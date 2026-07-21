<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Services\ExportarReporteService;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;

/**
 * `GET /api/admin/reporte`: el mismo .xlsx de 5 hojas (préstamos, resumen por cobrador,
 * movimientos de capital, cierre de caja y su resumen agregado) que ya descarga el panel web
 * en `POST /admin/exportar` — mismo `ExportarReporteService::generarXlsx()`, sin reimplementar
 * nada. Antes este endpoint devolvía JSON y el panel admin móvil armaba su propio CSV con esos
 * datos (`AdminReportesRepository`); se cambió a servir el .xlsx tal cual (igual que la web)
 * para no tener que generar ni mantener un export en Dart — mobile solo descarga los bytes y
 * los comparte con `share_plus`.
 */
class AdminReporteController extends Controller
{
    public function index(Request $request, ExportarReporteService $servicio): Response
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

        $xlsx = $servicio->generarXlsx($datos['usuario_ids'], $desde, $hasta, $datos['categoria'] ?? null);
        $nombreArchivo = 'cobro_app_reporte_admin_'.now()->format('Ymd_His').'.xlsx';

        return response($xlsx, 200, [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'Content-Disposition' => 'attachment; filename="'.$nombreArchivo.'"',
        ]);
    }
}
