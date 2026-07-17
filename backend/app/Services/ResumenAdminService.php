<?php

namespace App\Services;

use App\Models\CargaCapital;
use App\Models\Cliente;
use App\Models\Prestamo;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Toda la lógica de "Resumen" del panel de administración: única fuente de verdad, usada tanto
 * por `Api\Admin\AdminResumenController` (móvil, `GET /api/admin/resumen`) como por los
 * componentes Livewire del panel web (`App\Livewire\Admin\Resumen\*`) — para no reimplementar el
 * cálculo de ganancia/cartera en dos lugares. Las consultas de drill-down (préstamos, clientes,
 * cargas de capital, historial de pagos de un cobrador) son exclusivas del panel web: no hay
 * endpoint móvil equivalente que las use hoy.
 */
class ResumenAdminService
{
    public function __construct(
        private readonly CapitalService $capitalService,
    ) {}

    /**
     * @return array{global: array<string, float>, por_cobrador: array<int, array<string, mixed>>}
     */
    public function resumen(): array
    {
        $capitalPorCobrador = Prestamo::where('estado', '!=', 'anulado')
            ->selectRaw('usuario_id, SUM(monto_capital) as total')
            ->groupBy('usuario_id')
            ->pluck('total', 'usuario_id');

        $cobradoPorCobrador = DB::table('pagos')
            ->join('prestamos', 'pagos.prestamo_id', '=', 'prestamos.id')
            ->selectRaw('prestamos.usuario_id, SUM(pagos.monto_aplicado) as total')
            ->groupBy('prestamos.usuario_id')
            ->pluck('total', 'usuario_id');

        $pagosPorCuota = DB::table('pagos')
            ->select('cuota_id', DB::raw('SUM(monto_aplicado) as aplicado'))
            ->whereNotNull('cuota_id')
            ->groupBy('cuota_id');

        $moraPorCobrador = DB::table('cuotas')
            ->leftJoinSub($pagosPorCuota, 'pagos_cuota', 'cuotas.id', '=', 'pagos_cuota.cuota_id')
            ->join('prestamos', 'cuotas.prestamo_id', '=', 'prestamos.id')
            ->where('cuotas.estado', 'en_mora')
            ->groupBy('prestamos.usuario_id')
            ->selectRaw('prestamos.usuario_id, SUM(cuotas.monto_esperado - COALESCE(pagos_cuota.aplicado, 0)) as total')
            ->pluck('total', 'usuario_id');

        [$gananciaInteresPorCobrador, $gananciaExtraPorCobrador] = $this->calcularGananciaPorCobrador();

        $porCobrador = User::where('rol', 'cobrador')
            ->orderBy('nombre')
            ->get()
            ->map(fn (User $cobrador) => [
                'usuario_id' => $cobrador->id,
                'nombre' => $cobrador->nombre,
                'activo' => $cobrador->activo,
                'capital_prestado' => round((float) ($capitalPorCobrador[$cobrador->id] ?? 0), 2),
                'total_cobrado' => round((float) ($cobradoPorCobrador[$cobrador->id] ?? 0), 2),
                'cartera_en_mora' => round((float) ($moraPorCobrador[$cobrador->id] ?? 0), 2),
                'ganancia_interes' => round($gananciaInteresPorCobrador[$cobrador->id] ?? 0.0, 2),
                'ganancia_extra' => round($gananciaExtraPorCobrador[$cobrador->id] ?? 0.0, 2),
                'saldo_disponible' => $this->capitalService->calcularSaldoDisponible($cobrador->id),
            ]);

        return [
            'global' => [
                'capital_prestado' => round((float) $porCobrador->sum('capital_prestado'), 2),
                'total_cobrado' => round((float) $porCobrador->sum('total_cobrado'), 2),
                'cartera_en_mora' => round((float) $porCobrador->sum('cartera_en_mora'), 2),
                'ganancia_interes' => round((float) $porCobrador->sum('ganancia_interes'), 2),
                'ganancia_extra' => round((float) $porCobrador->sum('ganancia_extra'), 2),
                'saldo_disponible' => round((float) $porCobrador->sum('saldo_disponible'), 2),
            ],
            'por_cobrador' => $porCobrador->values()->all(),
        ];
    }

