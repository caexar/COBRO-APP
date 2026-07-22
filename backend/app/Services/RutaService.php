<?php

namespace App\Services;

use App\Models\Cuota;
use App\Models\Prestamo;
use App\Models\Ruta;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class RutaService
{
    /**
     * Crea una ruta nueva y la llena con un ruta_item por cada préstamo `activo`/`en_mora` del
     * cobrador cuya PRÓXIMA cuota pendiente vence en [$fecha] (hoy por defecto si se omite —
     * de ahí el nombre del método, aunque acepte cualquier día).
     *
     * "Próxima cuota pendiente" es exactamente el mismo criterio que ya usa `PagoProcessor`
     * para decidir contra qué cuota se aplica un pago: la de menor `numero_cuota` con
     * `estado != pagada`. Con [$incluirVencidas] en `false` (default) no es "cualquier cuota
     * del préstamo vence ese día" — un préstamo en mora cuya cuota atrasada más vieja es de días
     * anteriores a [$fecha] (y la de esa fecha es una futura, todavía no la que toca cobrar) no
     * entra hasta que se ponga al día.
     *
     * Con [$incluirVencidas] en `true`, además de los que vencen justo en [$fecha] entran los
     * que ya estén atrasados de días anteriores (próxima cuota pendiente con
     * `fecha_esperada <= $fecha`). Un préstamo que deba varios días atrás (ej. 21 y 22 de julio,
     * generando la ruta del 22) aparece **una sola vez** — nunca se agregan dos ruta_items por
     * el mismo préstamo, porque siempre se evalúa (y se agrega, si corresponde) solo su próxima
     * cuota pendiente, la más antigua sin pagar.
     *
     * Los ruta_items quedan en el mismo orden en que se encontraron los préstamos (el cobrador
     * los reordena después manualmente vía `PUT /rutas/{ruta}/items/reordenar`).
     */
    public function autogenerarHoy(User $usuario, ?Carbon $fecha = null, bool $incluirVencidas = false): Ruta
    {
        $fechaObjetivo = ($fecha ?? Carbon::today())->startOfDay();
        $esHoy = $fechaObjetivo->isToday();

        $prestamos = Prestamo::where('usuario_id', $usuario->id)
            ->whereIn('estado', ['activo', 'en_mora'])
            ->with(['cuotas' => fn ($query) => $query->orderBy('numero_cuota')])
            ->get()
            ->filter(function (Prestamo $prestamo) use ($fechaObjetivo, $incluirVencidas) {
                $proximaCuota = $prestamo->cuotas->first(fn (Cuota $cuota) => $cuota->estado !== 'pagada');

                if ($proximaCuota === null) {
                    return false;
                }

                return $incluirVencidas
                    ? $proximaCuota->fecha_esperada->lte($fechaObjetivo)
                    : $proximaCuota->fecha_esperada->isSameDay($fechaObjetivo);
            })
            ->values();

        return DB::transaction(function () use ($usuario, $fechaObjetivo, $esHoy, $prestamos) {
            $ruta = Ruta::create([
                'usuario_id' => $usuario->id,
                'nombre' => ($esHoy ? 'Ruta de hoy ' : 'Ruta del ').$fechaObjetivo->toDateString(),
                'fecha' => $fechaObjetivo->toDateString(),
                'orden' => Ruta::where('usuario_id', $usuario->id)->count(),
            ]);

            foreach ($prestamos as $indice => $prestamo) {
                $ruta->items()->create([
                    'prestamo_id' => $prestamo->id,
                    'orden' => $indice,
                    'estado' => 'pendiente',
                ]);
            }

            return $ruta->load('items.prestamo.cliente');
        });
    }
}
