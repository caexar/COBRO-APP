<?php

namespace App\Policies;

use App\Models\Prestamo;
use App\Models\User;

class PrestamoPolicy
{
    /**
     * Admin y cobrador pueden listar; el filtrado por usuario_id (cobrador)
     * o sin filtro (admin) lo aplica el controlador sobre la query.
     */
    public function viewAny(User $user): bool
    {
        return true;
    }

    /**
     * Admin puede ver cualquier préstamo (solo lectura).
     * Cobrador solo puede ver los préstamos de sus propios clientes.
     */
    public function view(User $user, Prestamo $prestamo): bool
    {
        if ($user->isAdmin()) {
            return true;
        }

        return $prestamo->usuario_id === $user->id;
    }

    /**
     * Crear préstamos es una operación exclusiva del cobrador dueño de la cartera.
     * El admin gestiona datos operativos desde sus propios endpoints.
     */
    public function create(User $user): bool
    {
        return $user->isCobrador();
    }

    public function update(User $user, Prestamo $prestamo): bool
    {
        return $user->isCobrador() && $prestamo->usuario_id === $user->id;
    }

    public function delete(User $user, Prestamo $prestamo): bool
    {
        return $user->isCobrador() && $prestamo->usuario_id === $user->id;
    }
}
