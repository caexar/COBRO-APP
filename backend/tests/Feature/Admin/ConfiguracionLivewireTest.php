<?php

namespace Tests\Feature\Admin;

use App\Livewire\Admin\Configuracion\Formulario;
use App\Models\ConfiguracionGlobal;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Livewire\Livewire;
use Tests\TestCase;

/**
 * Configuración global desde el panel web (Livewire): reutiliza `ConfiguracionAdminService`,
 * misma lógica que ya usa `Api\Admin\AdminConfiguracionController` — acá solo se prueba que el
 * hash del PIN maestro nunca se exponga (ni en el HTML renderizado ni en una propiedad pública
 * del componente) y que el checkbox "Quitar el PIN maestro actual" lo borre de verdad.
 */
class ConfiguracionLivewireTest extends TestCase
{
    use RefreshDatabase;

    public function test_el_componente_nunca_expone_el_hash_del_pin_maestro(): void
    {
        $admin = User::factory()->admin()->create();
        $hash = Hash::make('123456');
        ConfiguracionGlobal::guardar('pin_maestro_hash', $hash);

        $componente = Livewire::actingAs($admin)->test(Formulario::class);

        $componente->assertSet('pinMaestroConfigurado', true);
        $componente->assertDontSee($hash);

        // Solo el booleano "configurado" viene del hash guardado; el campo de texto es para
        // escribir uno nuevo, nunca se precarga con el valor existente.
        $componente->assertSet('nuevoPinMaestro', '');
    }

    public function test_guardar_un_nuevo_pin_maestro_actualiza_el_hash_y_deja_auditoria_sin_el_valor(): void
    {
        $admin = User::factory()->admin()->create();

        Livewire::actingAs($admin)
            ->test(Formulario::class)
            ->set('politicaMoraDefault', 'mantener')
            ->set('intentosPinAntesDeMaestro', 5)
            ->set('nuevoPinMaestro', '654321')
            ->call('guardar')
            ->assertSet('pinMaestroConfigurado', true)
            ->assertSet('mensaje', 'Configuración actualizada correctamente.');

        $hashGuardado = ConfiguracionGlobal::obtener('pin_maestro_hash');
        $this->assertTrue(Hash::check('654321', $hashGuardado));

        $registro = \App\Models\Auditoria::where('accion', 'actualizar_configuracion')->latest('id')->first();
        $this->assertNotNull($registro);
        $this->assertStringNotContainsString('654321', json_encode($registro->datos_nuevos));
        $this->assertTrue($registro->datos_nuevos['pin_maestro_actualizado']);
    }

    public function test_quitar_el_pin_maestro_lo_borra(): void
    {
        $admin = User::factory()->admin()->create();
        ConfiguracionGlobal::guardar('pin_maestro_hash', Hash::make('123456'));

        Livewire::actingAs($admin)
            ->test(Formulario::class)
            ->set('politicaMoraDefault', 'mantener')
            ->set('intentosPinAntesDeMaestro', 3)
            ->set('quitarPinMaestro', true)
            ->call('guardar')
            ->assertSet('pinMaestroConfigurado', false);

        $this->assertDatabaseMissing('configuracion_global', ['clave' => 'pin_maestro_hash']);
    }
}
