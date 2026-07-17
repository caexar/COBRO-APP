<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

/**
 * Login/logout del panel de administración web: sesión (guard `web`), completamente aparte del
 * login de la app móvil (`Api\Auth\AuthController`, token de Sanctum). No hay Policy de objeto
 * acá — el único filtro es el middleware `role:admin` sobre las rutas protegidas (ver
 * `routes/web.php`), así que cualquier credencial válida puede iniciar sesión web; un cobrador
 * que lo intente entra pero es rechazado (con mensaje) apenas toca una ruta protegida.
 */
class AdminAuthController extends Controller
{
    public function mostrarFormulario(): RedirectResponse|View
    {
        if (Auth::guard('web')->check()) {
            return redirect()->route('admin.usuarios.index');
        }

        return view('admin.auth.login');
    }

    public function iniciarSesion(Request $request): RedirectResponse
    {
        $credenciales = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        if (! Auth::guard('web')->attempt($credenciales, $request->boolean('recordarme'))) {
            throw ValidationException::withMessages([
                'email' => 'Las credenciales no coinciden con ningún registro.',
            ]);
        }

        $request->session()->regenerate();

        return redirect()->intended(route('admin.usuarios.index'));
    }

    public function cerrarSesion(Request $request): RedirectResponse
    {
        Auth::guard('web')->logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('admin.login');
    }
}
