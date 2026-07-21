<?php

use App\Http\Controllers\Api\Admin\AdminCargaCapitalController;
use App\Http\Controllers\Api\Admin\AdminConfiguracionController;
use App\Http\Controllers\Api\Admin\AdminReporteController;
use App\Http\Controllers\Api\Admin\AdminResumenController;
use App\Http\Controllers\Api\Admin\AdminUsuarioController;
use App\Http\Controllers\Api\CargaCapitalController;
use App\Http\Controllers\Api\CierreCajaController;
use App\Http\Controllers\Api\ClienteController;
use App\Http\Controllers\Api\PagoController;
use App\Http\Controllers\Api\PinMaestroController;
use App\Http\Controllers\Api\PrestamoController;
use App\Http\Controllers\Api\RestaurarController;
use App\Http\Controllers\Api\SyncController;
use App\Http\Controllers\Auth\AuthController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);

    Route::get('/user', function (Request $request) {
        return $request->user();
    });

    Route::middleware('role:cobrador')->group(function () {
        Route::get('clientes', [ClienteController::class, 'index']);
        Route::post('clientes', [ClienteController::class, 'store']);
        Route::put('clientes/{cliente}', [ClienteController::class, 'update']);
        Route::delete('clientes/{cliente}', [ClienteController::class, 'destroy']);

        Route::post('prestamos', [PrestamoController::class, 'store']);
        Route::post('prestamos/simular', [PrestamoController::class, 'simular']);
        Route::get('prestamos/{prestamo}', [PrestamoController::class, 'show']);
        Route::put('prestamos/{prestamo}/anular', [PrestamoController::class, 'anular']);
        Route::get('prestamos/{prestamo}/pagos', [PrestamoController::class, 'pagos']);

        Route::post('pagos', [PagoController::class, 'store']);

        Route::post('cargas-capital', [CargaCapitalController::class, 'store']);

        Route::get('cierres-caja', [CierreCajaController::class, 'index']);
        Route::post('cierres-caja', [CierreCajaController::class, 'store']);
        Route::get('cierres-caja/{cierreCaja}', [CierreCajaController::class, 'show']);

        Route::get('pin-maestro', [PinMaestroController::class, 'index']);

        Route::post('sync', [SyncController::class, 'store']);

        Route::get('restaurar', [RestaurarController::class, 'index']);
    });

    Route::middleware('role:admin')->prefix('admin')->group(function () {
        Route::get('usuarios', [AdminUsuarioController::class, 'index']);
        Route::post('usuarios', [AdminUsuarioController::class, 'store']);
        Route::put('usuarios/{usuario}', [AdminUsuarioController::class, 'update']);
        Route::put('usuarios/{usuario}/desactivar', [AdminUsuarioController::class, 'desactivar']);
        Route::put('usuarios/{usuario}/reactivar', [AdminUsuarioController::class, 'reactivar']);
        Route::get('usuarios/{usuario}/detalle', [AdminUsuarioController::class, 'detalle']);

        Route::get('resumen', [AdminResumenController::class, 'index']);
        Route::get('reporte', [AdminReporteController::class, 'index']);

        Route::get('configuracion', [AdminConfiguracionController::class, 'index']);
        Route::put('configuracion', [AdminConfiguracionController::class, 'update']);

        Route::post('cargas-capital', [AdminCargaCapitalController::class, 'store']);
    });
});
