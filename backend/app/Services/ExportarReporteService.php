<?php

namespace App\Services;

use App\Exports\Admin\ArraySheetExport;
use App\Exports\Admin\ReporteAdminExport;
use App\Models\CargaCapital;
use App\Models\CierreCaja;
use App\Models\Cuota;
use App\Models\Prestamo;
use App\Models\Ruta;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Maatwebsite\Excel\Excel as ExcelFormat;
use Maatwebsite\Excel\Facades\Excel;

/**
 * Genera el .xlsx del panel web (`/admin/exportar`): un reporte financiero de 3 hojas
 * (préstamos, evolución por cobrador, movimientos de capital) para los cobradores y el rango
 * de fechas filtrados. Reutiliza `ResumenAdminService::prestamosDeCobrador()`/
 * `gananciaDePrestamo()` en vez de repetir esas queries/fórmulas.
 *
 * A diferencia del CSV anterior, el paquete de Excel (`maatwebsite/excel`) ya maneja UTF-8 de
 * forma nativa — no hace falta el hack del BOM que sí era necesario para que Excel detectara
 * bien la codificación de un .csv plano.
 */
class ExportarReporteService
{
    public function __construct(
        private readonly ResumenAdminService $resumenAdminService,
    ) {}

    /**
     * @param  array<int, int>  $usuarioIds
     */
    public function generarXlsx(array $usuarioIds, ?Carbon $desde, ?Carbon $hasta, ?string $categoriaCapital): string
    {
        $datos = $this->datosReporte($usuarioIds, $desde, $hasta, $categoriaCapital);

        $export = new ReporteAdminExport(array_map(
            fn (array $hoja) => new ArraySheetExport($hoja['titulo'], $hoja['columnas'], $hoja['filas']),
            array_values($datos),
        ));

        return Excel::raw($export, ExcelFormat::XLSX);
    }

    /**
     * Los mismos 3 bloques de datos que arma `generarXlsx()` (préstamos, resumen por
     * cobrador, movimientos de capital), pero como arrays planos —encabezados + filas, sin
     * generar ningún archivo— en vez de un .xlsx. Fuente única de verdad para ambos: el panel
     * web sigue descargando el .xlsx (`generarXlsx()`), y `GET /api/admin/reporte`
     * (`Api\Admin\AdminReporteController`) expone esto mismo como JSON para que el panel admin
     * móvil arme su propio CSV sin duplicar ninguno de estos cálculos.
     *
     * @param  array<int, int>  $usuarioIds
     * @return array<string, array{titulo: string, columnas: array<int, string>, filas: array<int, array<int, mixed>>}>
     */
    public function datosReporte(array $usuarioIds, ?Carbon $desde, ?Carbon $hasta, ?string $categoriaCapital): array
    {
        $cobradores = User::whereIn('id', $usuarioIds)->orderBy('nombre')->get();

        return [
            'prestamos' => [
                'titulo' => 'Detalle de préstamos',
                'columnas' => ['Cobrador', 'Cliente', 'Cédula', 'Capital', '% Interés', 'Valor de cada cuota', 'Ganancia', 'Capital + Interés (sin extras)', 'Plazo (cuotas)', 'Frecuencia de pago', 'Estado'],
                'filas' => $this->filasPrestamos($cobradores),
            ],
            'resumen_por_cobrador' => [
                'titulo' => 'Resumen por cobrador',
                'columnas' => ['Cobrador', 'Cartera pendiente al inicio', 'Total cobrado en el periodo', 'Total prestado en el periodo', 'Cartera pendiente al final', 'Ganancia por interés (periodo)', 'Ganancia por extra (periodo)'],
                'filas' => $this->filasResumenCobrador($cobradores, $desde, $hasta),
            ],
            'movimientos_capital' => [
                'titulo' => 'Movimientos de capital',
                'columnas' => ['Cobrador', 'Fecha', 'Tipo', 'Monto', 'Categoría', 'Descripción', 'Origen'],
                'filas' => $this->filasMovimientosCapital($cobradores, $desde, $hasta, $categoriaCapital),
            ],
            'cierre_caja' => [
                'titulo' => 'Cierre de caja',
                'columnas' => ['Cobrador', 'Fecha', 'Capital inicio', 'Capital cierre', 'Total gastos', 'Detalle de gastos', 'Justificación'],
                'filas' => $this->filasCierreCaja($cobradores, $desde, $hasta),
            ],
            'cierre_caja_resumen' => [
                'titulo' => 'Resumen de cierre de caja (rango)',
                'columnas' => ['Cobrador', 'Capital inicio (primer día)', 'Capital cierre (último día)', 'Total gastos (rango)'],
                'filas' => $this->filasCierreCajaResumen($cobradores, $desde, $hasta),
            ],
            'rutas' => [
                'titulo' => 'Rutas de cobro',
                'columnas' => ['Cobrador', 'Ruta', 'Fecha de la ruta', 'Orden', 'Cliente', 'Préstamo', 'Estado', 'Cobrado en', 'Monto pendiente'],
                'filas' => $this->filasRutas($cobradores, $desde, $hasta),
            ],
        ];
    }

