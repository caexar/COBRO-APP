<?php

namespace Tests\Feature;

use App\Models\CargaCapital;
use App\Models\CierreCaja;
use App\Models\Cliente;
use App\Models\Prestamo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PrestamoMontoTotalTest extends TestCase
{
    use RefreshDatabase;

    private function crearPrestamoConExtra(): Prestamo
    {
        $cobrador = User::factory()->create();
        $cliente = Cliente::create([
            'usuario_id' => $cobrador->id,
            'nombre' => 'Juan Perez',
            'cedula' => '123456',
            'telefono' => '3001234567',
            'direccion' => 'Calle 1',
        ]);

        $prestamo = Prestamo::create([
            'cliente_id' => $cliente->id,
            'usuario_id' => $cobrador->id,
            'monto_capital' => 100000,
            'porcentaje_interes' => 20,
            'frecuencia_pago' => 'diario',
            'plazo_cuotas' => 10,
            'fecha_inicio' => now(),
        ]);
        $prestamo->extras()->create(['concepto' => 'papeleria', 'valor' => 5000]);

        return $prestamo->fresh();
    }

    public function test_monto_total_es_capital_mas_interes_mas_extras(): void
    {
        $prestamo = $this->crearPrestamoConExtra();

        // 100000 + (100000 * 20%) + 5000 = 125000, misma cuenta que PrestamoCalculator.
        $this->assertEqualsWithDelta(125000, $prestamo->monto_total, 0.01);
    }

    public function test_monto_total_aparece_al_serializar_el_modelo(): void
    {
        $prestamo = $this->crearPrestamoConExtra();

        $arreglo = $prestamo->toArray();

        $this->assertArrayHasKey('monto_total', $arreglo);
        $this->assertEqualsWithDelta(125000, $arreglo['monto_total'], 0.01);
    }

    public function test_monto_total_y_cliente_id_aparecen_en_get_admin_usuarios_detalle(): void
    {
        $prestamo = $this->crearPrestamoConExtra();
        $admin = User::factory()->admin()->create();

        Sanctum::actingAs($admin);

        $respuesta = $this->getJson("/api/admin/usuarios/{$prestamo->usuario_id}/detalle");

        $respuesta->assertOk();
        $respuesta->assertJsonPath('data.prestamos.0.monto_total', 125000);
        $respuesta->assertJsonPath('data.prestamos.0.cliente_id', $prestamo->cliente_id);
    }

    public function test_cargas_capital_del_cobrador_aparecen_en_get_admin_usuarios_detalle(): void
    {
        $prestamo = $this->crearPrestamoConExtra();
        $admin = User::factory()->admin()->create();

        CargaCapital::create(['usuario_id' => $prestamo->usuario_id, 'tipo' => 'carga', 'monto' => 50000]);
        CargaCapital::create([
            'usuario_id' => $prestamo->usuario_id,
            'tipo' => 'retiro',
            'monto' => 10000,
            'origen' => 'admin',
            'creado_por_usuario_id' => $admin->id,
        ]);

        Sanctum::actingAs($admin);

        $respuesta = $this->getJson("/api/admin/usuarios/{$prestamo->usuario_id}/detalle");

        $respuesta->assertOk();
        $respuesta->assertJsonCount(2, 'data.cargas_capital');
        $respuesta->assertJsonFragment(['tipo' => 'carga', 'origen' => 'cobrador']);
        $respuesta->assertJsonFragment(['tipo' => 'retiro', 'origen' => 'admin']);
    }

    public function test_cierres_de_caja_del_cobrador_con_sus_gastos_aparecen_en_get_admin_usuarios_detalle(): void
    {
        $prestamo = $this->crearPrestamoConExtra();
        $admin = User::factory()->admin()->create();

        $cierre = CierreCaja::create([
            'usuario_id' => $prestamo->usuario_id,
            'fecha' => '2026-01-01',
            'capital_inicio' => 100000,
            'capital_cierre' => 120000,
            'gastos_total' => 10000,
        ]);
        $cierre->gastos()->create(['monto' => 10000, 'detalle' => 'almuerzo']);

        Sanctum::actingAs($admin);

        $respuesta = $this->getJson("/api/admin/usuarios/{$prestamo->usuario_id}/detalle");

        $respuesta->assertOk();
        $respuesta->assertJsonCount(1, 'data.cierres_caja');
        $respuesta->assertJsonPath('data.cierres_caja.0.capital_inicio', '100000.00');
        $respuesta->assertJsonCount(1, 'data.cierres_caja.0.gastos');
        $respuesta->assertJsonPath('data.cierres_caja.0.gastos.0.detalle', 'almuerzo');
    }
}
