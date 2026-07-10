<?php

namespace App\Services;

use App\Models\Auditoria;
use App\Models\User;

class AuditoriaLogger
{
    /**
     * @param  array<string, mixed>|null  $datosAnteriores
     * @param  array<string, mixed>|null  $datosNuevos
     */
    public function registrar(
        User $usuario,
        string $accion,
        string $entidad,
        int $entidadId,
        ?array $datosAnteriores,
        ?array $datosNuevos,
    ): Auditoria {
        return Auditoria::create([
            'usuario_id' => $usuario->id,
            'accion' => $accion,
            'entidad' => $entidad,
            'entidad_id' => $entidadId,
            'datos_anteriores' => $datosAnteriores,
            'datos_nuevos' => $datosNuevos,
        ]);
    }
}
