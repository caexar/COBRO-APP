<?php

namespace Tests\Feature;

use App\Models\Cliente;
use App\Models\Prestamo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PrestamoControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_acepta_frecuencia_pago_quincenal_al_crear_un_prestamo(): void
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

        $respuesta = $this->postJson('/api/prestamos', [
            'cliente_id' => $cliente->id,
            'monto_capital' => 100000,
            'porcentaje_interes' => 20,
            'frecuencia_pago' => 'quincenal',
            'plazo_cuotas' => 2,
            'fecha_inicio' => '2026-07-10',
        ]);

        $respuesta->assertCreated();
        $this->assertSame('quincenal', Prestamo::sole()->frecuencia_pago);
    }
}
