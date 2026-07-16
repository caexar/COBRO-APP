<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

/**
 * Cobertura ligera de las migraciones nuevas: que las columnas existan tal como se pidieron.
 * El comportamiento real de cada una (origen/creado_por_usuario_id, tipo, uuid_local como
 * dedup key) se ejercita de punta a punta en AdminCargaCapitalControllerTest y
 * SyncControllerTest.
 */
class SchemaSyncColumnsTest extends TestCase
{
    use RefreshDatabase;

    public function test_cargas_capital_tiene_las_columnas_nuevas(): void
    {
        $this->assertTrue(Schema::hasColumns('cargas_capital', [
            'origen', 'creado_por_usuario_id', 'tipo', 'uuid_local',
        ]));
    }

    public function test_clientes_prestamos_y_pagos_tienen_uuid_local(): void
    {
        $this->assertTrue(Schema::hasColumn('clientes', 'uuid_local'));
        $this->assertTrue(Schema::hasColumn('prestamos', 'uuid_local'));
        $this->assertTrue(Schema::hasColumn('pagos', 'uuid_local'));
    }
}
