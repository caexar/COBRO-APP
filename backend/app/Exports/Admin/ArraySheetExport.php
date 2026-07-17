<?php

namespace App\Exports\Admin;

use Maatwebsite\Excel\Concerns\FromArray;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithStrictNullComparison;
use Maatwebsite\Excel\Concerns\WithTitle;

/**
 * Una hoja genérica a partir de datos ya calculados (título + encabezados + filas) —
 * reutilizada por las 3 hojas de `ExportarReporteService::generarXlsx()` para no repetir 3
 * clases casi idénticas. Toda la lógica de negocio (qué filas van, cómo se calculan) vive en
 * el Service, no acá.
 *
 * `WithStrictNullComparison` es necesario porque, sin ella, PhpSpreadsheet compara cada valor
 * contra null con `!=` (no `!==`) al armar la hoja — y en PHP `0.0 != null` es `false` (son
 * "iguales" con comparación floja), así que cualquier celda con el número 0 quedaría en blanco
 * en vez de mostrar "0" (bug real detectado con los totales en 0 de la Hoja 2).
 */
class ArraySheetExport implements FromArray, WithHeadings, WithStrictNullComparison, WithTitle
{
    /**
     * @param  array<int, string>  $encabezados
     * @param  array<int, array<int, mixed>>  $filas
     */
    public function __construct(
        private readonly string $titulo,
        private readonly array $encabezados,
        private readonly array $filas,
    ) {}

    public function array(): array
    {
        return $this->filas;
    }

    public function headings(): array
    {
        return $this->encabezados;
    }

    public function title(): string
    {
        return $this->titulo;
    }
}
