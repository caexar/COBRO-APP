<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ConfiguracionGlobal;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PinMaestroController extends Controller
{
    /**
     * Datos de bloqueo que la app móvil descarga y guarda cifrados/localmente
     * en cada sincronización, para que el bloqueo (PIN maestro de emergencia,
     * cuántos intentos de PIN personal se toleran) funcione incluso sin
     * conexión. Nunca se expone el PIN en texto plano, solo el hash ya
     * calculado por el backend (Hash::make en Laravel = bcrypt).
     */
    public function index(Request $request): JsonResponse
    {
        return response()->json([
            'data' => [
                'pin_maestro_individual_hash' => $request->user()->pin_maestro_hash,
                'pin_maestro_global_hash' => ConfiguracionGlobal::obtener('pin_maestro_hash'),
                'intentos_pin_antes_de_maestro' => (int) ConfiguracionGlobal::obtener('intentos_pin_antes_de_maestro', 3),
            ],
        ]);
    }
}
