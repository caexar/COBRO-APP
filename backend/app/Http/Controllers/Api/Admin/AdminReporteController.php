<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Services\ExportarReporteService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;

/**
 * `GET /api/admin/reporte`: los mismos 3 bloques (préstamos, resumen por cobrador,
 * movimientos de capital) que `ExportarReporteService::generarXlsx()` ya arma para el panel
 * web, pero como JSON en vez de un archivo .xlsx — consumido por el panel admin móvil, que
 * arma su propio CSV con estos datos (ver `AdminReportesRepository` en Flutter) porque ahí un
 * CSV es más liviano/compatible para compartir por WhatsApp/correo que un .xlsx.
 */
class AdminReporteController extends Controller
{
    public function index(Request $request, ExportarReporteService $servicio): JsonResponse
    {
        $datos = $request->validate([
            'usuario_ids' => ['required', 'array', 'min:1'],
            'usuario_ids.*' => ['integer', Rule::exists('users', 'id')->where(fn ($query) => $query->where('rol', 'cobrador'))],
            'desde' => ['nullable', 'date'],
            'hasta' => ['nullable', 'date', 'after_or_equal:desde'],
            'categoria' => ['nullable', 'in:gasto_operativo,decision_jefe,salario,otro'],
        ]);

        $desde = filled($datos['desde'] ?? null) ? Carbon::parse($datos['desde'])->startOfDay() : null;
        $hasta = filled($datos['hasta'] ?? null) ? Carbon::parse($datos['hasta'])->endOfDay() : null;

        return response()->json([
            'data' => $servicio->datosReporte($datos['usuario_ids'], $desde, $hasta, $datos['categoria'] ?? null),
        ]);
    }
}
