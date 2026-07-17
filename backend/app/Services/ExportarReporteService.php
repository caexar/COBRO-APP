<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Carbon;

/**
 * Genera el CSV del panel web (`/admin/exportar`): reutiliza
 * `ResumenAdminService::prestamosDeCobrador()` para traer préstamos + pagos (no repite esas
 * queries) y solo filtra los pagos por rango de `fecha_pago` y arma las filas del archivo. Una
 * fila por pago, con el cobrador dueño siempre visible en su propia columna (puede haber varios
 * cobradores en un mismo export).
 */
class ExportarReporteService
{
    public function __construct(
        private readonly ResumenAdminService $resumenAdminService,
    ) {}

    /**
     * @param  array<int, int>  $usuarioIds
     */
    public function generarCsv(array $usuarioIds, ?Carbon $desde, ?Carbon $hasta): string
    {
        $cobradores = User::whereIn('id', $usuarioIds)->orderBy('nombre')->get();

        $buffer = fopen('php://temp', 'r+');
        fputcsv($buffer, ['Cobrador', 'Cliente - Préstamo', 'Fecha de pago', 'Monto abonado', 'Monto aplicado', 'Saldo restante después']);

        foreach ($cobradores as $cobrador) {
            foreach ($this->resumenAdminService->prestamosDeCobrador($cobrador->id) as $item) {
                foreach ($item->prestamo->pagos as $pago) {
                    if ($desde !== null && $pago->fecha_pago->lt($desde)) {
                        continue;
                    }
                    if ($hasta !== null && $pago->fecha_pago->gt($hasta)) {
                        continue;
                    }

                    fputcsv($buffer, [
                        $cobrador->nombre,
                        $item->titulo,
                        $pago->fecha_pago->format('d/m/Y'),
                        number_format((float) $pago->monto_abonado, 2, '.', ''),
                        number_format((float) $pago->monto_aplicado, 2, '.', ''),
                        number_format((float) $pago->saldo_restante_despues, 2, '.', ''),
                    ]);
                }
            }
        }

        rewind($buffer);
        $contenido = stream_get_contents($buffer);
        fclose($buffer);

        // BOM de UTF-8 (bytes EF BB BF): sin este prefijo, Excel no detecta la codificación del
        // archivo y muestra tildes/ñ como símbolos raros — mismo criterio ya corregido del lado
        // móvil (ver `csv_exportador.dart`, que antepone el carácter \uFEFF por la misma razón).
        return "\xEF\xBB\xBF".$contenido;
    }
}
