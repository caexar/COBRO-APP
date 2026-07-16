<?php

namespace App\Services;

use App\Models\Cuota;
use App\Models\Pago;
use App\Models\Prestamo;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class PagoProcessor
{
    /**
     * Registra un pago contra la cuota pendiente más antigua de un préstamo,
     * aplicando la política de mora del préstamo si el abono no la cubre por completo,
     * o pidiendo una decisión explícita si el abono la supera.
     *
     * Devuelve una colección de Pago: normalmente uno solo, pero puede haber varios
     * cuando un excedente (manejo_excedente=abono_deuda) alcanza a cubrir cuotas
     * futuras, ya que cada pago solo puede referenciar una cuota (cuota_id).
     *
     * @param  array{monto_abonado: float|string, fecha_pago: string, manejo_excedente?: string|null}  $datos
     * @return Collection<int, Pago>
     */
    public function procesar(Prestamo $prestamo, array $datos): Collection
    {
        return DB::transaction(function () use ($prestamo, $datos) {
            $prestamo = Prestamo::whereKey($prestamo->id)->lockForUpdate()->firstOrFail();

            if ($prestamo->estado === 'anulado') {
                throw new RuntimeException('No se pueden registrar pagos sobre un préstamo anulado.');
            }

            $cuota = $prestamo->cuotas()
                ->where('estado', '!=', 'pagada')
                ->orderBy('numero_cuota')
                ->lockForUpdate()
                ->first();

            if (! $cuota) {
                throw new RuntimeException('Este préstamo no tiene cuotas pendientes por pagar.');
            }

            $fechaPago = Carbon::parse($datos['fecha_pago']);
            $fechaEsperada = Carbon::parse($cuota->fecha_esperada);
            $diasMora = $fechaPago->gt($fechaEsperada) ? $fechaEsperada->diffInDays($fechaPago) : 0;

            $pendienteEnCuota = $this->pendienteEnCuota($cuota);
            $montoAbonado = round((float) $datos['monto_abonado'], 2);
            $pagosCreados = collect();

            if ($montoAbonado > $pendienteEnCuota) {
                $manejoExcedente = $datos['manejo_excedente'] ?? null;

                if (! in_array($manejoExcedente, ['abono_deuda', 'cobro_extra'], true)) {
                    throw new RuntimeException(
                        'El abono supera el monto pendiente de la cuota. Especifica "manejo_excedente" '.
                        '("abono_deuda" para restar el excedente de la deuda total, o "cobro_extra" si no debe afectar el préstamo).'
                    );
                }

                $excedente = round($montoAbonado - $pendienteEnCuota, 2);
                $cuota->estado = 'pagada';
                $cuota->save();

                // 'cobro_extra': el excedente queda registrado en monto_abonado de esta misma fila
                // pero no se aplica a la deuda (monto_aplicado se queda solo con lo que cubría la cuota).
                $montoAbonadoFila = $manejoExcedente === 'cobro_extra' ? $montoAbonado : $pendienteEnCuota;
                $pagosCreados->push($this->crearPago($prestamo, $cuota, $montoAbonadoFila, $pendienteEnCuota, $fechaPago, $diasMora));

                if ($manejoExcedente === 'abono_deuda') {
                    $pagosCreados = $pagosCreados->merge(
                        $this->aplicarExcedenteComoAbono($prestamo, $cuota, $excedente, $fechaPago)
                    );
                }
            } elseif ($montoAbonado < $pendienteEnCuota) {
                $faltante = round($pendienteEnCuota - $montoAbonado, 2);
                $this->aplicarPoliticaMora($prestamo, $cuota, $faltante, $diasMora);
                $pagosCreados->push($this->crearPago($prestamo, $cuota, $montoAbonado, $montoAbonado, $fechaPago, $diasMora));
            } else {
                $cuota->estado = 'pagada';
                $cuota->save();
                $pagosCreados->push($this->crearPago($prestamo, $cuota, $montoAbonado, $montoAbonado, $fechaPago, $diasMora));
            }

            $this->actualizarEstadoPrestamo($prestamo);

            return $pagosCreados;
        });
    }

    private function pendienteEnCuota(Cuota $cuota): float
    {
        $yaAplicado = (float) Pago::where('cuota_id', $cuota->id)->sum('monto_aplicado');

        return round((float) $cuota->monto_esperado - $yaAplicado, 2);
    }

    private function crearPago(
        Prestamo $prestamo,
        Cuota $cuota,
        float $montoAbonado,
        float $montoAplicado,
        Carbon $fechaPago,
        int $diasMora,
    ): Pago {
        $totalAplicadoPrevio = (float) Pago::where('prestamo_id', $prestamo->id)->sum('monto_aplicado');
        $saldoRestante = max(round($prestamo->monto_total - ($totalAplicadoPrevio + $montoAplicado), 2), 0.0);

        return Pago::create([
            'prestamo_id' => $prestamo->id,
            'cuota_id' => $cuota->id,
            'monto_abonado' => $montoAbonado,
            'monto_aplicado' => $montoAplicado,
            'fecha_pago' => $fechaPago->toDateString(),
            'dias_mora' => $diasMora,
            'saldo_restante_despues' => $saldoRestante,
        ]);
    }

    /**
     * Aplica un excedente de pago como abono a la deuda: lo va descontando de las
     * siguientes cuotas pendientes en orden, marcándolas como pagadas si alcanza,
     * dejando un registro de pago propio por cada cuota que resulte abonada.
     *
     * @return Collection<int, Pago>
     */
    private function aplicarExcedenteComoAbono(Prestamo $prestamo, Cuota $cuotaActual, float $excedente, Carbon $fechaPago): Collection
    {
        $pagosCreados = collect();

        $siguientes = $prestamo->cuotas()
            ->where('estado', '!=', 'pagada')
            ->where('numero_cuota', '>', $cuotaActual->numero_cuota)
            ->orderBy('numero_cuota')
            ->lockForUpdate()
            ->get();

        foreach ($siguientes as $siguiente) {
            if ($excedente <= 0) {
                break;
            }

            $pendiente = $this->pendienteEnCuota($siguiente);
            $aAplicar = min($excedente, $pendiente);

            if ($aAplicar >= $pendiente) {
                $siguiente->estado = 'pagada';
            }

            $siguiente->save();

            $pagosCreados->push($this->crearPago($prestamo, $siguiente, $aAplicar, $aAplicar, $fechaPago, 0));

            $excedente = round($excedente - $aAplicar, 2);
        }

        return $pagosCreados;
    }

    /**
     * Cuando el abono no alcanza a cubrir la cuota, aplica la política de mora
     * configurada en el préstamo (mantener | siguiente_pago | sumar_total).
     */
    private function aplicarPoliticaMora(Prestamo $prestamo, Cuota $cuotaActual, float $faltante, int $diasMora): void
    {
        $politica = $prestamo->politica_mora ?? 'mantener';

        if ($politica === 'siguiente_pago') {
            $siguiente = $prestamo->cuotas()
                ->where('estado', '!=', 'pagada')
                ->where('numero_cuota', '>', $cuotaActual->numero_cuota)
                ->orderBy('numero_cuota')
                ->lockForUpdate()
                ->first();

            if ($siguiente) {
                $siguiente->monto_esperado = round((float) $siguiente->monto_esperado + $faltante, 2);
                $siguiente->save();
                $cuotaActual->estado = 'pagada';
                $cuotaActual->save();

                return;
            }

            // No hay una siguiente cuota a la cual trasladar el faltante: se mantiene en la cuota actual.
            $politica = 'mantener';
        }

        if ($politica === 'sumar_total') {
            $pendientes = $prestamo->cuotas()
                ->where('estado', '!=', 'pagada')
                ->where('id', '!=', $cuotaActual->id)
                ->orderBy('numero_cuota')
                ->lockForUpdate()
                ->get();

            if ($pendientes->isNotEmpty()) {
                $porCuota = round($faltante / $pendientes->count(), 2);
                $acumulado = 0.0;
                $total = $pendientes->count();

                foreach ($pendientes as $index => $pendiente) {
                    $esUltima = $index === $total - 1;
                    $incremento = $esUltima ? round($faltante - $acumulado, 2) : $porCuota;
                    $acumulado += $incremento;

                    $pendiente->monto_esperado = round((float) $pendiente->monto_esperado + $incremento, 2);
                    $pendiente->save();
                }

                $cuotaActual->estado = 'pagada';
                $cuotaActual->save();

                return;
            }

            // No hay otras cuotas pendientes entre las cuales repartir el faltante: se mantiene en la cuota actual.
        }

        // Política 'mantener' (o sin alternativa disponible): la cuota queda abierta con el faltante pendiente.
        $cuotaActual->estado = $diasMora > 0 ? 'en_mora' : 'pendiente';
        $cuotaActual->save();
    }

    private function actualizarEstadoPrestamo(Prestamo $prestamo): void
    {
        $quedaPendiente = $prestamo->cuotas()->where('estado', '!=', 'pagada')->exists();

        if (! $quedaPendiente) {
            $estado = 'pagado';
        } elseif ($prestamo->cuotas()->where('estado', 'en_mora')->exists()) {
            $estado = 'en_mora';
        } else {
            $estado = 'activo';
        }

        if ($prestamo->estado !== $estado) {
            $prestamo->update(['estado' => $estado]);
        }
    }
}
