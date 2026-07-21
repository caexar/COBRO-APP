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

    /**
     * Interpreta lo que un admin escribió en un campo de monto según su preferencia de
     * "atajo de miles" (`users.atajo_miles_activado`, ver `App\Livewire\Admin\Resumen\
     * DetalleCobrador`): si está activada, el valor escrito se multiplica por 1000 (ej.
     * "300" al guardar se persiste como 300000); si no, se usa tal cual. Equivalente web de
     * `interpretarValorIngresado()` en `mobile/lib/core/utils/formato_dinero.dart` — mismo
     * criterio, ningún campo de monto nuevo del panel debe reimplementarlo. No afecta en
     * absoluto la visualización de montos ya guardados (`Dinero::formatear()`).
     */
    public static function interpretarValorIngresado(?float $valor, bool $atajoMilesActivado): ?float
    {
        if ($valor === null) {
            return null;
        }

        return $atajoMilesActivado ? $valor * 1000 : $valor;
    }
}
