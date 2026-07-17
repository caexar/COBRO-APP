<?php

namespace App\Services;

use App\Exceptions\SaldoInsuficienteException;
use App\Models\CargaCapital;
use App\Models\Prestamo;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class CapitalService
{
    public function __construct(
        private readonly AuditoriaLogger $auditoria,
    ) {}

    /**
     * Réplica del cálculo de `DashboardRepository.calcularResumen` del lado móvil (ver
     * CLAUDE.md): cargas - retiros + Σpagos.monto_abonado - Σmonto_capital de préstamos no
     * anulados, todo filtrado por el cobrador destino. Usado tanto para validar un retiro
     * ([asignar]) como para mostrarlo en el resumen consolidado (`ResumenAdminService`) — una
     * sola fuente de verdad para la fórmula.
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

    /**
     * El admin asigna (o retira) saldo de capital a un cobrador puntual. Única fuente de
     * verdad para esta acción — usada tanto por `Api\Admin\AdminCargaCapitalController` (móvil)
     * como por el panel web (`App\Livewire\Admin\Resumen\DetalleCobrador`).
     *
     * @throws SaldoInsuficienteException si $tipo es 'retiro' y $monto excede el saldo
     *                                     disponible del cobrador.
     */
    public function asignar(
        int $usuarioId,
        string $tipo,
        float $monto,
        ?string $descripcion,
        User $actor,
        ?string $categoria = null,
    ): CargaCapital {
        if ($tipo === 'retiro') {
            $saldoDisponible = $this->calcularSaldoDisponible($usuarioId);

            if ($monto > $saldoDisponible) {
                throw new SaldoInsuficienteException(
                    'El monto del retiro excede el saldo disponible del cobrador ($'.number_format($saldoDisponible, 2).').',
                );
            }
        }

        $carga = CargaCapital::create([
            'usuario_id' => $usuarioId,
            'tipo' => $tipo,
            // Solo aplica a un retiro; para una carga, null sin importar lo que llegue acá
            // (mismo criterio que ya aplica StoreAdminCargaCapitalRequest del lado API).
            'categoria' => $tipo === 'retiro' ? $categoria : null,
            'monto' => $monto,
            'descripcion' => $descripcion,
            'origen' => 'admin',
            'creado_por_usuario_id' => $actor->id,
        ]);

        $this->auditoria->registrar(
            usuario: $actor,
            accion: 'asignar_capital',
            entidad: 'CargaCapital',
            entidadId: $carga->id,
            datosAnteriores: null,
            datosNuevos: [
                'usuario_id' => $carga->usuario_id,
                'tipo' => $carga->tipo,
                'categoria' => $carga->categoria,
                'monto' => (float) $carga->monto,
                'descripcion' => $carga->descripcion,
            ],
        );

        return $carga;
    }
}
