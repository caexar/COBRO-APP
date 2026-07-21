<?php

namespace Tests\Feature\Admin;

use App\Models\CargaCapital;
use App\Models\CierreCaja;
use App\Models\Cliente;
use App\Models\Prestamo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use PhpOffice\PhpSpreadsheet\IOFactory;
use Tests\TestCase;

/**
 * Exportar el reporte financiero (.xlsx) del panel web: reutiliza `ResumenAdminService`
 * (no repite queries/fórmulas), así que acá solo se prueba lo específico de este endpoint —
 * las 3 hojas traen los datos/cálculos correctos y el rango de fechas acota la Hoja 2 y la
 * Hoja 3, pero no la Hoja 1 (que siempre trae todos los préstamos existentes).
 */
class ExportarReporteTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Préstamo con un extra y un pago con excedente `cobro_extra`, para ejercitar el cálculo
     * de ganancia (interés + extra) en las 3 hojas a la vez.
     */
    private function crearEscenario(User $cobrador): Prestamo
    {
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
            'plazo_cuotas' => 2,
            'fecha_inicio' => '2026-01-01',
            'estado' => 'activo',
            'politica_mora' => 'mantener',
        ]);
        $prestamo->extras()->create(['concepto' => 'papeleria', 'valor' => 5000]);

        // monto_total = 100000 + 20000 (interés) + 5000 (extra) = 125000, repartido en 2
        // cuotas de 62500 (mismo cálculo que PrestamoCalculator).
        $cuota1 = $prestamo->cuotas()->create([
            'numero_cuota' => 1, 'fecha_esperada' => '2026-01-02', 'monto_esperado' => 62500, 'estado' => 'pagada',
        ]);
        $prestamo->cuotas()->create([
            'numero_cuota' => 2, 'fecha_esperada' => '2026-01-03', 'monto_esperado' => 62500, 'estado' => 'pendiente',
        ]);

        // Excedente cobro_extra: monto_abonado (70000) > monto_aplicado (62500).
        $prestamo->pagos()->create([
            'cuota_id' => $cuota1->id,
            'monto_abonado' => 70000,
            'monto_aplicado' => 62500,
            'fecha_pago' => '2026-01-05',
            'dias_mora' => 3,
            'saldo_restante_despues' => 62500,
        ]);

        return $prestamo->fresh();
    }

    private function leerFilas(string $contenidoXlsx, int $indiceHoja): array
    {
        $ruta = tempnam(sys_get_temp_dir(), 'cobro_app_xlsx_test_');
        file_put_contents($ruta, $contenidoXlsx);

        $filas = IOFactory::load($ruta)->getSheet($indiceHoja)->toArray(null, true, false, false);

        unlink($ruta);

        return $filas;
    }

    public function test_las_3_hojas_traen_los_datos_y_calculos_correctos(): void
    {
        $admin = User::factory()->admin()->create();
        $cobrador = User::factory()->create(['nombre' => 'Ana Torres']);
        $this->crearEscenario($cobrador);

        $this->travelTo(Carbon::parse('2026-01-10'), function () use ($cobrador) {
            CargaCapital::create([
                'usuario_id' => $cobrador->id, 'tipo' => 'retiro', 'monto' => 20000,
                'categoria' => 'gasto_operativo', 'descripcion' => 'Pago de arriendo',
            ]);
        });

        $respuesta = $this->actingAs($admin)->post('/admin/exportar', [
            'usuario_ids' => [$cobrador->id],
            'desde' => '2026-01-01',
            'hasta' => '2026-01-31',
        ]);

        $respuesta->assertOk();
        $respuesta->assertHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

        $contenido = $respuesta->getContent();

        // Hoja 1: Detalle de préstamos.
        $filasPrestamos = $this->leerFilas($contenido, 0);
        $this->assertSame(
            ['Cobrador', 'Cliente', 'Cédula', 'Capital', '% Interés', 'Valor de cada cuota', 'Ganancia', 'Capital + Interés (sin extras)', 'Plazo (cuotas)', 'Frecuencia de pago', 'Estado'],
            $filasPrestamos[0],
        );
        // PhpSpreadsheet auto-detecta valores numéricos: la cédula (sin ceros a la izquierda
        // en Colombia) se lee de vuelta como número, no como texto.
        $this->assertSame(
            ['Ana Torres', 'Juan Perez', 123456, 100000.0, 20.0, 62500.0, 20000.0, 120000.0, 2, 'diario', 'activo'],
            $filasPrestamos[1],
        );

        // Hoja 2: Resumen por cobrador — evolución dentro del rango enero.
        $filasResumen = $this->leerFilas($contenido, 1);
        $this->assertSame(
            ['Cobrador', 'Cartera pendiente al inicio', 'Total cobrado en el periodo', 'Total prestado en el periodo', 'Cartera pendiente al final', 'Ganancia por interés (periodo)', 'Ganancia por extra (periodo)'],
            $filasResumen[0],
        );
        // Sin cuotas antes del 1 de enero -> 0. Se cobró la cuota 1 (62500) dentro del rango.
        // Se prestó el capital completo (fecha_inicio 2026-01-01) dentro del rango. Al 31 de
        // enero solo queda pendiente la cuota 2 (62500, todavía sin pagar).
        $this->assertSame(['Ana Torres', 0.0, 62500.0, 100000.0, 62500.0, 10000.0, 10000.0], $filasResumen[1]);

        // Hoja 3: Movimientos de capital.
        $filasCapital = $this->leerFilas($contenido, 2);
        $this->assertSame(
            ['Cobrador', 'Fecha', 'Tipo', 'Monto', 'Categoría', 'Descripción', 'Origen'],
            $filasCapital[0],
        );
        $this->assertSame(
            ['Ana Torres', '10/01/2026', 'retiro', 20000.0, 'gasto_operativo', 'Pago de arriendo', 'cobrador'],
            $filasCapital[1],
        );
    }

    public function test_el_rango_de_fechas_acota_la_hoja_2_y_la_hoja_3_pero_no_la_hoja_1(): void
    {
        $admin = User::factory()->admin()->create();
        $cobrador = User::factory()->create(['nombre' => 'Ana Torres']);
        $this->crearEscenario($cobrador);

        $this->travelTo(Carbon::parse('2026-03-01'), function () use ($cobrador) {
            CargaCapital::create(['usuario_id' => $cobrador->id, 'tipo' => 'carga', 'monto' => 99999]);
        });

        // Rango que termina ANTES del pago (2026-01-05) y de la carga de capital (2026-03-01).
        $respuesta = $this->actingAs($admin)->post('/admin/exportar', [
            'usuario_ids' => [$cobrador->id],
            'desde' => '2026-01-01',
            'hasta' => '2026-01-04',
        ]);

        $respuesta->assertOk();
        $contenido = $respuesta->getContent();

        // Hoja 1 no se filtra por fecha: el préstamo sigue apareciendo completo.
        $filasPrestamos = $this->leerFilas($contenido, 0);
        $this->assertCount(2, $filasPrestamos); // encabezado + 1 préstamo
        $this->assertSame('Juan Perez', $filasPrestamos[1][1]);

        // Hoja 2: el pago (01-05) queda fuera del rango -> nada cobrado, ganancia en 0, y las
        // 2 cuotas (fechas 01-02 y 01-03, ninguna pagada "hasta" el 01-04) quedan pendientes.
        $filasResumen = $this->leerFilas($contenido, 1);
        $this->assertSame(['Ana Torres', 0.0, 0.0, 100000.0, 125000.0, 0.0, 0.0], $filasResumen[1]);

        // Hoja 3: la carga de marzo queda fuera del rango de enero.
        $filasCapital = $this->leerFilas($contenido, 2);
        $this->assertCount(1, $filasCapital); // solo el encabezado, sin movimientos en rango
    }

    public function test_el_filtro_de_categoria_solo_afecta_la_hoja_de_movimientos_de_capital(): void
    {
        $admin = User::factory()->admin()->create();
        $cobrador = User::factory()->create(['nombre' => 'Ana Torres']);
        $this->crearEscenario($cobrador);

        $this->travelTo(Carbon::parse('2026-01-10'), function () use ($cobrador) {
            CargaCapital::create(['usuario_id' => $cobrador->id, 'tipo' => 'retiro', 'monto' => 20000, 'categoria' => 'gasto_operativo']);
            CargaCapital::create(['usuario_id' => $cobrador->id, 'tipo' => 'retiro', 'monto' => 5000, 'categoria' => 'salario']);
        });

        $respuesta = $this->actingAs($admin)->post('/admin/exportar', [
            'usuario_ids' => [$cobrador->id],
            'categoria' => 'salario',
        ]);

        $respuesta->assertOk();
        $contenido = $respuesta->getContent();

        $filasCapital = $this->leerFilas($contenido, 2);
        $this->assertCount(2, $filasCapital); // encabezado + solo el retiro de categoria "salario"
        $this->assertSame('salario', $filasCapital[1][4]);

        // La hoja de préstamos no cambia por este filtro.
        $filasPrestamos = $this->leerFilas($contenido, 0);
        $this->assertCount(2, $filasPrestamos);
    }

    public function test_incluye_cierre_de_caja_diario_y_su_resumen_agregado_del_rango(): void
    {
        $admin = User::factory()->admin()->create();
        $cobrador = User::factory()->create(['nombre' => 'Ana Torres']);

        $cierre1 = CierreCaja::create([
            'usuario_id' => $cobrador->id,
            'fecha' => '2026-01-01',
            'capital_inicio' => 100000,
            'capital_cierre' => 120000,
            'gastos_total' => 35000,
        ]);
        $cierre1->gastos()->createMany([
            ['monto' => 10000, 'detalle' => 'almuerzo'],
            ['monto' => 25000, 'detalle' => 'gasolina'],
        ]);

        $cierre2 = CierreCaja::create([
            'usuario_id' => $cobrador->id,
            'fecha' => '2026-01-05',
            'capital_inicio' => 120000,
            'capital_cierre' => 200000,
            'justificacion_diferencia' => 'Ajuste por cambio no registrado',
            'gastos_total' => 5000,
        ]);
        $cierre2->gastos()->create(['monto' => 5000, 'detalle' => 'papeleria']);

        $respuesta = $this->actingAs($admin)->post('/admin/exportar', [
            'usuario_ids' => [$cobrador->id],
            'desde' => '2026-01-01',
            'hasta' => '2026-01-31',
        ]);

        $respuesta->assertOk();
        $contenido = $respuesta->getContent();

        // Hoja 4 (índice 3): Cierre de caja, una fila por día.
        $filasCierre = $this->leerFilas($contenido, 3);
        $this->assertSame(
            ['Cobrador', 'Fecha', 'Capital inicio', 'Capital cierre', 'Total gastos', 'Detalle de gastos', 'Justificación'],
            $filasCierre[0],
        );
        // "Justificación" queda vacía (null) para este día: no hay diferencia que explicar. Un
        // valor null se escribe/lee como celda vacía en PhpSpreadsheet, no como cadena vacía.
        $this->assertSame(
            ['Ana Torres', '01/01/2026', 100000.0, 120000.0, 35000.0, 'almuerzo ($10.000); gasolina ($25.000)', null],
            $filasCierre[1],
        );
        $this->assertSame(
            ['Ana Torres', '05/01/2026', 120000.0, 200000.0, 5000.0, 'papeleria ($5.000)', 'Ajuste por cambio no registrado'],
            $filasCierre[2],
        );

        // Hoja 5 (índice 4): resumen agregado del rango (capital inicio del primer día,
        // capital cierre del último, suma de gastos de ambos días).
        $filasResumen = $this->leerFilas($contenido, 4);
        $this->assertSame(
            ['Cobrador', 'Capital inicio (primer día)', 'Capital cierre (último día)', 'Total gastos (rango)'],
            $filasResumen[0],
        );
        $this->assertSame(['Ana Torres', 100000.0, 200000.0, 40000.0], $filasResumen[1]);
    }

    public function test_el_formulario_renderiza_el_selector_de_categoria(): void
    {
        $admin = User::factory()->admin()->create();

        $respuesta = $this->actingAs($admin)->get('/admin/exportar');

        $respuesta->assertOk();
        $respuesta->assertSee('Categoría de movimientos de capital', false);
        $respuesta->assertSee('gasto_operativo', false);
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
