<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreSyncRequest;
use App\Models\ConfiguracionGlobal;
use App\Services\SyncService;
use Illuminate\Http\JsonResponse;

class SyncController extends Controller
{
    public function __construct(
        private readonly SyncService $syncService,
    ) {}

    /**
     * Recibe el batch de cambios pendientes de la app móvil (clientes/prestamos/pagos/
     * cargas_capital) y devuelve, junto con el resultado por registro, la configuración global
     * vigente — así el móvil descarga ambas cosas en un solo viaje de red.
     */
    public function store(StoreSyncRequest $request): JsonResponse
    {
        $resultado = $this->syncService->sincronizar($request->user(), $request->validated());

        // Se calcula (y se marca como entregada) después del batch de subida a propósito: si
        // algo del batch falla con una excepción no controlada, nunca llegamos a marcar estas
        // cargas como descargadas y se reintentan en el próximo /sync.
        $cargasCapitalAdmin = $this->syncService->cargasCapitalAdminPendientes($request->user());

        return response()->json([
            'data' => $resultado,
            'cargas_capital_admin' => $cargasCapitalAdmin,
            'configuracion' => $this->configuracionParaMovil(),
        ]);
    }

    /**
     * Mismas claves que `AdminConfiguracionController::configuracionActual()`, sin el hash del
     * PIN maestro: eso sigue siendo exclusivo de `GET /pin-maestro`, no se duplica acá.
     *
     * @return array{tasas_interes_default: array<int, float>, politica_mora_default: string, pin_maestro_configurado: bool, intentos_pin_antes_de_maestro: int}
     */
    private function configuracionParaMovil(): array
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
