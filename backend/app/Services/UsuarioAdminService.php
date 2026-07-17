<?php

namespace App\Services;

use App\Exceptions\UsuarioAdminException;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

/**
 * Toda la lógica de gestión de usuarios (cobradores y admins) desde el panel de administración:
 * única fuente de verdad, usada tanto por `Api\Admin\AdminUsuarioController` (móvil) como por los
 * componentes Livewire del panel web (`App\Livewire\Admin\Usuarios\*`) — para no reimplementar
 * reglas de negocio (PIN por defecto, protección de auto-desactivación, auditoría) en dos lugares.
 */
class UsuarioAdminService
{
    public function __construct(
        private readonly AuditoriaLogger $auditoria,
    ) {}

    /**
     * @param  array<string, mixed>  $datos  nombre, email, password, rol, pin (opcional, "0000"
     *                                        por defecto), pin_maestro (opcional)
     */
    public function crear(array $datos, User $actor): User
    {
        $usuario = User::create([
            'nombre' => $datos['nombre'],
            'email' => $datos['email'],
            'password' => $datos['password'],
            'rol' => $datos['rol'],
            'pin_hash' => Hash::make($datos['pin'] ?? '0000'),
            'pin_maestro_hash' => isset($datos['pin_maestro']) ? Hash::make($datos['pin_maestro']) : null,
            'activo' => true,
        ]);

        $this->auditoria->registrar(
            usuario: $actor,
            accion: 'crear_usuario',
            entidad: 'User',
            entidadId: $usuario->id,
            datosAnteriores: null,
            datosNuevos: ['nombre' => $usuario->nombre, 'email' => $usuario->email, 'rol' => $usuario->rol],
        );

        return $usuario;
    }

    /**
     * [$datos] solo debe incluir lo que realmente cambió (nombre/email/rol/password/pin/
     * pin_maestro) — nunca `activo`, eso es exclusivo de [desactivar]/[reactivar].
     *
     * @param  array<string, mixed>  $datos
     */
    public function actualizar(User $usuario, array $datos, User $actor): User
    {
        $anterior = $usuario->only(['nombre', 'email', 'rol']);
        $cambios = collect($datos)->only(['nombre', 'email', 'rol', 'password'])->all();

        if (array_key_exists('pin', $datos)) {
            $cambios['pin_hash'] = Hash::make($datos['pin']);
        }

        if (array_key_exists('pin_maestro', $datos)) {
            $cambios['pin_maestro_hash'] = $datos['pin_maestro'] !== null ? Hash::make($datos['pin_maestro']) : null;
        }

        $usuario->update($cambios);

        $this->auditoria->registrar(
            usuario: $actor,
            accion: 'actualizar_usuario',
            entidad: 'User',
            entidadId: $usuario->id,
            datosAnteriores: $anterior,
            datosNuevos: $usuario->only(['nombre', 'email', 'rol']),
        );

        return $usuario;
    }

    /**
     * @throws UsuarioAdminException si el actor intenta desactivarse a sí mismo, o si el usuario
     *                                ya estaba desactivado.
     */
    public function desactivar(User $usuario, User $actor): User
    {
        if ($usuario->id === $actor->id) {
            throw new UsuarioAdminException('No puedes desactivar tu propio usuario.');
        }

        if (! $usuario->activo) {
            throw new UsuarioAdminException('Este usuario ya está desactivado.');
        }

        $usuario->update(['activo' => false]);

        $this->auditoria->registrar(
            usuario: $actor,
            accion: 'desactivar_usuario',
            entidad: 'User',
            entidadId: $usuario->id,
            datosAnteriores: ['activo' => true],
            datosNuevos: ['activo' => false],
        );

        return $usuario;
    }

    /**
     * @throws UsuarioAdminException si el usuario ya estaba activo.
     */
    public function reactivar(User $usuario, User $actor): User
    {
        if ($usuario->activo) {
            throw new UsuarioAdminException('Este usuario ya está activo.');
        }

        $usuario->update(['activo' => true]);

        $this->auditoria->registrar(
            usuario: $actor,
            accion: 'reactivar_usuario',
            entidad: 'User',
            entidadId: $usuario->id,
            datosAnteriores: ['activo' => false],
            datosNuevos: ['activo' => true],
        );

        return $usuario;
    }
}
