<?php

use App\Http\Controllers\Admin\AdminAuthController;
use App\Http\Controllers\Admin\AdminExportarController;
use App\Models\User;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

/*
|--------------------------------------------------------------------------
| Panel de administración web (Livewire)
|--------------------------------------------------------------------------
|
| Costo cero adicional: vive en el mismo proyecto/despliegue que la API móvil, sesión propia
| (guard `web`), separada del token de Sanctum que usa el móvil. Todo bajo /admin/*, protegido
| por `role:admin` salvo el login — ver App\Http\Middleware\EnsureUserHasRole.
*/
Route::prefix('admin')->name('admin.')->group(function () {
    Route::get('login', [AdminAuthController::class, 'mostrarFormulario'])->name('login');
    Route::post('login', [AdminAuthController::class, 'iniciarSesion'])->name('login.submit');
    Route::post('logout', [AdminAuthController::class, 'cerrarSesion'])->middleware('auth')->name('logout');

    Route::middleware(['auth', 'role:admin'])->group(function () {
        Route::redirect('/', '/admin/usuarios')->name('home');

        Route::get('usuarios', function () {
            return view('admin.usuarios.index');
        })->name('usuarios.index');

        Route::get('usuarios/crear', function () {
            return view('admin.usuarios.formulario');
        })->name('usuarios.crear');

        Route::get('usuarios/{usuario}/editar', function (User $usuario) {
            return view('admin.usuarios.formulario', ['usuario' => $usuario]);
        })->name('usuarios.editar');

        Route::get('resumen', function () {
            return view('admin.resumen.index');
        })->name('resumen');

        Route::get('resumen/{usuario}', function (User $usuario) {
            abort_if($usuario->rol !== 'cobrador', 404, 'El usuario indicado no es un cobrador.');

            return view('admin.resumen.detalle', ['usuario' => $usuario]);
        })->name('resumen.detalle');

        Route::get('configuracion', function () {
            return view('admin.configuracion.index');
        })->name('configuracion');

        Route::get('auditoria', function () {
            return view('admin.auditoria.index');
        })->name('auditoria');

        Route::get('exportar', [AdminExportarController::class, 'formulario'])->name('exportar');
        Route::post('exportar', [AdminExportarController::class, 'descargar'])->name('exportar.descargar');
    });
});
