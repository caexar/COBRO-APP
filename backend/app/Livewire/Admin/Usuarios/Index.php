<?php

namespace App\Livewire\Admin\Usuarios;

use App\Exceptions\UsuarioAdminException;
use App\Models\User;
use App\Services\UsuarioAdminService;
use Livewire\Component;

/**
 * Listado de usuarios (cobradores y admins) con activar/desactivar en línea. Las mutaciones
 * (desactivar/reactivar) llaman a `UsuarioAdminService` — la misma lógica que ya usa
 * `Api\Admin\AdminUsuarioController` para el móvil, incluida la auditoría.
 */
class Index extends Component
{
    public ?string $mensaje = null;

    public ?string $error = null;

    public function activar(int $usuarioId): void
    {
        $this->cambiarEstado($usuarioId, reactivar: true);
    }

    public function desactivar(int $usuarioId): void
    {
        $this->cambiarEstado($usuarioId, reactivar: false);
    }

    private function cambiarEstado(int $usuarioId, bool $reactivar): void
    {
        $usuario = User::findOrFail($usuarioId);
        $actor = auth('web')->user();
        $servicio = app(UsuarioAdminService::class);

        $this->mensaje = null;
        $this->error = null;

        try {
            if ($reactivar) {
                $servicio->reactivar($usuario, $actor);
                $this->mensaje = "Usuario \"{$usuario->nombre}\" reactivado correctamente.";
            } else {
                $servicio->desactivar($usuario, $actor);
                $this->mensaje = "Usuario \"{$usuario->nombre}\" desactivado correctamente.";
            }
        } catch (UsuarioAdminException $e) {
            $this->error = $e->getMessage();
        }
    }

    public function render()
    {
        return view('livewire.admin.usuarios.index', [
            'usuarios' => User::orderBy('nombre')->get(),
        ]);
    }
}
