<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\ExportarReporteService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

/**
 * Exportar CSV desde el panel web: rango de fechas + selección de uno, varios o todos los
 * cobradores. Es un formulario HTML simple (sin Livewire) que descarga el archivo directamente
 * —no hace falta compartir como en mobile, solo un `Content-Disposition: attachment`—, así que
 * no necesita el round-trip de un componente reactivo.
 */
class AdminExportarController extends Controller
{
    public function formulario(): View
    {
        return view('admin.exportar.index', [
            'cobradores' => User::where('rol', 'cobrador')->orderBy('nombre')->get(),
        ]);
    }

    public function descargar(Request $request, ExportarReporteService $servicio): Response|RedirectResponse
    {
        $datos = $request->validate([
            'usuario_ids' => ['required', 'array', 'min:1'],
            'usuario_ids.*' => ['integer', Rule::exists('users', 'id')->where(fn ($query) => $query->where('rol', 'cobrador'))],
            'desde' => ['nullable', 'date'],
            'hasta' => ['nullable', 'date', 'after_or_equal:desde'],
        ]);

        $desde = filled($datos['desde'] ?? null) ? Carbon::parse($datos['desde'])->startOfDay() : null;
        $hasta = filled($datos['hasta'] ?? null) ? Carbon::parse($datos['hasta'])->endOfDay() : null;

        $csv = $servicio->generarCsv($datos['usuario_ids'], $desde, $hasta);
        $nombreArchivo = 'cobro_app_reporte_admin_'.now()->format('Ymd_His').'.csv';

        return response($csv, 200, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => 'attachment; filename="'.$nombreArchivo.'"',
        ]);
    }
}