    /**
     * Una fila por préstamo de los cobradores filtrados, sin importar su estado ni su
     * fecha_inicio (el rango de fechas no aplica acá — ver Hoja 2 para la evolución acotada al
     * periodo). "Ganancia" es interés + extra de ESE préstamo puntual, no el total del
     * cobrador.
     *
     * @param  Collection<int, User>  $cobradores
     * @return array<int, array<int, mixed>>
     */
    private function filasPrestamos(Collection $cobradores): array
    {
        $filas = [];

        foreach ($cobradores as $cobrador) {
            foreach ($this->resumenAdminService->prestamosDeCobrador($cobrador->id) as $item) {
                $prestamo = $item->prestamo;
                $ganancia = $this->resumenAdminService->gananciaDePrestamo($prestamo);

                $filas[] = [
                    $cobrador->nombre,
                    $prestamo->cliente->nombre,
                    $prestamo->cliente->cedula,
                    (float) $prestamo->monto_capital,
                    (float) $prestamo->porcentaje_interes,
                    round($item->montoTotal / $prestamo->plazo_cuotas, 2),
                    round($ganancia['interes'] + $ganancia['extra'], 2),
                    round((float) $prestamo->monto_capital + $item->montoInteres, 2),
                    $prestamo->plazo_cuotas,
                    $prestamo->frecuencia_pago,
                    $prestamo->estado,
                ];
            }
        }

        return $filas;
    }

    /**
     * Una fila por cobrador con la evolución de su cartera dentro del rango filtrado: cuánto
     * debían los clientes al inicio, cuánto se prestó/cobró durante el periodo, cuánto quedó
     * pendiente al final, y la ganancia generada solo por los pagos del periodo (no el
     * histórico completo del préstamo).
     *
     * @param  Collection<int, User>  $cobradores
     * @return array<int, array<int, mixed>>
     */
    private function filasResumenCobrador(Collection $cobradores, ?Carbon $desde, ?Carbon $hasta): array
    {
        $filas = [];

        foreach ($cobradores as $cobrador) {
            $totalCobradoEnRango = (float) DB::table('pagos')
                ->join('prestamos', 'pagos.prestamo_id', '=', 'prestamos.id')
                ->where('prestamos.usuario_id', $cobrador->id)
                ->when($desde, fn ($query) => $query->where('pagos.fecha_pago', '>=', $desde))
                ->when($hasta, fn ($query) => $query->where('pagos.fecha_pago', '<=', $hasta))
                ->sum('pagos.monto_aplicado');

            $totalPrestadoEnRango = (float) Prestamo::where('usuario_id', $cobrador->id)
                ->when($desde, fn ($query) => $query->where('fecha_inicio', '>=', $desde))
                ->when($hasta, fn ($query) => $query->where('fecha_inicio', '<=', $hasta))
                ->sum('monto_capital');

            $gananciaInteres = 0.0;
            $gananciaExtra = 0.0;
            foreach (Prestamo::where('usuario_id', $cobrador->id)->with(['extras', 'pagos'])->get() as $prestamo) {
                $ganancia = $this->resumenAdminService->gananciaDePrestamo($prestamo, $desde, $hasta);
                $gananciaInteres += $ganancia['interes'];
                $gananciaExtra += $ganancia['extra'];
            }

            $filas[] = [
                $cobrador->nombre,
                $this->carteraPendienteAlCorte($cobrador->id, $desde, inclusive: false),
                round($totalCobradoEnRango, 2),
                round($totalPrestadoEnRango, 2),
                $this->carteraPendienteAlCorte($cobrador->id, $hasta ?? Carbon::now(), inclusive: true),
                round($gananciaInteres, 2),
                round($gananciaExtra, 2),
            ];
        }

        return $filas;
    }

