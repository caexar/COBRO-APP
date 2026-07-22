<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Solo tiene sentido en una ruta creada por `POST /rutas/autogenerar-hoy`: nullable, para
     * distinguir "no aplica" (ruta manual) de `false` ("solo esa fecha", la opción explícita
     * que eligió el cobrador al autogenerar). Ver `RutaService::autogenerarHoy`.
     */
    public function up(): void
    {
        Schema::table('rutas', function (Blueprint $table) {
            $table->boolean('incluye_vencidas')->nullable()->after('fecha');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('rutas', function (Blueprint $table) {
            $table->dropColumn('incluye_vencidas');
        });
    }
};
