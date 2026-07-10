<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StorePagoRequest;
use App\Models\Prestamo;
use App\Services\AuditoriaLogger;
use App\Services\PagoProcessor;
use Illuminate\Http\JsonResponse;
use RuntimeException;

class PagoController extends Controller
{
    public function __construct(
        private readonly PagoProcessor $procesador,
        private readonly AuditoriaLogger $auditoria,
    ) {}

    public function store(StorePagoRequest $request): JsonResponse
    {
        $datos = $request->validated();

        $prestamo = Prestamo::findOrFail($datos['prestamo_id']);
        $this->authorize('update', $prestamo);

        try {
            $pagos = $this->procesador->procesar($prestamo, $datos);
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        $prestamo->refresh();
        $pagoPrincipal = $pagos->first();

        $this->auditoria->registrar(
            usuario: $request->user(),
            accion: 'registrar_pago',
            entidad: 'Pago',
            entidadId: $pagoPrincipal->id,
            datosAnteriores: null,
            datosNuevos: [
                'prestamo_id' => $prestamo->id,
                'monto_abonado_total' => (float) $datos['monto_abonado'],
                'manejo_excedente' => $datos['manejo_excedente'] ?? null,
                'estado_prestamo' => $prestamo->estado,
                'pagos_generados' => $pagos->map(fn ($pago) => [
                    'id' => $pago->id,
                    'cuota_id' => $pago->cuota_id,
                    'monto_abonado' => (float) $pago->monto_abonado,
                    'monto_aplicado' => (float) $pago->monto_aplicado,
                    'dias_mora' => $pago->dias_mora,
                    'saldo_restante_despues' => (float) $pago->saldo_restante_despues,
                ])->all(),
            ],
        );

        return response()->json([
            'data' => $pagos->each->load('cuota')->values(),
        ], 201);
    }
}