    /**
     * Saldo pendiente de las cuotas del cobrador cuya fecha_esperada es anterior (o, si
     * [$inclusive], anterior o igual) a [$fechaCorte], evaluado contra los pagos aplicados
     * hasta ese mismo corte — una reconstrucción histórica de "cuánta cartera estaba
     * pendiente en ese momento" (mora + cuotas aún no vencidas en ese punto), no el estado
     * actual de las cuotas. Si [$fechaCorte] es null, no hay nada "antes" de un rango sin
     * inicio definido: devuelve 0.
     */
    private function carteraPendienteAlCorte(int $usuarioId, ?Carbon $fechaCorte, bool $inclusive): float
    {
        if ($fechaCorte === null) {
            return 0.0;
        }

        $cuotas = Cuota::whereHas('prestamo', fn ($query) => $query->where('usuario_id', $usuarioId))
            ->where('fecha_esperada', $inclusive ? '<=' : '<', $fechaCorte)
            ->with('pagos')
            ->get();

        $total = 0.0;
        foreach ($cuotas as $cuota) {
            $pagadoAlCorte = (float) $cuota->pagos
                ->filter(fn ($pago) => $inclusive ? $pago->fecha_pago->lte($fechaCorte) : $pago->fecha_pago->lt($fechaCorte))
                ->sum('monto_aplicado');

            $saldo = round((float) $cuota->monto_esperado - $pagadoAlCorte, 2);
            if ($saldo > 0) {
                $total += $saldo;
            }
        }

        return round($total, 2);
    }

    /**
     * Una fila por cada movimiento de capital de los cobradores filtrados, dentro del rango
     * de fechas (por `created_at`, mismo campo que ya usa la vista de detalle de cobrador) y,
     * si se dio, con la categoria elegida (solo los retiros tienen categoria, así que este
     * filtro naturalmente no afecta las cargas).
     *
     * @param  Collection<int, User>  $cobradores
     * @return array<int, array<int, mixed>>
     */
    private function filasMovimientosCapital(Collection $cobradores, ?Carbon $desde, ?Carbon $hasta, ?string $categoriaCapital): array
    {
        $nombresPorId = $cobradores->pluck('nombre', 'id');

        $cargas = CargaCapital::whereIn('usuario_id', $cobradores->pluck('id'))
            ->when($desde, fn ($query) => $query->where('created_at', '>=', $desde))
            ->when($hasta, fn ($query) => $query->where('created_at', '<=', $hasta))
            ->when($categoriaCapital, fn ($query) => $query->where('categoria', $categoriaCapital))
            ->orderByDesc('created_at')
            ->get();

        return $cargas->map(fn (CargaCapital $carga) => [
            $nombresPorId[$carga->usuario_id] ?? '—',
            $carga->created_at->format('d/m/Y'),
            $carga->tipo,
            (float) $carga->monto,
            $carga->categoria ?? '',
            $carga->descripcion ?? '',
            $carga->origen,
        ])->all();
    }

    /**
     * Una fila por día (por `fecha`, la fecha operativa elegida por el cobrador — no
     * `created_at`) de los cierres de caja de los cobradores filtrados, dentro del rango.
     * "Detalle de gastos" concatena cada gasto del día ("almuerzo ($10.000); gasolina
     * ($25.000)") porque el pedido es una fila por día, no una fila por gasto.
     *
     * @param  Collection<int, User>  $cobradores
     * @return array<int, array<int, mixed>>
     */
    private function filasCierreCaja(Collection $cobradores, ?Carbon $desde, ?Carbon $hasta): array
    {
        $nombresPorId = $cobradores->pluck('nombre', 'id');

        $cierres = CierreCaja::whereIn('usuario_id', $cobradores->pluck('id'))
            ->when($desde, fn ($query) => $query->where('fecha', '>=', $desde))
            ->when($hasta, fn ($query) => $query->where('fecha', '<=', $hasta))
            ->with('gastos')
            ->orderBy('fecha')
            ->get();

        return $cierres->map(fn (CierreCaja $cierre) => [
            $nombresPorId[$cierre->usuario_id] ?? '—',
            $cierre->fecha->format('d/m/Y'),
            (float) $cierre->capital_inicio,
            (float) $cierre->capital_cierre,
            (float) $cierre->gastos_total,
            $this->detalleGastos($cierre),
            $cierre->justificacion_diferencia,
        ])->all();
    }

