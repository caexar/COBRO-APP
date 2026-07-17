<?php

namespace App\Support;

/**
 * `AuditoriaLogger` nunca debería registrar un PIN en texto plano (ver CLAUDE.md,
 * `actualizar_configuracion` solo guarda si cambió, no su valor) — esto es una defensa extra
 * puramente de presentación para el visor de auditoría: si alguna clave de `datos_anteriores`/
 * `datos_nuevos` menciona "pin", se oculta su valor al mostrarlo, sin tocar el dato guardado.
 */
class AuditoriaPresentador
{
    /**
     * @param  array<string, mixed>|null  $datos
     * @return array<string, mixed>|null
     */
    public static function datosSeguros(?array $datos): ?array
    {
        if ($datos === null) {
            return null;
        }

        $resultado = [];
        foreach ($datos as $clave => $valor) {
            $resultado[$clave] = str_contains(strtolower((string) $clave), 'pin') ? '(oculto)' : $valor;
        }

        return $resultado;
    }
}
