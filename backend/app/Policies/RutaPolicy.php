<?php

namespace App\Policies;

use App\Models\Ruta;
use App\Models\User;

/**
 * A diferencia de ClientePolicy/PrestamoPolicy, una ruta no tiene lectura de admin — es una
 * herramienta puramente organizativa del propio cobrador, sin ningún endpoint `/admin/*` que la
 * consuma (ver CLAUDE.md si eso cambia en el futuro).
 */
class RutaPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->isCobrador();
    }

    public function view(User $user, Ruta $ruta): bool
    {
        return $ruta->usuario_id === $user->id;
    }

    public function create(User $user): bool
    {
        return $user->isCobrador();
    }

    public function update(User $user, Ruta $ruta): bool
    {
        return $ruta->usuario_id === $user->id;
    }

    public function delete(User $user, Ruta $ruta): bool
    {
        return $ruta->usuario_id === $user->id;
    }
}
