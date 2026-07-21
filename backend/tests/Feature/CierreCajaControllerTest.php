<?php

namespace Tests\Feature;

use App\Models\CierreCaja;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CierreCajaControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_crea_un_cierre_de_caja_con_justificacion_y_gastos_derivando_el_total(): void
    {
        $cobrador = User::factory()->create();
        Sanctum::actingAs($cobrador);

        $respuesta = $this->postJson('/api/cierres-caja', [
            'fecha' => '2026-07-21',
            'capital_inicio' => 100000,
            'capital_cierre' => 150000,
            'justificacion_diferencia' => 'Se contó mal el efectivo inicial',
            'gastos' => [
                ['monto' => 10000, 'detalle' => 'almuerzo'],
                ['monto' => 25000, 'detalle' => 'gasolina'],
            ],
        ]);

        $respuesta->assertCreated();
        // `gastos_total` tiene cast decimal:2 en el modelo — se serializa como string en JSON.
        $respuesta->assertJsonPath('data.gastos_total', '35000.00');
        $respuesta->assertJsonPath('data.justificacion_diferencia', 'Se contó mal el efectivo inicial');
        $respuesta->assertJsonCount(2, 'data.gastos');

        $this->assertDatabaseHas('cierres_caja', [
            'usuario_id' => $cobrador->id,
            'capital_inicio' => 100000,
            'capital_cierre' => 150000,
            'gastos_total' => 35000,
        ]);
        $this->assertDatabaseCount('cierre_caja_gastos', 2);

        $this->assertDatabaseHas('auditoria', [
            'accion' => 'registrar_cierre_caja',
            'entidad' => 'CierreCaja',
        ]);
    }

    public function test_crea_un_cierre_sin_gastos_ni_justificacion(): void
    {
        $cobrador = User::factory()->create();
        Sanctum::actingAs($cobrador);

        $respuesta = $this->postJson('/api/cierres-caja', [
            'fecha' => '2026-07-21',
            'capital_inicio' => 100000,
            'capital_cierre' => 100000,
        ]);

        $respuesta->assertCreated();
        $respuesta->assertJsonPath('data.gastos_total', '0.00');
        $respuesta->assertJsonPath('data.justificacion_diferencia', null);
        $respuesta->assertJsonCount(0, 'data.gastos');
    }

    public function test_index_solo_devuelve_los_cierres_del_cobrador_autenticado(): void
    {
        $cobrador = User::factory()->create();
        $otro = User::factory()->create();

        CierreCaja::create([
            'usuario_id' => $cobrador->id, 'fecha' => '2026-07-20', 'capital_inicio' => 1000, 'capital_cierre' => 2000,
        ]);
        CierreCaja::create([
            'usuario_id' => $otro->id, 'fecha' => '2026-07-20', 'capital_inicio' => 1000, 'capital_cierre' => 2000,
        ]);

        Sanctum::actingAs($cobrador);
        $respuesta = $this->getJson('/api/cierres-caja');

        $respuesta->assertOk();
        $respuesta->assertJsonCount(1, 'data');
    }

    public function test_un_admin_no_puede_usar_este_endpoint(): void
    {
        $admin = User::factory()->admin()->create();
        Sanctum::actingAs($admin);

        $respuesta = $this->postJson('/api/cierres-caja', [
            'fecha' => '2026-07-21', 'capital_inicio' => 100000, 'capital_cierre' => 100000,
        ]);

        $respuesta->assertForbidden();
    }
}
