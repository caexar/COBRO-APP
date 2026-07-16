<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CargaCapital;
use App\Models\Cliente;
use App\Models\Pago;
use App\Models\Prestamo;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RestaurarController extends Controller
{
    /**
     * Recuperación de datos para un dispositivo nuevo (o con la app reinstalada): devuelve,
     * en un solo payload, todo lo que le pertenece al cobrador autenticado —nunca de otro—
     * para que la app lo inserte de una vez en Drift como ya sincronizado. Misma forma de
     * serializar que ya usan `GET /clientes`, `GET /prestamos/{id}` y
     * `GET /admin/usuarios/{id}/detalle` (modelos Eloquent tal cual, sin Resource/Transformer
     * propio): no se inventa un formato nuevo.
     *
     * A diferencia de `POST /sync` (incremental, sube la cola local), este endpoint es de
     * solo lectura y de una sola vía: el móvil nunca sube nada acá, solo descarga el estado
     * completo actual del servidor.
     */
    public function index(Request $request): JsonResponse
    {
        $usuario = $request->user();

        $clientes = Cliente::where('usuario_id', $usuario->id)->orderBy('nombre')->get();

        $prestamos = Prestamo::where('usuario_id', $usuario->id)->with(['extras', 'cuotas'])->get();

        $pagos = Pago::whereIn('prestamo_id', $prestamos->pluck('id'))->get();

        // Se marcan como descargadas en la misma operación (antes de leerlas) para que el
        // próximo POST /sync normal no las vuelva a ofrecer como pendientes de un admin —
        // mismo campo y mismo criterio que ya usa SyncService::cargasCapitalAdminPendientes().
        CargaCapital::where('usuario_id', $usuario->id)
            ->where('origen', 'admin')
            ->where('descargado', false)
            ->update(['descargado' => true]);

        $cargasCapital = CargaCapital::where('usuario_id', $usuario->id)->get();

        return response()->json([
            'data' => [
                'clientes' => $clientes,
                'prestamos' => $prestamos,
                'pagos' => $pagos,
                'cargas_capital' => $cargasCapital,
            ],
        ]);
    }
}
