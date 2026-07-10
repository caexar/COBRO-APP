<?php

use App\Http\Controllers\Api\ClienteController;
use App\Http\Controllers\Api\PagoController;
use App\Http\Controllers\Api\PrestamoController;
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
    });
});
