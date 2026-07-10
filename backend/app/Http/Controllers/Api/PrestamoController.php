<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\SimularPrestamoRequest;
use App\Http\Requests\StorePrestamoRequest;
use App\Models\Prestamo;
use App\Services\AuditoriaLogger;
use App\Services\PrestamoCalculator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PrestamoController extends Controller
{
    public function __construct(
        private readonly PrestamoCalculator $calculator,
        private readonly AuditoriaLogger $auditoria,
    ) {}

    public function store(StorePrestamoRequest $request): JsonResponse
    {
        $datos = $request->validated();
        $resultado = $this->calculator->calcular($datos);

        $prestamo = DB::transaction(function () use ($datos, $resultado, $request) {
            $prestamo = Prestamo::create([
                'cliente_id' => $datos['cliente_id'],
                'usuario_id' => $request->user()->id,
                'monto_capital' => $datos['monto_capital'],
                'porcentaje_interes' => $datos['porcentaje_interes'],
                'frecuencia_pago' => $datos['frecuencia_pago'],
                'dias_personalizado' => $datos['dias_personalizado'] ?? null,
                'plazo_cuotas' => $datos['plazo_cuotas'],
                'fecha_inicio' => $datos['fecha_inicio'],
                'estado' => 'activo',
                'politica_mora' => $datos['politica_mora'] ?? 'mantener',
            ]);

            foreach ($datos['extras'] ?? [] as $extra) {
                $prestamo->extras()->create($extra);
            }

            foreach ($resultado['cuotas'] as $cuota) {
                $prestamo->cuotas()->create($cuota);
            }

            return $prestamo;
        });

        $this->auditoria->registrar(
            usuario: $request->user(),
            accion: 'crear_prestamo',
            entidad: 'Prestamo',
            entidadId: $prestamo->id,
            datosAnteriores: null,
            datosNuevos: [
                'cliente_id' => $prestamo->cliente_id,
                'monto_capital' => $resultado['monto_capital'],
                'porcentaje_interes' => $prestamo->porcentaje_interes,
                'monto_extras' => $resultado['monto_extras'],
                'monto_total' => $resultado['monto_total'],
                'plazo_cuotas' => $prestamo->plazo_cuotas,
                'frecuencia_pago' => $prestamo->frecuencia_pago,
            ],
        );

        return response()->json([
            'data' => $prestamo->load(['extras', 'cuotas']),
        ], 201);
    }

    public function simular(SimularPrestamoRequest $request): JsonResponse
    {
        return response()->json([
            'data' => $this->calculator->calcular($request->validated()),
        ]);
    }

    public function show(Prestamo $prestamo): JsonResponse
    {
        $this->authorize('view', $prestamo);

        return response()->json([
            'data' => $prestamo->load(['cliente', 'extras', 'cuotas', 'pagos']),
        ]);
    }

    public function anular(Request $request, Prestamo $prestamo): JsonResponse
    {
        $this->authorize('update', $prestamo);

        if ($prestamo->estado === 'anulado') {
            return response()->json([
                'message' => 'Este préstamo ya se encuentra anulado.',
            ], 422);
        }

        $estadoAnterior = $prestamo->estado;
        $prestamo->update(['estado' => 'anulado']);

        $this->auditoria->registrar(
            usuario: $request->user(),
            accion: 'anular_prestamo',
            entidad: 'Prestamo',
            entidadId: $prestamo->id,
            datosAnteriores: ['estado' => $estadoAnterior],
            datosNuevos: ['estado' => 'anulado'],
        );

        return response()->json(['data' => $prestamo]);
    }

    public function pagos(Prestamo $prestamo): JsonResponse
    {
        $this->authorize('view', $prestamo);

        return response()->json([
            'data' => $prestamo->pagos()->orderBy('fecha_pago')->orderBy('id')->get(),
        ]);
    }
}
