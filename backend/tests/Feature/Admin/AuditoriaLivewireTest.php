<?php

namespace Tests\Feature\Admin;

use App\Livewire\Admin\Auditoria\Index;
use App\Models\Auditoria;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

/**
 * Visor de auditoría (Livewire): puramente de consulta. Se prueba que liste correctamente, que
 * el filtro por `accion` funcione, y que no exista ninguna forma de editar/eliminar un registro
 * desde acá (no hay métodos de mutación en el componente).
 */
class AuditoriaLivewireTest extends TestCase
{
    use RefreshDatabase;

    public function test_lista_los_registros_de_auditoria_y_filtra_por_accion(): void
    {
        $admin = User::factory()->admin()->create();
        $cobrador = User::factory()->create(['nombre' => 'Ana Torres']);

        Auditoria::create([
            'usuario_id' => $cobrador->id,
            'accion' => 'crear_prestamo',
            'entidad' => 'Prestamo',
            'entidad_id' => 10,
            'datos_anteriores' => null,
            'datos_nuevos' => ['monto_capital' => 100000],
        ]);
        Auditoria::create([
            'usuario_id' => $admin->id,
            'accion' => 'actualizar_configuracion',
            'entidad' => 'ConfiguracionGlobal',
            'entidad_id' => 0,
            'datos_anteriores' => [],
            'datos_nuevos' => ['pin_maestro_actualizado' => true],
        ]);

        $componente = Livewire::actingAs($admin)->test(Index::class);

        $componente->assertSee('crear_prestamo')
            ->assertSee('actualizar_configuracion')
            ->assertSee('Ana Torres');

        // El filtro por acción también aparece listado en el <select>, así que se verifica el
        // efecto del filtro por una columna que solo pertenece a la fila excluida (la acción
        // "actualizar_configuracion" en sí misma seguiría viéndose como opción del <select>).
        $componente->set('accion', 'crear_prestamo')
            ->assertSee('crear_prestamo')
            ->assertSee('Prestamo #10')
            ->assertDontSee('ConfiguracionGlobal');
    }

    public function test_el_visor_es_de_solo_lectura_sin_botones_de_editar_o_eliminar(): void
    {
        $admin = User::factory()->admin()->create();
        Auditoria::create([
            'usuario_id' => $admin->id,
            'accion' => 'crear_usuario',
            'entidad' => 'User',
            'entidad_id' => 1,
            'datos_anteriores' => null,
            'datos_nuevos' => ['nombre' => 'Juan'],
        ]);

        Livewire::actingAs($admin)
            ->test(Index::class)
            ->assertDontSee('Eliminar')
            ->assertDontSee('Editar');

        $this->assertFalse(method_exists(Index::class, 'eliminar'));
        $this->assertFalse(method_exists(Index::class, 'actualizar'));
    }

    public function test_los_datos_relacionados_a_pin_se_ocultan_en_el_detalle(): void
    {
        $admin = User::factory()->admin()->create();
        Auditoria::create([
            'usuario_id' => $admin->id,
            'accion' => 'actualizar_usuario',
            'entidad' => 'User',
            'entidad_id' => 1,
            'datos_anteriores' => ['pin_hash' => 'no-deberia-estar-aqui'],
            'datos_nuevos' => ['nombre' => 'Juan'],
        ]);

        Livewire::actingAs($admin)
            ->test(Index::class)
            ->assertDontSee('no-deberia-estar-aqui')
            ->assertSee('(oculto)')
            ->assertSee('Juan');
    }
}
