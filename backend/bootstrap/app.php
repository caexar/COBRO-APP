<?php

use App\Http\Middleware\EnsureUserHasRole;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'role' => EnsureUserHasRole::class,
        ]);

        // Laravel Cloud (como cualquier PaaS gestionado) sirve la app detrás de un balanceador
        // que termina TLS y reenvía la petición por HTTP interno con cabeceras X-Forwarded-*.
        // Sin confiar en ese proxy, Request::isSecure() vería HTTP y rompería todo lo que
        // depende de detectar HTTPS (SESSION_SECURE_COOKIE, URLs absolutas con https://,
        // redirects). '*' confía en cualquier proxy inmediato — la práctica estándar
        // recomendada por Laravel para este tipo de entornos, donde no se conoce la IP fija
        // del balanceador de antemano.
        $middleware->trustProxies(at: '*');

        // El panel de administración web (routes/web.php) es la única autenticación basada en
        // sesión de esta app — la API móvil siempre habla JSON (auth:sanctum, nunca pasa por
        // acá porque expectsJson() es true). Sin esto, un acceso no autenticado a /admin/*
        // fallaría con RouteNotFoundException al buscar la ruta 'login' por defecto de Laravel.
        $middleware->redirectGuestsTo(fn () => route('admin.login'));
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*'),
        );
    })->create();