    private function detalleGastos(CierreCaja $cierre): string
    {
        return $cierre->gastos
            ->map(fn ($gasto) => "{$gasto->detalle} (\$".number_format((float) $gasto->monto, 0, ',', '.').')')
            ->implode('; ');
    }

    /**
     * Una fila por cobrador con el total agregado del rango filtrado (suma de gastos, capital
     * inicio del primer día del rango, capital cierre del último) — complementa la vista diaria
     * de arriba para ver de un vistazo el total semanal/mensual. Un cobrador sin ningún cierre
     * en el rango no aparece (no hay nada que resumir).
     *
     * @param  Collection<int, User>  $cobradores
     * @return array<int, array<int, mixed>>
     */
    private function filasCierreCajaResumen(Collection $cobradores, ?Carbon $desde, ?Carbon $hasta): array
    {
        $filas = [];

        foreach ($cobradores as $cobrador) {
            $cierres = CierreCaja::where('usuario_id', $cobrador->id)
                ->when($desde, fn ($query) => $query->where('fecha', '>=', $desde))
                ->when($hasta, fn ($query) => $query->where('fecha', '<=', $hasta))
                ->orderBy('fecha')
                ->get();

            if ($cierres->isEmpty()) {
                continue;
            }

            $filas[] = [
                $cobrador->nombre,
                (float) $cierres->first()->capital_inicio,
                (float) $cierres->last()->capital_cierre,
                round((float) $cierres->sum('gastos_total'), 2),
            ];
        }

        return $filas;
    }

    /**
     * Una fila por ítem (préstamo dentro de una ruta) de los cobradores filtrados, en el orden
     * en que quedaron dentro de cada ruta, dentro del rango — por `created_at` de la ruta
     * (mismo campo que ya usa `filasMovimientosCapital()` para `cargas_capital`, no `fecha` de
     * la ruta: esa es nullable en una ruta general/reutilizable y filtrar por ella dejaría esas
     * rutas fuera del reporte por completo). "Monto pendiente" es el saldo del préstamo al
     * momento de exportar (no un histórico congelado a la fecha del ítem) — misma fórmula que
     * `monto_total - Σpagos.monto_aplicado` usada en el resto del reporte.
     *
     * @param  Collection<int, User>  $cobradores
     * @return array<int, array<int, mixed>>
     */
    private function filasRutas(Collection $cobradores, ?Carbon $desde, ?Carbon $hasta): array
    {
        $nombresPorId = $cobradores->pluck('nombre', 'id');

        $rutas = Ruta::whereIn('usuario_id', $cobradores->pluck('id'))
            ->when($desde, fn ($query) => $query->where('created_at', '>=', $desde))
            ->when($hasta, fn ($query) => $query->where('created_at', '<=', $hasta))
            ->with(['items' => fn ($query) => $query->orderBy('orden'), 'items.prestamo.cliente', 'items.prestamo.pagos'])
            ->orderBy('created_at')
            ->get();

        $filas = [];

        foreach ($rutas as $ruta) {
            foreach ($ruta->items as $item) {
                $prestamo = $item->prestamo;
                $saldoPendiente = $prestamo
                    ? max(0, round((float) $prestamo->monto_total - (float) $prestamo->pagos->sum('monto_aplicado'), 2))
                    : 0.0;

                $filas[] = [
                    $nombresPorId[$ruta->usuario_id] ?? '—',
                    $ruta->nombre,
                    $ruta->fecha?->format('d/m/Y') ?? '',
                    $item->orden,
                    $prestamo?->cliente?->nombre ?? '—',
                    $prestamo?->referencia ?? ($prestamo ? "Préstamo #{$prestamo->id}" : '—'),
                    $item->estado,
                    $item->cobrado_en?->format('d/m/Y H:i') ?? '',
                    $saldoPendiente,
                ];
            }
        }

        return $filas;
    }
}
