<?php

namespace Tests\Feature\Admin;

use App\Livewire\Admin\Usuarios\Formulario;
use App\Livewire\Admin\Usuarios\Index;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Livewire\Livewire;
use Tests\TestCase;

/**
 * CRUD básico de usuarios desde el panel web (Livewire), reutilizando
 * `UsuarioAdminService` — misma lógica de negocio que ya cubren los tests de
 * `Api\Admin\AdminUsuarioController` (PIN por defecto, protección de
 * auto-desactivación, auditoría), así que acá solo se prueba el flujo desde
 * los componentes Livewire, sin repetir esa cobertura.
 */
class UsuariosLivewireTest extends TestCase
{
    use RefreshDatabase;

    public function test_crear_un_usuario_desde_el_formulario_usa_pin_por_defecto_y_deja_auditoria(): void
    {
        $admin = User::factory()->admin()->create();

        Livewire::actingAs($admin)
            ->test(Formulario::class)
            ->set('nombre', 'Juan Perez')
            ->set('email', 'juan@cobroapp.test')
            ->set('password', 'password123')
            ->set('rol', 'cobrador')
            ->call('guardar')
            ->assertRedirect(route('admin.usuarios.index'));

        $usuario = User::where('email', 'juan@cobroapp.test')->firstOrFail();
        $this->assertTrue(Hash::check('0000', $usuario->pin_hash));
        $this->assertSame('cobrador', $usuario->rol);

        $this->assertDatabaseHas('auditoria', [
            'usuario_id' => $admin->id,
            'accion' => 'crear_usuario',
            'entidad' => 'User',
            'entidad_id' => $usuario->id,
        ]);
    }

    public function test_editar_un_usuario_no_permite_tocar_activo_y_conserva_password_si_se_deja_en_blanco(): void
    {
        $admin = User::factory()->admin()->create();
        $usuario = User::factory()->create(['nombre' => 'Nombre Viejo']);
        $hashOriginal = $usuario->password;

        Livewire::actingAs($admin)
            ->test(Formulario::class, ['usuario' => $usuario])
            ->assertSet('nombre', 'Nombre Viejo')
            ->set('nombre', 'Nombre Nuevo')
            ->set('email', $usuario->email)
            ->call('guardar')
            ->assertRedirect(route('admin.usuarios.index'));

        $usuario->refresh();
        $this->assertSame('Nombre Nuevo', $usuario->nombre);
        $this->assertSame($hashOriginal, $usuario->password);
        $this->assertTrue($usuario->activo);
    }

    public function test_desactivar_y_reactivar_un_usuario_desde_el_listado(): void
    {
        $admin = User::factory()->admin()->create();
        $cobrador = User::factory()->create();

        Livewire::actingAs($admin)
            ->test(Index::class)
            ->call('desactivar', $cobrador->id)
            ->assertSet('mensaje', "Usuario \"{$cobrador->nombre}\" desactivado correctamente.");

        $this->assertFalse($cobrador->fresh()->activo);

        Livewire::actingAs($admin)
            ->test(Index::class)
            ->call('activar', $cobrador->id)
            ->assertSet('mensaje', "Usuario \"{$cobrador->nombre}\" reactivado correctamente.");

        $this->assertTrue($cobrador->fresh()->activo);
    }

    public function test_un_admin_no_puede_desactivarse_a_si_mismo_desde_el_listado(): void
    {
        $admin = User::factory()->admin()->create();

        Livewire::actingAs($admin)
            ->test(Index::class)
            ->call('desactivar', $admin->id)
            ->assertSet('error', 'No puedes desactivar tu propio usuario.');

        $this->assertTrue($admin->fresh()->activo);
    }
}
