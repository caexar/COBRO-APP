<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

/**
 * Misma condición de rol para los dos consumidores de la API/paneles de administración: la app
 * móvil (`auth:sanctum` + `role:admin|cobrador`) y el panel web (`auth` + `role:admin`, ver
 * `routes/web.php`). Solo cambia el formato de la respuesta de rechazo: JSON para la API,
 * redirect con mensaje claro para el panel web — nunca se reimplementa el chequeo de rol dos
 * veces, ver CLAUDE.md.
 */
class EnsureUserHasRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if ($user && in_array($user->rol, $roles, true)) {
            return $next($request);
        }

        if ($request->is('api/*')) {
            return response()->json([
                'message' => 'No tienes permiso para acceder a este recurso.',
            ], 403);
        }

        // Panel web: un cobrador (o cualquier rol sin permiso) que llega hasta acá no debe
        // quedarse con una sesión "a medias" — se cierra y se manda de vuelta al login con un
        // mensaje claro, en vez de un 403 crudo sin contexto.
        Auth::guard('web')->logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('admin.login')->with(
            'error',
            'Tu cuenta no tiene permisos de administrador para acceder a este panel.',
        );
    }
}
