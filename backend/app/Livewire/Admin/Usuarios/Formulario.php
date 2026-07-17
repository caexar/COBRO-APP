<?php

namespace App\Livewire\Admin\Usuarios;

use App\Exceptions\UsuarioAdminException;
use App\Models\User;
use App\Services\UsuarioAdminService;
use Illuminate\Validation\Rule;
use Livewire\Component;

/**
 * Crear/editar un usuario (cobrador o admin) — un solo componente para ambos modos, según si
 * [usuario] llega o no en `mount()`. Llama a `UsuarioAdminService` (misma lógica que ya usa
 * `Api\Admin\AdminUsuarioController`): PIN por defecto "0000" al crear si se omite, y al editar
 * nunca se toca `activo` (eso vive exclusivamente en `Index::activar/desactivar`) ni se cambian
 * password/pin si el campo queda en blanco.
 */
class Formulario extends Component
{
    public ?User $usuario = null;

    public string $nombre = '';

    public string $email = '';

    public string $password = '';

    public string $rol = 'cobrador';

    public string $pin = '';

    public ?string $error = null;

    public function mount(?User $usuario = null): void
    {
        $this->usuario = $usuario;

        if ($usuario) {
            $this->nombre = $usuario->nombre;
            $this->email = $usuario->email;
            $this->rol = $usuario->rol;
        }
    }

    /**
     * @return array<string, mixed>
     */
    protected function rules(): array
    {
        $emailUnico = Rule::unique('users', 'email');
        if ($this->usuario) {
            $emailUnico = $emailUnico->ignore($this->usuario->id);
        }

        return [
            'nombre' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', $emailUnico],
            'password' => [$this->usuario ? 'nullable' : 'required', 'string', 'min:8'],
            'rol' => ['required', 'in:admin,cobrador'],
            'pin' => ['nullable', 'string', 'min:4', 'max:10'],
        ];
    }

    public function guardar(): void
    {
        $datos = $this->validate();
        $actor = auth('web')->user();
        $servicio = app(UsuarioAdminService::class);

        try {
            if ($this->usuario) {
                $cambios = collect($datos)->only(['nombre', 'email', 'rol'])->all();
                if (filled($datos['password'])) {
                    $cambios['password'] = $datos['password'];
                }
                if (filled($datos['pin'])) {
                    $cambios['pin'] = $datos['pin'];
                }

                $servicio->actualizar($this->usuario, $cambios, $actor);
                session()->flash('status', 'Usuario actualizado correctamente.');
            } else {
                // Un campo de PIN vacío en el formulario debe comportarse como si no se hubiera
                // enviado (`crear()` solo aplica el default "0000" cuando la clave es null, no
                // cuando es un string vacío).
                if (! filled($datos['pin'])) {
                    $datos['pin'] = null;
                }

                $servicio->crear($datos, $actor);
                session()->flash('status', 'Usuario creado correctamente.');
            }
        } catch (UsuarioAdminException $e) {
            $this->error = $e->getMessage();

            return;
        }

        $this->redirect(route('admin.usuarios.index'), navigate: true);
    }

    public function render()
    {
        return view('livewire.admin.usuarios.formulario');
    }
}
