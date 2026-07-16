<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\StoreAdminCargaCapitalRequest;
use App\Models\CargaCapital;
use App\Services\AuditoriaLogger;
use Illuminate\Http\JsonResponse;

class AdminCargaCapitalController extends Controller
{
    public function __construct(
        private readonly AuditoriaLogger $auditoria,
    ) {}

    /**
     * El admin asigna (o retira) saldo de capital a un cobrador puntual. A diferencia de
     * POST /cargas-capital (que usa el cobrador autenticado como dueño), acá `usuario_id` es
     * el cobrador destino y queda registrado quién lo hizo (`creado_por_usuario_id`).
     */
    public function store(StoreAdminCargaCapitalRequest $request): JsonResponse
    {
        $datos = $request->validated();

        $carga = CargaCapital::create([
            'usuario_id' => $datos['usuario_id'],
            'tipo' => $datos['tipo'],
            'monto' => $datos['monto'],
            'descripcion' => $datos['descripcion'] ?? null,
            'origen' => 'admin',
            'creado_por_usuario_id' => $request->user()->id,
        ]);

        $this->auditoria->registrar(
            usuario: $request->user(),
            accion: 'asignar_capital',
            entidad: 'CargaCapital',
            entidadId: $carga->id,
            datosAnteriores: null,
            datosNuevos: [
                'usuario_id' => $carga->usuario_id,
                'tipo' => $carga->tipo,
                'monto' => (float) $carga->monto,
                'descripcion' => $carga->descripcion,
            ],
        );

        return response()->json(['data' => $carga], 201);
    }
}
