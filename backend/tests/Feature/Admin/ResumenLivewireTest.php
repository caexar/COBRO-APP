<?php

namespace Tests\Feature\Admin;

use App\Livewire\Admin\Resumen\DetalleCobrador;
use App\Livewire\Admin\Resumen\Index;
use App\Models\CargaCapital;
use App\Models\Cliente;
use App\Models\Prestamo;
use App\Models\User;
use App\Support\Dinero;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

/**
 * Resumen del panel web (Livewire), llamando directamente a `ResumenAdminService`/
 * `CapitalService` — misma lógica de negocio que ya cubren los tests de
 * `Api\Admin\AdminResumenController`/`Api\Admin\AdminCargaCapitalController`, así que acá solo
 * se prueba lo específico del panel: los mismos 6 campos se ven en la vista, el badge de
 * clientes cuenta "pagados" (no "activos"), y el formulario de asignar saldo rechaza un retiro
 * que exceda el saldo disponible.
 */
class ResumenLivewireTest extends TestCase
{
    use RefreshDatabase;

    private function crearPrestamo(User $cobrador, Cliente $cliente, string $estado): Prestamo
    {
        return Prestamo::create([
            'cliente_id' => $cliente->id,
            'usuario_id' => $cobrador->id,
            'monto_capital' => 100000,
            'porcentaje_interes' => 20,
            'frecuencia_pago' => 'diario',
            'plazo_cuotas' => 10,
            'fecha_inicio' => '2026-01-01',
            'estado' => $estado,
            'politica_mora' => 'mantener',
        ]);
    }

    public function test_el_resumen_global_y_por_cobrador_muestra_los_mismos_seis_campos(): void
    {
        $admin = User::factory()->admin()->create();
        $cobrador = User::factory()->create(['nombre' => 'Ana Torres']);
        $cliente = Cliente::create([
            'usuario_id' => $cobrador->id,
            'nombre' => 'Juan Perez',
            'cedula' => '123456',
            'telefono' => '3001234567',
            'direccion' => 'Calle 1',
        ]);
        $this->crearPrestamo($cobrador, $cliente, 'activo');
        CargaCapital::create(['usuario_id' => $cobrador->id, 'tipo' => 'carga', 'monto' => 200000]);

        Livewire::actingAs($admin)
            ->test(Index::class)
            ->assertSee('Ana Torres')
            ->assertSee(Dinero::formatear(100000)) // capital_prestado
            ->assertSee(Dinero::formatear(100000)); // saldo_disponible (200000 carga - 100000 capital)
    }

    public function test_el_badge_de_clientes_cuenta_pagados_no_activos(): void
    {
        $admin = User::factory()->admin()->create();
        $cobrador = User::factory()->create();
        $cliente = Cliente::create([
            'usuario_id' => $cobrador->id,
            'nombre' => 'Juan Perez',
            'cedula' => '123456',
            'telefono' => '3001234567',
            'direccion' => 'Calle 1',
        ]);

        // 3 préstamos: 2 pagados, 1 activo -> badge "2/3" (no "1/3", que sería el conteo de
        // activos/en_mora que se mostraba antes del fix del lado móvil).
        $this->crearPrestamo($cobrador, $cliente, 'pagado');
        $this->crearPrestamo($cobrador, $cliente, 'pagado');
        $this->crearPrestamo($cobrador, $cliente, 'activo');

        Livewire::actingAs($admin)
            ->test(DetalleCobrador::class, ['usuario' => $cobrador])
            ->assertSee('2/3')
            ->assertDontSee('1/3');
    }

    public function test_un_retiro_que_excede_el_saldo_disponible_es_rechazado_desde_el_formulario(): void
    {
        $admin = User::factory()->admin()->create();
        $cobrador = User::factory()->create();
        CargaCapital::create(['usuario_id' => $cobrador->id, 'tipo' => 'carga', 'monto' => 50000]);

        Livewire::actingAs($admin)
            ->test(DetalleCobrador::class, ['usuario' => $cobrador])
            ->set('tipoMovimiento', 'retiro')
            ->set('monto', '100000')
            ->call('asignarSaldo')
            ->assertSet('errorCapital', 'El monto del retiro excede el saldo disponible del cobrador ($50,000.00).')
            ->assertSet('mensajeCapital', null);

        $this->assertDatabaseCount('cargas_capital', 1);
    }

    public function test_asignar_un_retiro_dentro_del_saldo_disponible_se_guarda(): void
    {
        $admin = User::factory()->admin()->create();
        $cobrador = User::factory()->create();
        CargaCapital::create(['usuario_id' => $cobrador->id, 'tipo' => 'carga', 'monto' => 50000]);

        Livewire::actingAs($admin)
            ->test(DetalleCobrador::class, ['usuario' => $cobrador])
            ->set('tipoMovimiento', 'retiro')
            ->set('monto', '20000')
            ->call('asignarSaldo')
            ->assertSet('mensajeCapital', 'Saldo asignado correctamente.')
            ->assertSet('errorCapital', null);

        $this->assertDatabaseHas('cargas_capital', [
            'usuario_id' => $cobrador->id,
            'tipo' => 'retiro',
            'monto' => 20000,
            'origen' => 'admin',
            'creado_por_usuario_id' => $admin->id,
        ]);
    }
}
