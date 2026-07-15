<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreCargaCapitalRequest;
use App\Models\CargaCapital;
use App\Services\AuditoriaLogger;
use Illuminate\Http\JsonResponse;

class CargaCapitalController extends Controller
{
    public function __construct(
        private readonly AuditoriaLogger $auditoria,
    ) {}

    public function store(StoreCargaCapitalRequest $request): JsonResponse
    {
        $datos = $request->validated();

        $cargaCapital = CargaCapital::create([
            ...$datos,
            'usuario_id' => $request->user()->id,
        ]);

        $this->auditoria->registrar(
            usuario: $request->user(),
            accion: 'registrar_carga_capital',
            entidad: 'CargaCapital',
            entidadId: $cargaCapital->id,
            datosAnteriores: null,
            datosNuevos: [
                'monto' => $cargaCapital->monto,
                'descripcion' => $cargaCapital->descripcion,
            ],
        );

        return response()->json(['data' => $cargaCapital], 201);
    }
}
