<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\UpdateConfiguracionRequest;
use App\Models\ConfiguracionGlobal;
use App\Services\AuditoriaLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Hash;

class AdminConfiguracionController extends Controller
{
    public function __construct(
        private readonly AuditoriaLogger $auditoria,
    ) {}

    public function index(): JsonResponse
    {
        return response()->json(['data' => $this->configuracionActual()]);
    }

    public function update(UpdateConfiguracionRequest $request): JsonResponse
    {
        $datos = $request->validated();
        $anterior = $this->configuracionActual();
        $huboCambioPinMaestro = array_key_exists('pin_maestro', $datos);

        if (array_key_exists('tasas_interes_default', $datos)) {
            ConfiguracionGlobal::guardar('tasas_interes_default', json_encode($datos['tasas_interes_default']));
        }

        if (array_key_exists('politica_mora_default', $datos)) {
            ConfiguracionGlobal::guardar('politica_mora_default', $datos['politica_mora_default']);
        }

        if (array_key_exists('intentos_pin_antes_de_maestro', $datos)) {
            ConfiguracionGlobal::guardar('intentos_pin_antes_de_maestro', (string) $datos['intentos_pin_antes_de_maestro']);
        }

        if ($huboCambioPinMaestro) {
            if ($datos['pin_maestro'] === null) {
                ConfiguracionGlobal::where('clave', 'pin_maestro_hash')->delete();
            } else {
                ConfiguracionGlobal::guardar('pin_maestro_hash', Hash::make($datos['pin_maestro']));
            }
        }

        $actual = $this->configuracionActual();

        $this->auditoria->registrar(
            usuario: $request->user(),
            accion: 'actualizar_configuracion',
            entidad: 'ConfiguracionGlobal',
            entidadId: 0,
            datosAnteriores: $anterior,
            // El PIN maestro nunca se registra en texto plano; solo si cambió o no.
            datosNuevos: [...$actual, 'pin_maestro_actualizado' => $huboCambioPinMaestro],
        );

        return response()->json(['data' => $actual]);
    }

    /**
     * @return array{tasas_interes_default: array<int, float>, politica_mora_default: string, pin_maestro_configurado: bool, intentos_pin_antes_de_maestro: int}
     */
    private function configuracionActual(): array
    {
        $tasas = ConfiguracionGlobal::obtener('tasas_interes_default');

        return [
            'tasas_interes_default' => $tasas ? json_decode($tasas, true) : [10, 20, 30, 40],
            'politica_mora_default' => ConfiguracionGlobal::obtener('politica_mora_default', 'mantener'),
            'pin_maestro_configurado' => ConfiguracionGlobal::where('clave', 'pin_maestro_hash')->exists(),
            'intentos_pin_antes_de_maestro' => (int) ConfiguracionGlobal::obtener('intentos_pin_antes_de_maestro', 3),
        ];
    }
}