    /**
     * Reparte Σpagos.monto_aplicado de cada préstamo proporcional al peso de interés/extras
     * sobre su monto_total, agregado por cobrador sobre TODOS sus préstamos sin importar el
     * estado (uno ya pagado/anulado sigue contando históricamente) — misma lógica que
     * `DashboardRepository.calcularResumen` del lado móvil (ver CLAUDE.md). Reutiliza
     * [gananciaDePrestamo] préstamo por préstamo (sin rango: histórico completo).
     *
     * @return array{0: array<int, float>, 1: array<int, float>}
     */
    private function calcularGananciaPorCobrador(): array
    {
        $gananciaInteres = [];
        $gananciaExtra = [];

        foreach (Prestamo::with(['extras', 'pagos'])->get() as $prestamo) {
            $ganancia = $this->gananciaDePrestamo($prestamo);

            $usuarioId = $prestamo->usuario_id;
            $gananciaInteres[$usuarioId] = ($gananciaInteres[$usuarioId] ?? 0.0) + $ganancia['interes'];
            $gananciaExtra[$usuarioId] = ($gananciaExtra[$usuarioId] ?? 0.0) + $ganancia['extra'];
        }

        return [$gananciaInteres, $gananciaExtra];
    }

    /**
     * Ganancia de interés/extra de UN préstamo puntual: mismo reparto proporcional que
     * [calcularGananciaPorCobrador] (Σpagos.monto_aplicado proporcional al peso de
     * interés/extras sobre monto_total; el excedente `cobro_extra`, `monto_abonado -
     * monto_aplicado`, se suma íntegro a "extra"), pero acotado a un solo préstamo. Requiere
     * `extras`/`pagos` ya cargados en [$prestamo] (no dispara queries nuevas).
     *
     * Si se dan [$desde]/[$hasta], solo prorratea sobre los pagos con `fecha_pago` dentro de
     * ese rango — usado por el reporte de exportación para "ganancia generada en el periodo"
     * (Hoja 2), a diferencia del histórico completo que usa el resumen consolidado. Los pesos
     * (interés/extras sobre monto_total) siempre se calculan sobre el préstamo completo: son
     * fijos en el tiempo, no dependen de qué pagos se hayan hecho.
     *
     * @return array{interes: float, extra: float}
     */
    public function gananciaDePrestamo(Prestamo $prestamo, ?Carbon $desde = null, ?Carbon $hasta = null): array
    {
        $pagos = $prestamo->pagos->filter(function ($pago) use ($desde, $hasta) {
            if ($desde !== null && $pago->fecha_pago->lt($desde)) {
                return false;
            }
            if ($hasta !== null && $pago->fecha_pago->gt($hasta)) {
                return false;
            }

            return true;
        });

        $totalAplicado = (float) $pagos->sum('monto_aplicado');
        $totalAbonado = (float) $pagos->sum('monto_abonado');

        $montoCapital = (float) $prestamo->monto_capital;
        $montoInteres = round($montoCapital * ((float) $prestamo->porcentaje_interes / 100), 2);
        $montoExtras = round((float) $prestamo->extras->sum('valor'), 2);
        $montoTotal = round($montoCapital + $montoInteres + $montoExtras, 2);

        $gananciaInteres = 0.0;
        $gananciaExtra = 0.0;

        if ($montoTotal > 0) {
            $gananciaInteres = $totalAplicado * ($montoInteres / $montoTotal);
            $gananciaExtra = $totalAplicado * ($montoExtras / $montoTotal);
        }

        $gananciaExtra += $totalAbonado - $totalAplicado;

        return ['interes' => round($gananciaInteres, 2), 'extra' => round($gananciaExtra, 2)];
    }

