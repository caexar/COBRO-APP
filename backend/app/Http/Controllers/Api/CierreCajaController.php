<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreCierreCajaRequest;
use App\Models\CierreCaja;
use App\Services\AuditoriaLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * CRUD del propio cobrador sobre sus cierres de caja diarios — mismo patrón de aislamiento por
 * `usuario_id` que el resto de `/api/*` (`role:cobrador`). Solo lectura (`index`/`show`) y
 * creación (`store`); no hay edición ni borrado de un cierre ya registrado, igual que
 * `cargas_capital` no tiene flujo de edición desde el móvil.
 */
class CierreCajaController extends Controller
{
    public function __construct(
        private readonly AuditoriaLogger $auditoria,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $cierres = CierreCaja::where('usuario_id', $request->user()->id)
            ->with('gastos')
            ->orderByDesc('fecha')
            ->get();

        return response()->json(['data' => $cierres]);
    }

    public function show(Request $request, CierreCaja $cierreCaja): JsonResponse
    {
        abort_if($cierreCaja->usuario_id !== $request->user()->id, 404);

        return response()->json(['data' => $cierreCaja->load('gastos')]);
    }

    /**
     * `gastos_total` siempre se deriva acá como la suma de los gastos recibidos — nunca se
     * confía en un total que mande el cliente, para que no pueda desincronizarse del detalle.
     */
    public function store(StoreCierreCajaRequest $request): JsonResponse
    {
        $datos = $request->validated();
        $gastos = $datos['gastos'] ?? [];
        $gastosTotal = round(collect($gastos)->sum('monto'), 2);

        $cierre = DB::transaction(function () use ($request, $datos, $gastos, $gastosTotal) {
            $cierre = CierreCaja::create([
                'usuario_id' => $request->user()->id,
                'fecha' => $datos['fecha'],
                'capital_inicio' => $datos['capital_inicio'],
                'capital_cierre' => $datos['capital_cierre'],
                'justificacion_diferencia' => $datos['justificacion_diferencia'] ?? null,
                'gastos_total' => $gastosTotal,
            ]);

            foreach ($gastos as $gasto) {
                $cierre->gastos()->create($gasto);
            }

            return $cierre;
        });

        $this->auditoria->registrar(
            usuario: $request->user(),
            accion: 'registrar_cierre_caja',
            entidad: 'CierreCaja',
            entidadId: $cierre->id,
            datosAnteriores: null,
            datosNuevos: [
                'fecha' => $cierre->fecha->toDateString(),
                'capital_inicio' => (float) $cierre->capital_inicio,
                'capital_cierre' => (float) $cierre->capital_cierre,
                'gastos_total' => (float) $cierre->gastos_total,
                'justificacion_diferencia' => $cierre->justificacion_diferencia,
            ],
        );

        return response()->json(['data' => $cierre->load('gastos')], 201);
    }
}
