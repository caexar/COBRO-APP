<?php

namespace App\Services;

use App\Models\CargaCapital;
use App\Models\Prestamo;
use Illuminate\Support\Facades\DB;

class CapitalService
{
    /**
     * Réplica del cálculo de `DashboardRepository.calcularResumen` del lado móvil (ver
     * CLAUDE.md): cargas - retiros + Σpagos.monto_abonado - Σmonto_capital de préstamos no
     * anulados, todo filtrado por el cobrador destino. Usado tanto para validar un retiro
     * (`AdminCargaCapitalController`) como para mostrarlo en el resumen consolidado
     * (`AdminResumenController`) — una sola fuente de verdad para la fórmula.
     */
    public function calcularSaldoDisponible(int $usuarioId): float
    {
        $totalCargas = (float) CargaCapital::where('usuario_id', $usuarioId)->where('tipo', 'carga')->sum('monto');
        $totalRetiros = (float) CargaCapital::where('usuario_id', $usuarioId)->where('tipo', 'retiro')->sum('monto');

        $totalAbonado = (float) DB::table('pagos')
            ->join('prestamos', 'pagos.prestamo_id', '=', 'prestamos.id')
            ->where('prestamos.usuario_id', $usuarioId)
            ->sum('pagos.monto_abonado');

        $capitalPrestadoNoAnulado = (float) Prestamo::where('usuario_id', $usuarioId)
            ->where('estado', '!=', 'anulado')
            ->sum('monto_capital');

        return round($totalCargas - $totalRetiros + $totalAbonado - $capitalPrestadoNoAnulado, 2);
    }
}