    /**
     * Clientes del cobrador con el conteo "pagados/totales" de sus préstamos — "pagados" cuenta
     * solo `estado == 'pagado'`, "totales" cuenta cualquier estado sin filtrar (mismo criterio
     * ya corregido en `admin_cobrador_detalle_screen.dart` del lado móvil, no "activos/totales").
     *
     * @return array<int, array{cliente: Cliente, pagados: int, totales: int}>
     */
    public function clientesConConteo(int $usuarioId): array
    {
        $clientes = Cliente::where('usuario_id', $usuarioId)->orderBy('nombre')->get();

        $conteos = [];
        foreach (Prestamo::where('usuario_id', $usuarioId)->get(['cliente_id', 'estado']) as $prestamo) {
            $conteos[$prestamo->cliente_id]['totales'] = ($conteos[$prestamo->cliente_id]['totales'] ?? 0) + 1;
            $conteos[$prestamo->cliente_id]['pagados'] = ($conteos[$prestamo->cliente_id]['pagados'] ?? 0)
                + ($prestamo->estado === 'pagado' ? 1 : 0);
        }

        return $clientes->map(fn (Cliente $cliente) => [
            'cliente' => $cliente,
            'pagados' => $conteos[$cliente->id]['pagados'] ?? 0,
            'totales' => $conteos[$cliente->id]['totales'] ?? 0,
        ])->all();
    }

    /**
     * Préstamos del cobrador con extras/cuotas/pagos ya cargados y los campos derivados que
     * necesita la vista de detalle: título ("Cliente - Referencia", con el nombre del cliente
     * como respaldo), monto de interés/extras, total pagado, saldo pendiente, el excedente
     * `cobro_extra` ("extra cobrado") y la fecha de pago real por cuota — mismos cálculos ya
     * corregidos del lado móvil (`admin_models.dart`/`admin_cobrador_detalle_screen.dart`), acá
     * replicados en PHP porque esa lógica vive en Dart y no es reutilizable desde el backend.
     *
     * @return array<int, object>
     */
    public function prestamosDeCobrador(int $usuarioId): array
    {
        return Prestamo::where('usuario_id', $usuarioId)
            ->with(['cliente', 'extras', 'cuotas', 'pagos'])
            ->latest('fecha_inicio')
            ->get()
            ->map(function (Prestamo $prestamo) {
                $totalAbonado = round((float) $prestamo->pagos->sum('monto_abonado'), 2);
                $totalAplicado = round((float) $prestamo->pagos->sum('monto_aplicado'), 2);
                $montoExtras = round((float) $prestamo->extras->sum('valor'), 2);
                $montoTotal = (float) $prestamo->monto_total;
                $saldoPendiente = round($montoTotal - $totalAplicado, 2);

                $fechaPagoPorCuota = [];
                foreach ($prestamo->pagos as $pago) {
                    if ($pago->cuota_id === null) {
                        continue;
                    }
                    $actual = $fechaPagoPorCuota[$pago->cuota_id] ?? null;
                    if ($actual === null || $pago->fecha_pago->gt($actual)) {
                        $fechaPagoPorCuota[$pago->cuota_id] = $pago->fecha_pago;
                    }
                }

                return (object) [
                    'prestamo' => $prestamo,
                    'titulo' => filled($prestamo->referencia)
                        ? "{$prestamo->cliente->nombre} - {$prestamo->referencia}"
                        : $prestamo->cliente->nombre,
                    'montoExtras' => $montoExtras,
                    'montoInteres' => round($montoTotal - (float) $prestamo->monto_capital - $montoExtras, 2),
                    'montoTotal' => $montoTotal,
                    'totalPagado' => $totalAplicado,
                    'extraCobrado' => round($totalAbonado - $totalAplicado, 2),
                    'saldoPendiente' => max(0.0, $saldoPendiente),
                    'fechaPagoPorCuota' => $fechaPagoPorCuota,
                ];
            })
            ->all();
    }

    /**
     * @return Collection<int, CargaCapital>
     */
    public function cargasCapitalDeCobrador(int $usuarioId): Collection
    {
        return CargaCapital::where('usuario_id', $usuarioId)->orderByDesc('created_at')->get();
    }

