<?php

namespace App\Policies;

use App\Models\Cliente;
use App\Models\User;

class ClientePolicy
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
     * Admin puede ver cualquier cliente (solo lectura).
     * Cobrador solo puede ver los clientes de su propiedad.
     */
    public function view(User $user, Cliente $cliente): bool
    {
        if ($user->isAdmin()) {
            return true;
        }

        return $cliente->usuario_id === $user->id;
    }

    /**
     * Crear clientes es una operación exclusiva del cobrador dueño de la cartera.
     * El admin gestiona datos operativos desde sus propios endpoints.
     */
    public function create(User $user): bool
    {
        return $user->isCobrador();
    }

    public function update(User $user, Cliente $cliente): bool
    {
        return $user->isCobrador() && $cliente->usuario_id === $user->id;
    }

    public function delete(User $user, Cliente $cliente): bool
    {
        return $user->isCobrador() && $cliente->usuario_id === $user->id;
    }
}
