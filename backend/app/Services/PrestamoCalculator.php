<?php

namespace App\Services;

use Illuminate\Support\Carbon;
use InvalidArgumentException;

class PrestamoCalculator
{
    /**
     * Únicas frecuencias de pago válidas — reutilizada por las reglas de validación
     * (`StorePrestamoRequest`, `SimularPrestamoRequest`, `StoreSyncRequest`) para que agregar
     * una frecuencia nueva no vuelva a requerir tocar cada Form Request por separado.
     */
    public const FRECUENCIAS_VALIDAS = ['diario', 'semanal', 'quincenal', 'mensual', 'personalizado'];

    /**
     * Calcula el monto total a pagar de un préstamo (capital + interés + extras)
     * y genera el reparto de cuotas según la frecuencia de pago elegida.
     *
     * @param  array{
     *     monto_capital: float|string,
     *     porcentaje_interes: float|string,
     *     extras?: array<int, array{concepto: string, valor: float|string}>,
     *     frecuencia_pago: string,
     *     dias_personalizado?: int|null,
     *     plazo_cuotas: int,
     *     fecha_inicio: string,
     * }  $datos
     * @return array{
     *     monto_capital: float,
     *     monto_interes: float,
     *     monto_extras: float,
     *     monto_total: float,
     *     cuotas: array<int, array{numero_cuota: int, fecha_esperada: string, monto_esperado: float, estado: string}>,
     * }
     */
    public function calcular(array $datos): array
    {
        $capital = round((float) $datos['monto_capital'], 2);
        $interes = round($capital * ((float) $datos['porcentaje_interes'] / 100), 2);
        $montoExtras = round(collect($datos['extras'] ?? [])->sum(fn (array $extra) => (float) $extra['valor']), 2);
        $montoTotal = round($capital + $interes + $montoExtras, 2);

        return [
            'monto_capital' => $capital,
            'monto_interes' => $interes,
            'monto_extras' => $montoExtras,
            'monto_total' => $montoTotal,
            'cuotas' => $this->repartirCuotas(
                montoTotal: $montoTotal,
                plazoCuotas: (int) $datos['plazo_cuotas'],
                fechaInicio: Carbon::parse($datos['fecha_inicio']),
                frecuenciaPago: $datos['frecuencia_pago'],
                diasPersonalizado: $datos['dias_personalizado'] ?? null,
            ),
        ];
    }

    /**
     * @return array<int, array{numero_cuota: int, fecha_esperada: string, monto_esperado: float, estado: string}>
     */
    private function repartirCuotas(
        float $montoTotal,
        int $plazoCuotas,
        Carbon $fechaInicio,
        string $frecuenciaPago,
        ?int $diasPersonalizado,
    ): array {
        $montoBase = round($montoTotal / $plazoCuotas, 2);
        $acumulado = 0.0;
        $cuotas = [];

        for ($numero = 1; $numero <= $plazoCuotas; $numero++) {
            $esUltima = $numero === $plazoCuotas;
            $monto = $esUltima ? round($montoTotal - $acumulado, 2) : $montoBase;
            $acumulado += $monto;

            $cuotas[] = [
                'numero_cuota' => $numero,
                'fecha_esperada' => $this->fechaParaCuota($fechaInicio, $frecuenciaPago, $diasPersonalizado, $numero)->toDateString(),
                'monto_esperado' => $monto,
                'estado' => 'pendiente',
            ];
        }

        return $cuotas;
    }

    private function fechaParaCuota(Carbon $fechaInicio, string $frecuenciaPago, ?int $diasPersonalizado, int $numero): Carbon
    {
        return match ($frecuenciaPago) {
            'diario' => $fechaInicio->copy()->addDays($numero),
            'semanal' => $fechaInicio->copy()->addWeeks($numero),
            'quincenal' => $fechaInicio->copy()->addDays(15 * $numero),
            'mensual' => $fechaInicio->copy()->addMonthsNoOverflow($numero),
            'personalizado' => $fechaInicio->copy()->addDays((int) $diasPersonalizado * $numero),
            default => throw new InvalidArgumentException("Frecuencia de pago inválida: {$frecuenciaPago}"),
        };
    }
}
