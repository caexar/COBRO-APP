<?php

namespace Tests\Unit\Services;

use App\Services\PrestamoCalculator;
use PHPUnit\Framework\TestCase;

class PrestamoCalculatorTest extends TestCase
{
    public function test_frecuencia_quincenal_suma_15_dias_por_cuota(): void
    {
        // Mismos valores usados para verificar el lado mobile (prestamo_calculator_test.dart):
        // capital 1000, 0% interés, 2 cuotas quincenales desde 2026-01-01.
        $resultado = (new PrestamoCalculator())->calcular([
            'monto_capital' => 1000,
            'porcentaje_interes' => 0,
            'frecuencia_pago' => 'quincenal',
            'plazo_cuotas' => 2,
            'fecha_inicio' => '2026-01-01',
        ]);

        $this->assertSame('2026-01-16', $resultado['cuotas'][0]['fecha_esperada']);
        $this->assertSame('2026-01-31', $resultado['cuotas'][1]['fecha_esperada']);
    }
}
