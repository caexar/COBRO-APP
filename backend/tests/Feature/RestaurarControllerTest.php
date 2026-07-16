<?php

namespace Tests\Feature;

use App\Models\CargaCapital;
use App\Models\Cliente;
use App\Models\Pago;
use App\Models\Prestamo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RestaurarControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_devuelve_clientes_prestamos_con_extras_y_cuotas_pagos_y_cargas_capital_del_cobrador(): void
    {
        $cobrador = User::factory()->create();

        $cliente = Cliente::create([
            'usuario_id' => $cobrador->id,
            'nombre' => 'Juan Perez',
            'cedula' => '123456',
            'telefono' => '3001234567',
            'direccion' => 'Calle 1',
            'uuid_local' => 'c-1',
        ]);

        $prestamo = Prestamo::create([
            'cliente_id' => $cliente->id,
            'usuario_id' => $cobrador->id,
            'monto_capital' => 100000,
            'porcentaje_interes' => 20,
            'frecuencia_pago' => 'diario',
            'plazo_cuotas' => 2,
            'fecha_inicio' => '2026-07-10',
            'estado' => 'activo',
            'politica_mora' => 'mantener',
            'uuid_local' => 'p-1',
        ]);
        $prestamo->extras()->create(['concepto' => 'papeleria', 'valor' => 5000]);
        $prestamo->cuotas()->create(['numero_cuota' => 1, 'fecha_esperada' => '2026-07-11', 'monto_esperado' => 62500]);
        $prestamo->cuotas()->create(['numero_cuota' => 2, 'fecha_esperada' => '2026-07-12', 'monto_esperado' => 62500]);

        Pago::create([
            'prestamo_id' => $prestamo->id,
            'cuota_id' => $prestamo->cuotas()->where('numero_cuota', 1)->first()->id,
            'monto_abonado' => 62500,
            'monto_aplicado' => 62500,
            'fecha_pago' => '2026-07-11',
            'dias_mora' => 0,
            'saldo_restante_despues' => 62500,
            'uuid_local' => 'pg-1',
        ]);

        CargaCapital::create(['usuario_id' => $cobrador->id, 'tipo' => 'carga', 'monto' => 200000, 'uuid_local' => 'cc-1']);
        $cargaAdmin = CargaCapital::create([
            'usuario_id' => $cobrador->id,
            'tipo' => 'carga',
            'monto' => 50000,
            'origen' => 'admin',
            'descargado' => false,
        ]);

        Sanctum::actingAs($cobrador);

        $respuesta = $this->getJson('/api/restaurar');

        $respuesta->assertOk();
        $respuesta->assertJsonCount(1, 'data.clientes');
        $respuesta->assertJsonPath('data.clientes.0.nombre', 'Juan Perez');

        $respuesta->assertJsonCount(1, 'data.prestamos');
        $respuesta->assertJsonPath('data.prestamos.0.uuid_local', 'p-1');
        $respuesta->assertJsonCount(1, 'data.prestamos.0.extras');
        $respuesta->assertJsonCount(2, 'data.prestamos.0.cuotas');

        $respuesta->assertJsonCount(1, 'data.pagos');
        $respuesta->assertJsonPath('data.pagos.0.uuid_local', 'pg-1');

        $respuesta->assertJsonCount(2, 'data.cargas_capital');

        // La carga de origen admin queda marcada como descargada en la misma operación.
        $this->assertTrue($cargaAdmin->fresh()->descargado);
    }

    public function test_un_cobrador_no_puede_ver_datos_de_otro(): void
    {
        $cobradorA = User::factory()->create();
        $cobradorB = User::factory()->create();

        Cliente::create([
            'usuario_id' => $cobradorB->id,
            'nombre' => 'Cliente de otro cobrador',
            'cedula' => '999999',
            'telefono' => '3009999999',
            'direccion' => 'Calle 9',
        ]);
        CargaCapital::create(['usuario_id' => $cobradorB->id, 'tipo' => 'carga', 'monto' => 100000]);

        Sanctum::actingAs($cobradorA);

        $respuesta = $this->getJson('/api/restaurar');

        $respuesta->assertOk();
        $respuesta->assertJsonCount(0, 'data.clientes');
        $respuesta->assertJsonCount(0, 'data.prestamos');
        $respuesta->assertJsonCount(0, 'data.pagos');
        $respuesta->assertJsonCount(0, 'data.cargas_capital');
    }

    public function test_un_admin_no_puede_usar_este_endpoint(): void
    {
        $admin = User::factory()->admin()->create();
        Sanctum::actingAs($admin);

        $respuesta = $this->getJson('/api/restaurar');

        $respuesta->assertForbidden();
    }
}
