<?php

namespace Tests\Feature\Admin;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Guard web (sesión) + middleware de rol del panel de administración: coexiste con el guard
 * `sanctum` de la API móvil sin tocarlo (ver SyncControllerTest, AdminCargaCapitalControllerTest,
 * etc., que siguen usando Sanctum::actingAs sin cambios).
 */
class AdminPanelAccessTest extends TestCase
{
    use RefreshDatabase;

    public function test_un_visitante_sin_sesion_es_redirigido_al_login_del_panel(): void
    {
        $respuesta = $this->get('/admin/usuarios');

        $respuesta->assertRedirect(route('admin.login'));
    }

    public function test_un_admin_puede_entrar_al_panel(): void
    {
        $admin = User::factory()->admin()->create();

        $respuesta = $this->actingAs($admin)->get('/admin/usuarios');

        $respuesta->assertOk();
    }

    public function test_un_cobrador_es_rechazado_con_un_mensaje_claro_y_no_un_403_crudo(): void
    {
        $cobrador = User::factory()->create();

        $respuesta = $this->actingAs($cobrador)->get('/admin/usuarios');

        $respuesta->assertRedirect(route('admin.login'));
        $respuesta->assertSessionHas('error');
        $this->assertGuest();
    }

    public function test_login_web_crea_una_sesion_independiente_del_token_sanctum_de_la_api(): void
    {
        $admin = User::factory()->admin()->create(['password' => 'password-valido']);

        $respuesta = $this->post('/admin/login', [
            'email' => $admin->email,
            'password' => 'password-valido',
        ]);

        $respuesta->assertRedirect(route('admin.usuarios.index'));
        $this->assertAuthenticatedAs($admin, 'web');

        // El login web no emite ni depende de un token de Sanctum.
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_login_web_con_credenciales_invalidas_no_inicia_sesion(): void
    {
        $admin = User::factory()->admin()->create(['password' => 'password-valido']);

        $respuesta = $this->post('/admin/login', [
            'email' => $admin->email,
            'password' => 'incorrecta',
        ]);

        $respuesta->assertSessionHasErrors('email');
        $this->assertGuest('web');
    }
}