    /**
     * Historial de pagos del cobrador agrupado por (préstamo, fecha_pago) — todas las filas que
     * comparten esa combinación vinieron de un mismo pago registrado, aunque hayan generado
     * varias filas en `pagos` por una cascada de `abono_deuda`. Resumen corto ("Cuota 2 + Extra
     * $ 50.000") y etiqueta por fila ("Pago cuota N"/"Abono cuota N"/"Extra") — misma lógica que
     * ya se implementó en `historial_pagos_screen.dart` del lado móvil (agrupar solo por
     * fecha_pago porque ese componente ya está scopeado a un préstamo; acá se agrega prestamo_id
     * a la clave porque el historial abarca todos los préstamos del cobrador).
     *
     * @return array<int, object>
     */
    public function historialPagosAgrupado(int $usuarioId): array
    {
        $prestamos = Prestamo::where('usuario_id', $usuarioId)->with(['cliente', 'cuotas', 'pagos'])->get();

        $grupos = [];

        foreach ($prestamos as $prestamo) {
            $numeroCuotaPorCuotaId = $prestamo->cuotas->pluck('numero_cuota', 'id');
            $titulo = filled($prestamo->referencia)
                ? "{$prestamo->cliente->nombre} - {$prestamo->referencia}"
                : $prestamo->cliente->nombre;

            $porFecha = $prestamo->pagos->groupBy(fn ($pago) => $pago->fecha_pago->format('Y-m-d'));

            foreach ($porFecha as $fecha => $filas) {
                $ordenado = $filas->sortBy(fn ($pago) => $numeroCuotaPorCuotaId[$pago->cuota_id] ?? 0)->values();

                $numerosCuota = [];
                $extraTotal = 0.0;
                $montoTotalAbonado = 0.0;
                $saldoRestanteDespues = null;
                $diasMora = 0;
                $filasDescritas = [];

                foreach ($ordenado as $indice => $pago) {
                    $numero = $numeroCuotaPorCuotaId[$pago->cuota_id] ?? null;
                    if ($numero !== null) {
                        $numerosCuota[$numero] = true;
                    }

                    $montoAbonado = (float) $pago->monto_abonado;
                    $montoAplicado = (float) $pago->monto_aplicado;
                    $extraTotal += $montoAbonado - $montoAplicado;
                    $montoTotalAbonado += $montoAbonado;

                    $saldoDespues = (float) $pago->saldo_restante_despues;
                    if ($saldoRestanteDespues === null || $saldoDespues < $saldoRestanteDespues) {
                        $saldoRestanteDespues = $saldoDespues;
                    }
                    $diasMora = max($diasMora, $pago->dias_mora);

                    if ($montoAbonado !== $montoAplicado) {
                        $descripcion = 'Extra';
                    } elseif ($indice === 0) {
                        $descripcion = $numero !== null ? "Pago cuota {$numero}" : 'Pago';
                    } else {
                        $descripcion = $numero !== null ? "Abono cuota {$numero}" : 'Abono';
                    }

                    $filasDescritas[] = (object) ['pago' => $pago, 'descripcion' => $descripcion];
                }

                $numerosOrdenados = array_keys($numerosCuota);
                sort($numerosOrdenados);

                $segmentos = [];
                if (! empty($numerosOrdenados)) {
                    $segmentos[] = 'Cuota '.implode(', ', $numerosOrdenados);
                }
                if ($extraTotal > 0) {
                    $segmentos[] = 'Extra '.\App\Support\Dinero::formatear($extraTotal);
                }

                $grupos[] = (object) [
                    'prestamo' => $prestamo,
                    'tituloPrestamo' => $titulo,
                    'fecha' => $fecha,
                    'resumenCorto' => empty($segmentos) ? 'Pago' : implode(' + ', $segmentos),
                    'montoTotalAbonado' => round($montoTotalAbonado, 2),
                    'saldoRestanteDespues' => round($saldoRestanteDespues ?? 0.0, 2),
                    'diasMora' => $diasMora,
                    'filas' => $filasDescritas,
                ];
            }
        }

        usort($grupos, fn ($a, $b) => strcmp($b->fecha, $a->fecha));

        return $grupos;
    }
}
