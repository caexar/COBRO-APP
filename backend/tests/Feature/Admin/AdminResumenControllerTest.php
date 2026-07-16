<?php

namespace Tests\Feature\Admin;

use App\Models\Cliente;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminResumenControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_el_resumen_reparte_la_ganancia_entre_interes_y_extras_incluyendo_un_cobro_extra(): void
    {
        $cobrador = User::factory()->create();
        $cliente = Cliente::create([
            'usuario_id' => $cobrador->id,
            'nombre' => 'Juan Perez',
            'cedula' => '123456',
            'telefono' => '3001234567',
            'direccion' => 'Calle 1',
        ]);

        Sanctum::actingAs($cobrador);

        // Capital 100000, interés 20% (20000), extra 5000 -> total 125000, 10 cuotas
        // diarias de 12500 (mismos valores usados para verificar el equivalente en Dart,
        // ver dashboard_repository_test.dart).
        $prestamo = $this->postJson('/api/prestamos', [
            'cliente_id' => $cliente->id,
            'monto_capital' => 100000,
            'porcentaje_interes' => 20,
            'extras' => [['concepto' => 'papeleria', 'valor' => 5000]],
            'frecuencia_pago' => 'diario',
            'plazo_cuotas' => 10,
            'fecha_inicio' => now()->toDateString(),
        ])->assertCreated()->json('data');

        // Cuota 1: pago exacto (12500).
        $this->postJson('/api/pagos', [
            'prestamo_id' => $prestamo['id'],
            'monto_abonado' => 12500,
            'fecha_pago' => now()->toDateString(),
        ])->assertCreated();

        // Cuota 2: abona 20000 contra un pendiente de 12500 -> excedente 7500 como
        // cobro_extra (no reduce deuda, pero sí cuenta como ganancia de "extras").
        $this->postJson('/api/pagos', [
            'prestamo_id' => $prestamo['id'],
            'monto_abonado' => 20000,
            'fecha_pago' => now()->addDay()->toDateString(),
            'manejo_excedente' => 'cobro_extra',
        ])->assertCreated();

        $admin = User::factory()->admin()->create();
        Sanctum::actingAs($admin);

        $respuesta = $this->getJson('/api/admin/resumen');
        $respuesta->assertOk();

        $porCobrador = collect($respuesta->json('data.por_cobrador'))->firstWhere('usuario_id', $cobrador->id);

        // interesProp = 20000/125000 = 0.16; extrasProp = 5000/125000 = 0.04
        // totalAplicado = 25000 -> interés 4000, extras propias 1000 + excedente 7500 = 8500.
        $this->assertEqualsWithDelta(4000, $porCobrador['ganancia_interes'], 0.01);
        $this->assertEqualsWithDelta(8500, $porCobrador['ganancia_extra'], 0.01);

        $this->assertEqualsWithDelta(4000, $respuesta->json('data.global.ganancia_interes'), 0.01);
        $this->assertEqualsWithDelta(8500, $respuesta->json('data.global.ganancia_extra'), 0.01);
    }

    public function test_un_prestamo_sin_pagos_no_aporta_ganancia(): void
    {
        $cobrador = User::factory()->create();
        $cliente = Cliente::create([
            'usuario_id' => $cobrador->id,
            'nombre' => 'Maria Gomez',
            'cedula' => '654321',
            'telefono' => '3009999999',
            'direccion' => 'Calle 2',
        ]);

        Sanctum::actingAs($cobrador);
        $this->postJson('/api/prestamos', [
            'cliente_id' => $cliente->id,
            'monto_capital' => 50000,
            'porcentaje_interes' => 10,
            'frecuencia_pago' => 'diario',
            'plazo_cuotas' => 5,
            'fecha_inicio' => now()->toDateString(),
        ])->assertCreated();

        $admin = User::factory()->admin()->create();
        Sanctum::actingAs($admin);

        $respuesta = $this->getJson('/api/admin/resumen');
        $porCobrador = collect($respuesta->json('data.por_cobrador'))->firstWhere('usuario_id', $cobrador->id);

        $this->assertEqualsWithDelta(0, $porCobrador['ganancia_interes'], 0.01);
        $this->assertEqualsWithDelta(0, $porCobrador['ganancia_extra'], 0.01);
    }

    public function test_el_resumen_incluye_el_saldo_disponible_por_cobrador_y_a_nivel_global(): void
    {
        $cobrador = User::factory()->create();
        $cliente = Cliente::create([
            'usuario_id' => $cobrador->id,
            'nombre' => 'Carlos Ruiz',
            'cedula' => '999999',
            'telefono' => '3005555555',
            'direccion' => 'Calle 3',
        ]);

        Sanctum::actingAs($cobrador);

        $this->postJson('/api/cargas-capital', ['monto' => 200000])->assertCreated();

        $this->postJson('/api/prestamos', [
            'cliente_id' => $cliente->id,
            'monto_capital' => 50000,
            'porcentaje_interes' => 10,
            'frecuencia_pago' => 'diario',
            'plazo_cuotas' => 5,
            'fecha_inicio' => now()->toDateString(),
        ])->assertCreated();

        $admin = User::factory()->admin()->create();
        Sanctum::actingAs($admin);

        $respuesta = $this->getJson('/api/admin/resumen');
        $respuesta->assertOk();
        $porCobrador = collect($respuesta->json('data.por_cobrador'))->firstWhere('usuario_id', $cobrador->id);

        // saldo = 200000 (carga) - 0 (retiros) + 0 (abonado) - 50000 (capital prestado) = 150000
        $this->assertEqualsWithDelta(150000, $porCobrador['saldo_disponible'], 0.01);
        $this->assertEqualsWithDelta(150000, $respuesta->json('data.global.saldo_disponible'), 0.01);
    }
}
