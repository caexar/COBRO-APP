<?php

namespace App\Support;

/**
 * Mismo formato que `formatearMoneda()` del lado móvil (ver
 * `mobile/lib/core/utils/formato_dinero.dart`): sin decimales, separador de
 * miles con punto, prefijo "$ ". Único formateador de dinero para las vistas
 * Blade del panel admin — no reimplementar el formato en cada vista.
 */
class Dinero
{
    public static function formatear(float $valor): string
    {
        return '$ '.number_format((int) $valor, 0, '', '.');
    }
}
