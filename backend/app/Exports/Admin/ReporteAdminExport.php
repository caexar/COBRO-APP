<?php

namespace App\Exports\Admin;

use Maatwebsite\Excel\Concerns\WithMultipleSheets;

/**
 * El .xlsx completo de `GET/POST /admin/exportar`: las 3 hojas (préstamos, resumen por
 * cobrador, movimientos de capital) ya construidas por `ExportarReporteService`.
 */
class ReporteAdminExport implements WithMultipleSheets
{
    /**
     * @param  array<int, ArraySheetExport>  $hojas
     */
    public function __construct(
        private readonly array $hojas,
    ) {}

    public function sheets(): array
    {
        return $this->hojas;
    }
}
