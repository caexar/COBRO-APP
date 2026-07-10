<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Prestamo;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class AdminResumenController extends Controller
{
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
            ]);

        return response()->json([
            'data' => [
                'global' => [
                    'capital_prestado' => round((float) $porCobrador->sum('capital_prestado'), 2),
                    'total_cobrado' => round((float) $porCobrador->sum('total_cobrado'), 2),
                    'cartera_en_mora' => round((float) $porCobrador->sum('cartera_en_mora'), 2),
                ],
                'por_cobrador' => $porCobrador->values(),
            ],
        ]);
    }
}
