<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\ReordenarRutasRequest;
use App\Http\Requests\StoreRutaRequest;
use App\Http\Requests\UpdateRutaRequest;
use App\Models\Ruta;
use App\Services\RutaService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class RutaController extends Controller
{
    public function __construct(
        private readonly RutaService $rutaService,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $this->authorize('viewAny', Ruta::class);

        $rutas = Ruta::where('usuario_id', $request->user()->id)
            ->withCount('items')
            ->orderBy('orden')
            ->get();

        return response()->json(['data' => $rutas]);
    }

    public function show(Request $request, Ruta $ruta): JsonResponse
    {
        $this->authorize('view', $ruta);

        return response()->json(['data' => $ruta->load('items.prestamo.cliente')]);
    }

    public function store(StoreRutaRequest $request): JsonResponse
    {
        $ruta = Ruta::create([
            ...$request->validated(),
            'usuario_id' => $request->user()->id,
            'orden' => Ruta::where('usuario_id', $request->user()->id)->count(),
        ]);

        return response()->json(['data' => $ruta], 201);
    }

    public function update(UpdateRutaRequest $request, Ruta $ruta): JsonResponse
    {
        $ruta->update($request->validated());

        return response()->json(['data' => $ruta]);
    }

    public function destroy(Request $request, Ruta $ruta): JsonResponse
    {
        $this->authorize('delete', $ruta);

        $ruta->delete();

        return response()->json(['message' => 'Ruta eliminada correctamente.']);
    }

    /**
     * Reordena la LISTA de rutas del cobrador (no los ítems de una ruta puntual, ver
     * RutaItemController::reordenar) — `ids` ya viene validado como perteneciente al cobrador
     * autenticado (ver ReordenarRutasRequest).
     */
    public function reordenar(ReordenarRutasRequest $request): JsonResponse
    {
        foreach ($request->validated('ids') as $indice => $id) {
            Ruta::where('id', $id)->update(['orden' => $indice]);
        }

        $rutas = Ruta::where('usuario_id', $request->user()->id)->orderBy('orden')->get();

        return response()->json(['data' => $rutas]);
    }

    /**
     * `fecha` es opcional (hoy por defecto, ver `RutaService::autogenerarHoy`) — el cobrador
     * puede pedir la ruta de otro día (ej. planificar mañana con anticipación) desde el mismo
     * endpoint, sin uno nuevo.
     */
    public function autogenerarHoy(Request $request): JsonResponse
    {
        $this->authorize('create', Ruta::class);

        $datos = $request->validate([
            'fecha' => ['nullable', 'date'],
        ]);

        $fecha = filled($datos['fecha'] ?? null) ? Carbon::parse($datos['fecha']) : null;

        $ruta = $this->rutaService->autogenerarHoy($request->user(), $fecha);

        return response()->json(['data' => $ruta], 201);
    }
}
