<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('cargas_capital', function (Blueprint $table) {
            // 'cobrador': registrada por el propio dueño (POST /cargas-capital, flujo actual).
            // 'admin': asignada por un admin a un cobrador (POST /admin/cargas-capital).
            $table->enum('origen', ['cobrador', 'admin'])->default('cobrador')->after('descripcion');

            // Solo se llena cuando origen = admin (el admin autenticado que la asignó); null
            // para el flujo normal del cobrador, donde usuario_id ya identifica al autor.
            $table->foreignId('creado_por_usuario_id')->nullable()->after('origen')
                ->constrained('users')->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('cargas_capital', function (Blueprint $table) {
            $table->dropConstrainedForeignId('creado_por_usuario_id');
            $table->dropColumn('origen');
        });
    }
};
