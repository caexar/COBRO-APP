<?php

namespace Tests\Feature\Admin;

use App\Models\Cliente;
use App\Models\Prestamo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Exportar CSV del panel web: reutiliza `ResumenAdminService::prestamosDeCobrador()` (no repite
 * queries), así que acá solo se prueba lo específico de este endpoint: el BOM de UTF-8 al
 * principio del archivo y que filtre bien por cobrador y por rango de fecha_pago.
 */
class ExportarReporteTest extends TestCase
{
    use RefreshDatabase;

    private function crearPrestamoConPago(User $cobrador, string $nombreCliente, string $fechaPago): Prestamo
    {
        $cliente = Cliente::create([
            'usuario_id' => $cobrador->id,
            'nombre' => $nombreCliente,
            'cedula' => (string) random_int(100000, 999999),
            'telefono' => '3000000000',
            'direccion' => 'Calle 1',
        ]);

        $prestamo = Prestamo::create([
            'cliente_id' => $cliente->id,
            'usuario_id' => $cobrador->id,
            'monto_capital' => 100000,
            'porcentaje_interes' => 20,
            'frecuencia_pago' => 'diario',
            'plazo_cuotas' => 2,
            'fecha_inicio' => '2026-01-01',
            'estado' => 'activo',
            'politica_mora' => 'mantener',
        ]);

        $prestamo->pagos()->create([
            'monto_abonado' => 60000,
            'monto_aplicado' => 60000,
            'fecha_pago' => $fechaPago,
            'dias_mora' => 0,
            'saldo_restante_despues' => 60000,
        ]);

        return $prestamo;
    }

    public function test_el_csv_tiene_el_bom_de_utf8_y_filtra_por_cobrador_y_fecha(): void
    {
        $admin = User::factory()->admin()->create();
        $cobradorA = User::factory()->create(['nombre' => 'Ana Torres']);
        $cobradorB = User::factory()->create(['nombre' => 'Luis Rojas']);

        $this->crearPrestamoConPago($cobradorA, 'José Peña', '2026-01-05');
        $this->crearPrestamoConPago($cobradorA, 'María Gómez', '2026-03-01');
        $this->crearPrestamoConPago($cobradorB, 'Otro Cliente', '2026-01-05');

        $respuesta = $this->actingAs($admin)->post('/admin/exportar', [
            'usuario_ids' => [$cobradorA->id],
            'desde' => '2026-01-01',
            'hasta' => '2026-01-31',
        ]);

        $respuesta->assertOk();
        $respuesta->assertHeader('Content-Type', 'text/csv; charset=UTF-8');

        $contenido = $respuesta->getContent();

        // BOM de UTF-8 (EF BB BF) al inicio del archivo, para que Excel detecte la codificación.
        $this->assertSame("\xEF\xBB\xBF", substr($contenido, 0, 3));

        $this->assertStringContainsString('Ana Torres', $contenido);
        $this->assertStringContainsString('José Peña', $contenido);

        // Cobrador no seleccionado: no debe aparecer.
        $this->assertStringNotContainsString('Luis Rojas', $contenido);
        $this->assertStringNotContainsString('Otro Cliente', $contenido);

        // Pago fuera del rango de fechas: no debe aparecer.
        $this->assertStringNotContainsString('María Gómez', $contenido);
        $this->assertStringNotContainsString('01/03/2026', $contenido);
        $this->assertStringContainsString('05/01/2026', $contenido);
    }

    public function test_requiere_al_menos_un_cobrador_seleccionado(): void
    {
        $admin = User::factory()->admin()->create();

        $respuesta = $this->actingAs($admin)->post('/admin/exportar', [
            'usuario_ids' => [],
        ]);

        $respuesta->assertSessionHasErrors('usuario_ids');
    }
}
