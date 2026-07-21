<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Preferencia personal del panel web (independiente por usuario admin logueado, ver
     * `App\Livewire\Admin\Configuracion\Formulario`): si escribir "300" en el campo de
     * "Monto" de `Resumen\DetalleCobrador` se interpreta como 300000 al guardar. Activada
     * por defecto. Equivalente web de `AtajoMilesRepository` en mobile (ahí vive en secure
     * storage local, no en el servidor, porque la app es offline-first).
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('atajo_miles_activado')->default(true)->after('pin_maestro_hash');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('atajo_miles_activado');
        });
    }
};
