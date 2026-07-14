<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ConfiguracionGlobal;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PinMaestroController extends Controller
{
    /**
     * Hashes de PIN maestro que la app móvil descarga y guarda cifrada
     * localmente, para poder validar el PIN maestro incluso sin conexión.
     * Nunca se expone el PIN en texto plano, solo el hash ya calculado por
     * el backend (Hash::make en Laravel = bcrypt).
     */
    public function index(Request $request): JsonResponse
    {
        return response()->json([
            'data' => [
                'pin_maestro_individual_hash' => $request->user()->pin_maestro_hash,
                'pin_maestro_global_hash' => ConfiguracionGlobal::obtener('pin_maestro_hash'),
            ],
        ]);
    }
}
