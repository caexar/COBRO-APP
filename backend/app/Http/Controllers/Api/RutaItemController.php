<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\ReordenarRutaItemsRequest;
use App\Http\Requests\StoreRutaItemRequest;
use App\Models\Ruta;
use App\Models\RutaItem;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * CRUD de los ítems (préstamos) dentro de una ruta. Todas las acciones están anidadas bajo
 * `/rutas/{ruta}/items/...`; la autorización de "es tu ruta" vive en el Form Request
 * correspondiente (o, para las acciones sin uno propio, en un `authorize('update', $ruta)`
 * explícito acá) — `$rutaItem` se valida además contra `$ruta` con `abort_if` porque el binding
 * implícito de `{rutaItem}` no está scoped al `{ruta}` de la URL.
 */
class RutaItemController extends Controller
{
    public function store(StoreRutaItemRequest $request, Ruta $ruta): JsonResponse
    {
        $item = $ruta->items()->create([
            'prestamo_id' => $request->validated('prestamo_id'),
            'orden' => $ruta->items()->count(),
            'estado' => 'pendiente',
        ]);

        return response()->json(['data' => $item->load('prestamo.cliente')], 201);
    }

    public function destroy(Request $request, Ruta $ruta, RutaItem $rutaItem): JsonResponse
    {
        $this->authorize('update', $ruta);
        abort_if($rutaItem->ruta_id !== $ruta->id, 404);

        $rutaItem->delete();

        return response()->json(['message' => 'Ítem eliminado de la ruta.']);
    }

    /**
     * Reordena los ítems DENTRO de esta ruta (drag-and-drop) — distinto del orden de la lista
     * de rutas, ver RutaController::reordenar.
     */
    public function reordenar(ReordenarRutaItemsRequest $request, Ruta $ruta): JsonResponse
    {
        foreach ($request->validated('ids') as $indice => $id) {
            RutaItem::where('id', $id)->update(['orden' => $indice]);
        }

        return response()->json(['data' => $ruta->items()->with('prestamo.cliente')->get()]);
    }

    /**
     * Marca un ítem como cobrado directamente, sin pasar por el flujo de registrar un pago real
     * (ese es el caso principal, ver mobile — pero este endpoint cubre el caso de querer
     * marcarlo manualmente igual).
     */
    public function marcarCobrado(Request $request, Ruta $ruta, RutaItem $rutaItem): JsonResponse
    {
        $this->authorize('update', $ruta);
        abort_if($rutaItem->ruta_id !== $ruta->id, 404);

        $rutaItem->update(['estado' => 'cobrado', 'cobrado_en' => now()]);

        return response()->json(['data' => $rutaItem]);
    }
}
