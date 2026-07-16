<?php

namespace Tests\Feature\Admin;

use App\Models\Auditoria;
use App\Models\CargaCapital;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminCargaCapitalControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_un_admin_puede_asignar_capital_a_un_cobrador(): void
    {
        $admin = User::factory()->admin()->create();
        $cobrador = User::factory()->create();

        Sanctum::actingAs($admin);

        $respuesta = $this->postJson('/api/admin/cargas-capital', [
            'usuario_id' => $cobrador->id,
            'tipo' => 'carga',
            'monto' => 500000,
            'descripcion' => 'Fondeo inicial',
        ]);

        $respuesta->assertCreated();
        $respuesta->assertJsonPath('data.usuario_id', $cobrador->id);
        $respuesta->assertJsonPath('data.tipo', 'carga');
        $respuesta->assertJsonPath('data.origen', 'admin');
        $respuesta->assertJsonPath('data.creado_por_usuario_id', $admin->id);

        $this->assertDatabaseHas('cargas_capital', [
            'usuario_id' => $cobrador->id,
            'monto' => 500000,
            'tipo' => 'carga',
            'origen' => 'admin',
            'creado_por_usuario_id' => $admin->id,
        ]);

        $this->assertDatabaseHas('auditoria', [
            'usuario_id' => $admin->id,
            'accion' => 'asignar_capital',
            'entidad' => 'CargaCapital',
        ]);
    }

    public function test_un_admin_puede_registrar_un_retiro_para_un_cobrador(): void
    {
        $admin = User::factory()->admin()->create();
        $cobrador = User::factory()->create();

        Sanctum::actingAs($admin);

        $respuesta = $this->postJson('/api/admin/cargas-capital', [
            'usuario_id' => $cobrador->id,
            'tipo' => 'retiro',
            'monto' => 20000,
        ]);

        $respuesta->assertCreated();
        $respuesta->assertJsonPath('data.tipo', 'retiro');
    }

    public function test_un_cobrador_no_puede_usar_este_endpoint(): void
    {
        $cobrador = User::factory()->create();
        $otroCobrador = User::factory()->create();

        Sanctum::actingAs($cobrador);

        $respuesta = $this->postJson('/api/admin/cargas-capital', [
            'usuario_id' => $otroCobrador->id,
            'tipo' => 'carga',
            'monto' => 1000,
        ]);

        $respuesta->assertForbidden();
        $this->assertDatabaseCount('cargas_capital', 0);
    }

    public function test_usuario_id_debe_ser_un_cobrador_existente(): void
    {
        $admin = User::factory()->admin()->create();
        $otroAdmin = User::factory()->admin()->create();

        Sanctum::actingAs($admin);

        $respuesta = $this->postJson('/api/admin/cargas-capital', [
            'usuario_id' => $otroAdmin->id,
            'tipo' => 'carga',
            'monto' => 1000,
        ]);

        $respuesta->assertUnprocessable();
        $respuesta->assertJsonValidationErrors('usuario_id');
    }

    public function test_tipo_debe_ser_carga_o_retiro(): void
    {
        $admin = User::factory()->admin()->create();
        $cobrador = User::factory()->create();

        Sanctum::actingAs($admin);

        $respuesta = $this->postJson('/api/admin/cargas-capital', [
            'usuario_id' => $cobrador->id,
            'tipo' => 'invalido',
            'monto' => 1000,
        ]);

        $respuesta->assertUnprocessable();
        $respuesta->assertJsonValidationErrors('tipo');
    }
}
