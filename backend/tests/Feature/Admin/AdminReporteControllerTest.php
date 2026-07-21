<?php

namespace Tests\Feature\Admin;

use App\Models\CargaCapital;
use App\Models\Cliente;
use App\Models\Prestamo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use PhpOffice\PhpSpreadsheet\IOFactory;
use Tests\TestCase;

/**
 * `GET /api/admin/reporte`: mismo .xlsx de 5 hojas que ya descarga el panel web (comparte
 * `ExportarReporteService::generarXlsx()`, ver `ExportarReporteTest` para la cobertura completa
 * de cada hoja/fórmula) — acá solo se prueba que el endpoint móvil responde con el binario
 * correcto (headers + contenido de una hoja), los mismos filtros de `usuario_ids`/fechas/
 * categoria, y que sigue protegido por `role:admin`.
 */
class AdminReporteControllerTest extends TestCase
{
    use RefreshDatabase;

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

        $cuota1 = $prestamo->cuotas()->create([
            'numero_cuota' => 1, 'fecha_esperada' => '2026-01-02', 'monto_esperado' => 62500, 'estado' => 'pagada',
        ]);
        $prestamo->cuotas()->create([
            'numero_cuota' => 2, 'fecha_esperada' => '2026-01-03', 'monto_esperado' => 62500, 'estado' => 'pendiente',
        ]);

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

    public function test_devuelve_el_xlsx_con_las_5_hojas_filtradas_por_cobrador_y_fecha(): void
    {
        $admin = User::factory()->admin()->create();
        $cobradorA = User::factory()->create(['nombre' => 'Ana Torres']);
        $cobradorB = User::factory()->create(['nombre' => 'Luis Rojas']);
        $this->crearEscenario($cobradorA);
        $this->crearEscenario($cobradorB);

        $this->travelTo(Carbon::parse('2026-01-10'), function () use ($cobradorA) {
            CargaCapital::create([
                'usuario_id' => $cobradorA->id, 'tipo' => 'retiro', 'monto' => 20000,
                'categoria' => 'gasto_operativo', 'descripcion' => 'Pago de arriendo',
            ]);
        });

        Sanctum::actingAs($admin);

        $respuesta = $this->get('/api/admin/reporte?'.http_build_query([
            'usuario_ids' => [$cobradorA->id],
            'desde' => '2026-01-01',
            'hasta' => '2026-01-31',
        ]));

        $respuesta->assertOk();
        $respuesta->assertHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

        $contenido = $respuesta->getContent();

        // Hoja 1: Detalle de préstamos — solo el cobrador filtrado (A) aparece, no B.
        $filasPrestamos = $this->leerFilas($contenido, 0);
        $this->assertCount(2, $filasPrestamos); // encabezado + 1 préstamo
        $this->assertSame('Ana Torres', $filasPrestamos[1][0]);

        // Hoja 4 (índice 3): Cierre de caja — presente aunque este escenario no tenga cierres,
        // solo el encabezado (confirma que la hoja existe, no que la sección de cierre de caja
        // desapareciera del endpoint móvil).
        $filasCierre = $this->leerFilas($contenido, 3);
        $this->assertSame(
            ['Cobrador', 'Fecha', 'Capital inicio', 'Capital cierre', 'Total gastos', 'Detalle de gastos', 'Justificación'],
            $filasCierre[0],
        );
    }

    public function test_requiere_al_menos_un_cobrador(): void
    {
        $admin = User::factory()->admin()->create();

        Sanctum::actingAs($admin);

        $respuesta = $this->getJson('/api/admin/reporte');

        $respuesta->assertUnprocessable();
        $respuesta->assertJsonValidationErrors('usuario_ids');
    }

    public function test_un_cobrador_no_puede_usar_este_endpoint(): void
    {
        $cobrador = User::factory()->create();

        Sanctum::actingAs($cobrador);

        $respuesta = $this->getJson('/api/admin/reporte?'.http_build_query(['usuario_ids' => [$cobrador->id]]));

        $respuesta->assertForbidden();
    }
}
