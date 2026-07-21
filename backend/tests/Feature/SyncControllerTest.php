<?php

namespace Tests\Feature;

use App\Models\CargaCapital;
use App\Models\Cliente;
use App\Models\Cuota;
use App\Models\Pago;
use App\Models\Prestamo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SyncControllerTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Batch clientes -> prestamos -> pagos (más una carga de capital independiente), con
     * montos redondos: capital 100000 al 20% = 120000 total, repartido en 2 cuotas diarias de
     * 60000 empezando el 2026-07-10 (cuota 1 vence 2026-07-11, cuota 2 vence 2026-07-12).
     *
     * @return array<string, mixed>
     */
    private function batchCompleto(): array
    {
        return [
            'clientes' => [[
                'uuid_local' => 'c-1',
                'actualizado_en' => now()->toIso8601String(),
                'nombre' => 'Juan Perez',
                'cedula' => '123456',
                'telefono' => '3001234567',
                'direccion' => 'Calle 1 # 2-3',
            ]],
            'prestamos' => [[
                'uuid_local' => 'p-1',
                'actualizado_en' => now()->toIso8601String(),
                'cliente_uuid_local' => 'c-1',
                'monto_capital' => 100000,
                'porcentaje_interes' => 20,
                'frecuencia_pago' => 'diario',
                'plazo_cuotas' => 2,
                'fecha_inicio' => '2026-07-10',
            ]],
            'pagos' => [[
                'uuid_local' => 'pg-1',
                'prestamo_uuid_local' => 'p-1',
                'numero_cuota' => 1,
                'monto_abonado' => 60000,
                'monto_aplicado' => 60000,
                'fecha_pago' => '2026-07-11',
                'dias_mora' => 0,
                'saldo_restante_despues' => 60000,
                'estado_prestamo' => 'activo',
                'cuotas_afectadas' => [
                    ['numero_cuota' => 1, 'estado' => 'pagada'],
                ],
            ]],
            'cargas_capital' => [[
                'uuid_local' => 'cc-1',
                'tipo' => 'carga',
                'monto' => 500000,
                'descripcion' => 'Aporte inicial',
            ]],
        ];
    }

    public function test_sincroniza_un_batch_completo_creando_todo(): void
    {
        $cobrador = User::factory()->create();
        Sanctum::actingAs($cobrador);

        $respuesta = $this->postJson('/api/sync', $this->batchCompleto());

        $respuesta->assertOk();
        $respuesta->assertJsonPath('data.clientes.0.estado', 'creado');
        $respuesta->assertJsonPath('data.prestamos.0.estado', 'creado');
        $respuesta->assertJsonPath('data.pagos.0.estado', 'creado');
        $respuesta->assertJsonPath('data.cargas_capital.0.estado', 'creado');
        $respuesta->assertJsonPath('configuracion.pin_maestro_configurado', false);
        $respuesta->assertJsonStructure(['configuracion' => ['tasas_interes_default', 'politica_mora_default', 'intentos_pin_antes_de_maestro']]);

        $cliente = Cliente::where('uuid_local', 'c-1')->sole();
        $this->assertSame($cobrador->id, $cliente->usuario_id);

        $prestamo = Prestamo::where('uuid_local', 'p-1')->sole();
        $this->assertSame($cliente->id, $prestamo->cliente_id);
        $this->assertEqualsWithDelta(120000, $prestamo->monto_total, 0.01);

        $cuota1 = Cuota::where('prestamo_id', $prestamo->id)->where('numero_cuota', 1)->sole();
        $this->assertSame('pagada', $cuota1->estado);
        $cuota2 = Cuota::where('prestamo_id', $prestamo->id)->where('numero_cuota', 2)->sole();
        $this->assertSame('pendiente', $cuota2->estado);

        $pago = Pago::where('uuid_local', 'pg-1')->sole();
        $this->assertSame($cuota1->id, $pago->cuota_id);
        $this->assertEqualsWithDelta(60000, (float) $pago->monto_aplicado, 0.01);

        $this->assertDatabaseHas('cargas_capital', [
            'uuid_local' => 'cc-1', 'usuario_id' => $cobrador->id, 'tipo' => 'carga', 'origen' => 'cobrador',
        ]);
    }

    public function test_reenviar_el_mismo_batch_no_duplica_nada(): void
    {
        $cobrador = User::factory()->create();
        Sanctum::actingAs($cobrador);

        $this->postJson('/api/sync', $this->batchCompleto())->assertOk();
        $respuesta = $this->postJson('/api/sync', $this->batchCompleto());

        $respuesta->assertOk();
        $respuesta->assertJsonPath('data.clientes.0.estado', 'ya_existia');
        $respuesta->assertJsonPath('data.prestamos.0.estado', 'ya_existia');
        $respuesta->assertJsonPath('data.pagos.0.estado', 'ya_existia');
        $respuesta->assertJsonPath('data.cargas_capital.0.estado', 'ya_existia');

        $this->assertDatabaseCount('clientes', 1);
        $this->assertDatabaseCount('prestamos', 1);
        $this->assertDatabaseCount('pagos', 1);
        $this->assertDatabaseCount('cargas_capital', 1);
    }

    public function test_conflicto_si_el_cambio_entrante_es_mas_viejo_que_el_ya_guardado(): void
    {
        $cobrador = User::factory()->create();
        Sanctum::actingAs($cobrador);

        $this->postJson('/api/sync', $this->batchCompleto())->assertOk();
        $original = Cliente::where('uuid_local', 'c-1')->sole();

        $batch = $this->batchCompleto();
        $batch['prestamos'] = [];
        $batch['pagos'] = [];
        $batch['cargas_capital'] = [];
        $batch['clientes'][0]['telefono'] = '3009999999';
        $batch['clientes'][0]['actualizado_en'] = now()->subDay()->toIso8601String();

        $respuesta = $this->postJson('/api/sync', $batch);

        $respuesta->assertOk();
        $respuesta->assertJsonPath('data.clientes.0.estado', 'conflicto');

        $original->refresh();
        $this->assertSame('3001234567', $original->telefono);

        $this->assertDatabaseHas('auditoria', [
            'accion' => 'conflicto_resuelto',
            'entidad' => 'Cliente',
            'entidad_id' => $original->id,
        ]);
    }

    public function test_actualiza_si_el_cambio_entrante_es_mas_reciente_que_el_ya_guardado(): void
    {
        $cobrador = User::factory()->create();
        Sanctum::actingAs($cobrador);

        $this->postJson('/api/sync', $this->batchCompleto())->assertOk();

        $batch = $this->batchCompleto();
        $batch['prestamos'] = [];
        $batch['pagos'] = [];
        $batch['cargas_capital'] = [];
        $batch['clientes'][0]['telefono'] = '3009999999';
        $batch['clientes'][0]['actualizado_en'] = now()->addDay()->toIso8601String();

        $respuesta = $this->postJson('/api/sync', $batch);

        $respuesta->assertOk();
        $respuesta->assertJsonPath('data.clientes.0.estado', 'actualizado');
        $this->assertDatabaseHas('clientes', ['uuid_local' => 'c-1', 'telefono' => '3009999999']);
    }

    public function test_un_prestamo_con_cliente_uuid_local_inexistente_devuelve_error_sin_romper_el_batch(): void
    {
        $cobrador = User::factory()->create();
        Sanctum::actingAs($cobrador);

        $batch = $this->batchCompleto();
        $batch['prestamos'][0]['cliente_uuid_local'] = 'no-existe';
        $batch['pagos'] = [];

        $respuesta = $this->postJson('/api/sync', $batch);

        $respuesta->assertOk();
        $respuesta->assertJsonPath('data.clientes.0.estado', 'creado');
        $respuesta->assertJsonPath('data.prestamos.0.estado', 'error');
        $this->assertDatabaseCount('prestamos', 0);
    }

    public function test_sincroniza_un_cierre_de_caja_con_sus_gastos_derivando_el_total(): void
    {
        $cobrador = User::factory()->create();
        Sanctum::actingAs($cobrador);

        $respuesta = $this->postJson('/api/sync', [
            'cierres_caja' => [[
                'uuid_local' => 'cz-1',
                'fecha' => '2026-07-21',
                'capital_inicio' => 100000,
                'capital_cierre' => 150000,
                'justificacion_diferencia' => null,
                'gastos' => [
                    ['monto' => 10000, 'detalle' => 'almuerzo'],
                    ['monto' => 25000, 'detalle' => 'gasolina'],
                ],
            ]],
        ]);

        $respuesta->assertOk();
        $respuesta->assertJsonPath('data.cierres_caja.0.estado', 'creado');

        $this->assertDatabaseHas('cierres_caja', [
            'uuid_local' => 'cz-1', 'usuario_id' => $cobrador->id, 'gastos_total' => 35000,
        ]);
        $this->assertDatabaseCount('cierre_caja_gastos', 2);

        // Reenviar el mismo batch no duplica.
        $respuestaReenviada = $this->postJson('/api/sync', [
            'cierres_caja' => [[
                'uuid_local' => 'cz-1',
                'fecha' => '2026-07-21',
                'capital_inicio' => 100000,
                'capital_cierre' => 150000,
            ]],
        ]);

        $respuestaReenviada->assertOk();
        $respuestaReenviada->assertJsonPath('data.cierres_caja.0.estado', 'ya_existia');
        $this->assertDatabaseCount('cierres_caja', 1);
        $this->assertDatabaseCount('cierre_caja_gastos', 2);
    }

    public function test_un_admin_no_puede_usar_este_endpoint(): void
    {
        $admin = User::factory()->admin()->create();
        Sanctum::actingAs($admin);

        $respuesta = $this->postJson('/api/sync', $this->batchCompleto());

        $respuesta->assertForbidden();
    }

    public function test_devuelve_y_marca_como_descargadas_las_cargas_de_capital_asignadas_por_un_admin(): void
    {
        $admin = User::factory()->admin()->create();
        $cobrador = User::factory()->create();

        $pendiente = CargaCapital::create([
            'usuario_id' => $cobrador->id, 'tipo' => 'carga', 'monto' => 300000,
            'descripcion' => 'Fondeo', 'origen' => 'admin', 'creado_por_usuario_id' => $admin->id,
        ]);
        // No debe viajar: ya se había descargado en un /sync anterior.
        CargaCapital::create([
            'usuario_id' => $cobrador->id, 'tipo' => 'carga', 'monto' => 999999,
            'origen' => 'admin', 'creado_por_usuario_id' => $admin->id, 'descargado' => true,
        ]);
        // No debe viajar: es del propio cobrador, no de un admin.
        CargaCapital::create(['usuario_id' => $cobrador->id, 'tipo' => 'carga', 'monto' => 1000, 'origen' => 'cobrador']);

        Sanctum::actingAs($cobrador);

        $respuesta = $this->postJson('/api/sync', []);

        $respuesta->assertOk();
        $respuesta->assertJsonCount(1, 'cargas_capital_admin');
        $respuesta->assertJsonPath('cargas_capital_admin.0.id', $pendiente->id);
        $respuesta->assertJsonPath('cargas_capital_admin.0.monto', 300000);

        $this->assertTrue($pendiente->fresh()->descargado);
    }

    public function test_no_devuelve_cargas_de_capital_de_otro_cobrador(): void
    {
        $admin = User::factory()->admin()->create();
        $cobrador = User::factory()->create();
        $otroCobrador = User::factory()->create();

        CargaCapital::create([
            'usuario_id' => $otroCobrador->id, 'tipo' => 'carga', 'monto' => 500000,
            'origen' => 'admin', 'creado_por_usuario_id' => $admin->id,
        ]);

        Sanctum::actingAs($cobrador);

        $respuesta = $this->postJson('/api/sync', []);

        $respuesta->assertOk();
        $respuesta->assertJsonCount(0, 'cargas_capital_admin');
    }
}
