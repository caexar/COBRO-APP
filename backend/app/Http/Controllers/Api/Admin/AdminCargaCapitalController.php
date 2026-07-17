<?php

namespace App\Http\Controllers\Api\Admin;

use App\Exceptions\SaldoInsuficienteException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\StoreAdminCargaCapitalRequest;
use App\Services\CapitalService;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;

class AdminCargaCapitalController extends Controller
{
    public function __construct(
        private readonly CapitalService $capitalService,
    ) {}

    /**
     * El admin asigna (o retira) saldo de capital a un cobrador puntual. A diferencia de
     * POST /cargas-capital (que usa el cobrador autenticado como dueño), acá `usuario_id` es
     * el cobrador destino y queda registrado quién lo hizo (`creado_por_usuario_id`).
     */
    public function store(StoreAdminCargaCapitalRequest $request): JsonResponse
    {
        $datos = $request->validated();

        try {
            $carga = $this->capitalService->asignar(
                usuarioId: $datos['usuario_id'],
                tipo: $datos['tipo'],
                monto: (float) $datos['monto'],
                descripcion: $datos['descripcion'] ?? null,
                actor: $request->user(),
            );
        } catch (SaldoInsuficienteException $e) {
            throw ValidationException::withMessages(['monto' => $e->getMessage()]);
        }

        return response()->json(['data' => $carga], 201);
    }
}
