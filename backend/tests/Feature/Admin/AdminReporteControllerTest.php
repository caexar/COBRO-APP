<?php

namespace Tests\Feature\Admin;

use App\Models\CargaCapital;
use App\Models\Cliente;
use App\Models\Prestamo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * `GET /api/admin/reporte`: mismos datos que `ExportarReporteTest` (el .xlsx del panel web),
 * pero como JSON — comparte `ExportarReporteService::datosReporte()` con `generarXlsx()`, así
 * que acá solo se prueba que el endpoint devuelve esos 3 bloques con las filas/filtros
 * correctos y que sigue protegido por `role:admin`.
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

    public function test_devuelve_los_3_bloques_con_los_datos_correctos_filtrados_por_cobrador_y_fecha(): void
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

        $respuesta = $this->getJson('/api/admin/reporte?'.http_build_query([
            'usuario_ids' => [$cobradorA->id],
            'desde' => '2026-01-01',
            'hasta' => '2026-01-31',
        ]));

        $respuesta->assertOk();

        // Solo el cobrador filtrado (A) aparece, no B.
        $respuesta->assertJsonPath('data.prestamos.titulo', 'Detalle de préstamos');
        $respuesta->assertJsonCount(1, 'data.prestamos.filas');
        $respuesta->assertJsonPath('data.prestamos.filas.0.0', 'Ana Torres');
        // json_encode no conserva ".0" en un float de número entero, así que json_decode lo
        // trae como int -- se compara así, no como 20000.0.
        $respuesta->assertJsonPath('data.prestamos.filas.0.6', 20000); // ganancia (interés 10000 + extra 10000)

        $respuesta->assertJsonPath('data.resumen_por_cobrador.filas.0.0', 'Ana Torres');
        $respuesta->assertJsonPath('data.resumen_por_cobrador.filas.0.2', 62500); // total cobrado en el periodo

        $respuesta->assertJsonCount(1, 'data.movimientos_capital.filas');
        $respuesta->assertJsonPath('data.movimientos_capital.filas.0.0', 'Ana Torres');
        $respuesta->assertJsonPath('data.movimientos_capital.filas.0.4', 'gasto_operativo');
    }

    public function test_filtra_movimientos_de_capital_por_categoria_sin_afectar_las_otras_2_secciones(): void
    {
        $admin = User::factory()->admin()->create();
        $cobrador = User::factory()->create(['nombre' => 'Ana Torres']);
        $this->crearEscenario($cobrador);

        $this->travelTo(Carbon::parse('2026-01-10'), function () use ($cobrador) {
            CargaCapital::create(['usuario_id' => $cobrador->id, 'tipo' => 'retiro', 'monto' => 20000, 'categoria' => 'gasto_operativo']);
            CargaCapital::create(['usuario_id' => $cobrador->id, 'tipo' => 'retiro', 'monto' => 5000, 'categoria' => 'salario']);
        });

        Sanctum::actingAs($admin);

        $respuesta = $this->getJson('/api/admin/reporte?'.http_build_query([
            'usuario_ids' => [$cobrador->id],
            'categoria' => 'salario',
        ]));

        $respuesta->assertOk();
        $respuesta->assertJsonCount(1, 'data.movimientos_capital.filas');
        $respuesta->assertJsonPath('data.movimientos_capital.filas.0.4', 'salario');

        $respuesta->assertJsonCount(1, 'data.prestamos.filas');
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
