<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Prestamo;
use App\Models\User;
use App\Services\CapitalService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class AdminResumenController extends Controller
{
    public function __construct(
        private readonly CapitalService $capitalService,
    ) {}

    public function index(): JsonResponse
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

        return response()->json([
            'data' => [
                'global' => [
                    'capital_prestado' => round((float) $porCobrador->sum('capital_prestado'), 2),
                    'total_cobrado' => round((float) $porCobrador->sum('total_cobrado'), 2),
                    'cartera_en_mora' => round((float) $porCobrador->sum('cartera_en_mora'), 2),
                    'ganancia_interes' => round((float) $porCobrador->sum('ganancia_interes'), 2),
                    'ganancia_extra' => round((float) $porCobrador->sum('ganancia_extra'), 2),
                    'saldo_disponible' => round((float) $porCobrador->sum('saldo_disponible'), 2),
                ],
                'por_cobrador' => $porCobrador->values(),
            ],
        ]);
    }

    /**
     * Reparte Σpagos.monto_aplicado de cada préstamo proporcional al peso de interés/extras
     * sobre su monto_total, agregado por cobrador sobre TODOS sus préstamos sin importar el
     * estado (uno ya pagado/anulado sigue contando históricamente) — misma lógica que
     * `DashboardRepository.calcularResumen` del lado móvil (ver CLAUDE.md), replicada acá para
     * el consolidado del admin. El excedente de un pago `cobro_extra`
     * (`monto_abonado - monto_aplicado`, el único caso donde difieren) se suma íntegro al
     * balde de "extras", igual que del lado móvil.
     *
     * @return array{0: array<int, float>, 1: array<int, float>}
     */
    private function calcularGananciaPorCobrador(): array
    {
        $gananciaInteres = [];
        $gananciaExtra = [];

        foreach (Prestamo::with(['extras', 'pagos'])->get() as $prestamo) {
            $totalAplicado = (float) $prestamo->pagos->sum('monto_aplicado');
            $totalAbonado = (float) $prestamo->pagos->sum('monto_abonado');

            $montoCapital = (float) $prestamo->monto_capital;
            $montoInteres = round($montoCapital * ((float) $prestamo->porcentaje_interes / 100), 2);
            $montoExtras = round((float) $prestamo->extras->sum('valor'), 2);
            $montoTotal = round($montoCapital + $montoInteres + $montoExtras, 2);

            $usuarioId = $prestamo->usuario_id;
            $gananciaInteres[$usuarioId] ??= 0.0;
            $gananciaExtra[$usuarioId] ??= 0.0;

            if ($montoTotal > 0) {
                $gananciaInteres[$usuarioId] += $totalAplicado * ($montoInteres / $montoTotal);
                $gananciaExtra[$usuarioId] += $totalAplicado * ($montoExtras / $montoTotal);
            }

            $gananciaExtra[$usuarioId] += $totalAbonado - $totalAplicado;
        }

        return [$gananciaInteres, $gananciaExtra];
    }
}
