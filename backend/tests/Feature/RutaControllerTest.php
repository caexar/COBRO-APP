<?php

namespace Tests\Feature;

use App\Models\Cliente;
use App\Models\Prestamo;
use App\Models\Ruta;
use App\Models\RutaItem;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RutaControllerTest extends TestCase
{
    use RefreshDatabase;

    private function crearCliente(User $cobrador): Cliente
    {
        return Cliente::create([
            'usuario_id' => $cobrador->id,
            'nombre' => 'Juan Perez',
            'cedula' => '123456',
            'telefono' => '3001234567',
            'direccion' => 'Calle 1',
        ]);
    }

    /**
     * Crea un préstamo con cuotas explícitas (sin pasar por PrestamoCalculator, igual que
     * PrestamoMontoTotalTest) para poder controlar a mano cuál es la "próxima cuota pendiente"
     * y su fecha_esperada.
     *
     * @param  array<int, array{fecha: string, estado?: string}>  $cuotas
     */
    private function crearPrestamoConCuotas(User $cobrador, Cliente $cliente, array $cuotas, string $estado = 'activo'): Prestamo
    {
        $prestamo = Prestamo::create([
            'cliente_id' => $cliente->id,
            'usuario_id' => $cobrador->id,
            'monto_capital' => 100000,
            'porcentaje_interes' => 0,
            'frecuencia_pago' => 'diario',
            'plazo_cuotas' => count($cuotas),
            'fecha_inicio' => '2026-01-01',
            'estado' => $estado,
        ]);

        foreach ($cuotas as $numero => $cuota) {
            $prestamo->cuotas()->create([
                'numero_cuota' => $numero + 1,
                'fecha_esperada' => $cuota['fecha'],
                'monto_esperado' => 50000,
                'estado' => $cuota['estado'] ?? 'pendiente',
            ]);
        }

        return $prestamo;
    }

    public function test_crea_edita_lista_y_elimina_una_ruta(): void
    {
        $cobrador = User::factory()->create();
        Sanctum::actingAs($cobrador);

        $respuesta = $this->postJson('/api/rutas', [
            'nombre' => 'Barrio Centro',
            'descripcion' => 'Cobros de los lunes',
        ]);
        $respuesta->assertCreated();
        $respuesta->assertJsonPath('data.nombre', 'Barrio Centro');
        $respuesta->assertJsonPath('data.orden', 0);
        $rutaId = $respuesta->json('data.id');

        $this->putJson("/api/rutas/{$rutaId}", ['nombre' => 'Barrio Centro (editado)'])
            ->assertOk()
            ->assertJsonPath('data.nombre', 'Barrio Centro (editado)');

        $this->getJson('/api/rutas')->assertOk()->assertJsonCount(1, 'data');
        $this->getJson("/api/rutas/{$rutaId}")->assertOk()->assertJsonPath('data.id', $rutaId);

        $this->deleteJson("/api/rutas/{$rutaId}")->assertOk();
        $this->assertDatabaseMissing('rutas', ['id' => $rutaId]);
    }

    public function test_reordena_la_lista_de_rutas_del_cobrador(): void
    {
        $cobrador = User::factory()->create();
        $r1 = Ruta::create(['usuario_id' => $cobrador->id, 'nombre' => 'Ruta A', 'orden' => 0]);
        $r2 = Ruta::create(['usuario_id' => $cobrador->id, 'nombre' => 'Ruta B', 'orden' => 1]);
        $r3 = Ruta::create(['usuario_id' => $cobrador->id, 'nombre' => 'Ruta C', 'orden' => 2]);

        Sanctum::actingAs($cobrador);

        $respuesta = $this->putJson('/api/rutas/reordenar', ['ids' => [$r3->id, $r1->id, $r2->id]]);

        $respuesta->assertOk();
        $this->assertSame(1, $r1->fresh()->orden);
        $this->assertSame(2, $r2->fresh()->orden);
        $this->assertSame(0, $r3->fresh()->orden);
        $respuesta->assertJsonPath('data.0.id', $r3->id);
    }

    public function test_agrega_quita_reordena_y_marca_cobrado_un_item_de_ruta(): void
    {
        $cobrador = User::factory()->create();
        $cliente = $this->crearCliente($cobrador);
        $prestamo1 = $this->crearPrestamoConCuotas($cobrador, $cliente, [['fecha' => '2026-07-22']]);
        $prestamo2 = $this->crearPrestamoConCuotas($cobrador, $cliente, [['fecha' => '2026-07-23']]);
        $ruta = Ruta::create(['usuario_id' => $cobrador->id, 'nombre' => 'Ruta A']);

        Sanctum::actingAs($cobrador);

        $r1 = $this->postJson("/api/rutas/{$ruta->id}/items", ['prestamo_id' => $prestamo1->id]);
        $r1->assertCreated();
        $r1->assertJsonPath('data.orden', 0);
        $itemId1 = $r1->json('data.id');

        $r2 = $this->postJson("/api/rutas/{$ruta->id}/items", ['prestamo_id' => $prestamo2->id]);
        $r2->assertCreated();
        $r2->assertJsonPath('data.orden', 1);
        $itemId2 = $r2->json('data.id');

        $this->putJson("/api/rutas/{$ruta->id}/items/reordenar", ['ids' => [$itemId2, $itemId1]])->assertOk();
        $this->assertSame(1, RutaItem::find($itemId1)->orden);
        $this->assertSame(0, RutaItem::find($itemId2)->orden);

        $marcar = $this->putJson("/api/rutas/{$ruta->id}/items/{$itemId1}/marcar-cobrado");
        $marcar->assertOk();
        $marcar->assertJsonPath('data.estado', 'cobrado');
        $this->assertNotNull(RutaItem::find($itemId1)->cobrado_en);

        $this->deleteJson("/api/rutas/{$ruta->id}/items/{$itemId2}")->assertOk();
        $this->assertDatabaseMissing('ruta_items', ['id' => $itemId2]);
    }

    public function test_un_cobrador_no_puede_ver_ni_modificar_rutas_de_otro(): void
    {
        $dueno = User::factory()->create();
        $otro = User::factory()->create();
        $ruta = Ruta::create(['usuario_id' => $dueno->id, 'nombre' => 'Ruta del dueño']);

        Sanctum::actingAs($otro);

        $this->getJson("/api/rutas/{$ruta->id}")->assertForbidden();
        $this->putJson("/api/rutas/{$ruta->id}", ['nombre' => 'Hackeada'])->assertForbidden();
        $this->deleteJson("/api/rutas/{$ruta->id}")->assertForbidden();
        $this->postJson("/api/rutas/{$ruta->id}/items", ['prestamo_id' => 1])->assertForbidden();

        // La lista general tampoco la incluye.
        $this->getJson('/api/rutas')->assertOk()->assertJsonCount(0, 'data');

        $this->assertDatabaseHas('rutas', ['id' => $ruta->id, 'nombre' => 'Ruta del dueño']);
    }

    public function test_autogenerar_hoy_solo_incluye_prestamos_cuya_proxima_cuota_pendiente_vence_hoy(): void
    {
        $this->travelTo(\Illuminate\Support\Carbon::parse('2026-07-21 09:00:00'));

        $cobrador = User::factory()->create();
        $cliente = $this->crearCliente($cobrador);

        // Vence hoy: sí debe entrar.
        $vencidoHoy = $this->crearPrestamoConCuotas($cobrador, $cliente, [
            ['fecha' => '2026-07-21'],
        ]);

        // Próxima cuota pendiente vence mañana: no debe entrar.
        $vencidoManana = $this->crearPrestamoConCuotas($cobrador, $cliente, [
            ['fecha' => '2026-07-22'],
        ]);

        // En mora: la cuota 1 (más antigua, sin pagar) vence ayer, así que esa es la "próxima
        // cuota pendiente" aunque la cuota 2 venza justo hoy — no debe entrar todavía.
        $enMoraConCuotaFuturaHoy = $this->crearPrestamoConCuotas($cobrador, $cliente, [
            ['fecha' => '2026-07-20'],
            ['fecha' => '2026-07-21'],
        ], estado: 'en_mora');

        // En mora, pero la cuota 1 ya está pagada y la próxima pendiente (cuota 2) vence hoy: sí debe entrar.
        $enMoraQueVenceHoy = $this->crearPrestamoConCuotas($cobrador, $cliente, [
            ['fecha' => '2026-07-19', 'estado' => 'pagada'],
            ['fecha' => '2026-07-21'],
        ], estado: 'en_mora');

        // Ya pagado por completo: no debe entrar aunque alguna cuota "venciera" hoy.
        $pagado = $this->crearPrestamoConCuotas($cobrador, $cliente, [
            ['fecha' => '2026-07-21', 'estado' => 'pagada'],
        ], estado: 'pagado');

        Sanctum::actingAs($cobrador);

        $respuesta = $this->postJson('/api/rutas/autogenerar-hoy');

        $respuesta->assertCreated();
        $respuesta->assertJsonPath('data.nombre', 'Ruta de hoy 2026-07-21');
        $this->assertSame('2026-07-21', \Illuminate\Support\Carbon::parse($respuesta->json('data.fecha'))->toDateString());
        $respuesta->assertJsonCount(2, 'data.items');

        $prestamoIdsIncluidos = collect($respuesta->json('data.items'))->pluck('prestamo_id')->all();
        $this->assertEqualsCanonicalizing([$vencidoHoy->id, $enMoraQueVenceHoy->id], $prestamoIdsIncluidos);
        $this->assertNotContains($vencidoManana->id, $prestamoIdsIncluidos);
        $this->assertNotContains($enMoraConCuotaFuturaHoy->id, $prestamoIdsIncluidos);
        $this->assertNotContains($pagado->id, $prestamoIdsIncluidos);

        $this->travelBack();
    }

    public function test_autogenerar_hoy_acepta_una_fecha_distinta_a_hoy(): void
    {
        $this->travelTo(\Illuminate\Support\Carbon::parse('2026-07-21 09:00:00'));

        $cobrador = User::factory()->create();
        $cliente = $this->crearCliente($cobrador);

        // Vence hoy: no debe entrar, porque pedimos la ruta de mañana.
        $vencidoHoy = $this->crearPrestamoConCuotas($cobrador, $cliente, [
            ['fecha' => '2026-07-21'],
        ]);

        // Vence mañana: sí debe entrar.
        $vencidoManana = $this->crearPrestamoConCuotas($cobrador, $cliente, [
            ['fecha' => '2026-07-22'],
        ]);

        Sanctum::actingAs($cobrador);

        $respuesta = $this->postJson('/api/rutas/autogenerar-hoy', ['fecha' => '2026-07-22']);

        $respuesta->assertCreated();
        $respuesta->assertJsonPath('data.nombre', 'Ruta del 2026-07-22');
        $this->assertSame('2026-07-22', \Illuminate\Support\Carbon::parse($respuesta->json('data.fecha'))->toDateString());

        $prestamoIdsIncluidos = collect($respuesta->json('data.items'))->pluck('prestamo_id')->all();
        $this->assertSame([$vencidoManana->id], $prestamoIdsIncluidos);
        $this->assertNotContains($vencidoHoy->id, $prestamoIdsIncluidos);

        $this->travelBack();
    }

    public function test_incluir_vencidas_agrega_deudas_de_dias_anteriores_sin_duplicar_por_prestamo(): void
    {
        $this->travelTo(\Illuminate\Support\Carbon::parse('2026-07-22 09:00:00'));

        $cobrador = User::factory()->create();
        $cliente = $this->crearCliente($cobrador);

        // Debe únicamente del 21 (atrasado): sin incluir_vencidas no entraría a la ruta de hoy.
        $soloAtrasado = $this->crearPrestamoConCuotas($cobrador, $cliente, [
            ['fecha' => '2026-07-21'],
        ], estado: 'en_mora');

        // Debe del 21 (sin pagar) Y tiene una cuota del 22: la próxima pendiente sigue siendo la
        // del 21 — debe aparecer UNA sola vez (la del 21), nunca dos ruta_items.
        $atrasadoYHoy = $this->crearPrestamoConCuotas($cobrador, $cliente, [
            ['fecha' => '2026-07-21'],
            ['fecha' => '2026-07-22'],
        ], estado: 'en_mora');

        // Vence justo hoy, sin nada atrasado antes: debe entrar igual (con o sin la opción).
        $vencidoHoy = $this->crearPrestamoConCuotas($cobrador, $cliente, [
            ['fecha' => '2026-07-22'],
        ]);

        // Vence mañana: nunca debe entrar en la ruta de hoy.
        $vencidoManana = $this->crearPrestamoConCuotas($cobrador, $cliente, [
            ['fecha' => '2026-07-23'],
        ]);

        Sanctum::actingAs($cobrador);

        // Sin incluir_vencidas (default): los atrasados quedan fuera.
        $sinVencidas = $this->postJson('/api/rutas/autogenerar-hoy');
        $sinVencidas->assertCreated();
        $idsSinVencidas = collect($sinVencidas->json('data.items'))->pluck('prestamo_id')->all();
        $this->assertEqualsCanonicalizing([$vencidoHoy->id], $idsSinVencidas);

        // Con incluir_vencidas: los atrasados entran, cada préstamo una sola vez.
        $conVencidas = $this->postJson('/api/rutas/autogenerar-hoy', ['incluir_vencidas' => true]);
        $conVencidas->assertCreated();
        $idsConVencidas = collect($conVencidas->json('data.items'))->pluck('prestamo_id')->all();

        $this->assertEqualsCanonicalizing([$soloAtrasado->id, $atrasadoYHoy->id, $vencidoHoy->id], $idsConVencidas);
        $this->assertCount(3, $idsConVencidas);
        $this->assertNotContains($vencidoManana->id, $idsConVencidas);

        $this->travelBack();
    }
}
