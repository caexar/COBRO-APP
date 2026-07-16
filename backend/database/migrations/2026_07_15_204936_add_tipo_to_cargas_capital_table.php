<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * No pedida explícitamente en el encargo de esta tarea, pero necesaria para que
     * POST /admin/cargas-capital y POST /sync puedan aceptar/persistir el campo `tipo`
     * (carga|retiro) que ya existe del lado móvil (Drift `cargas_capital.tipo`, agregado en
     * una fase anterior) — sin esta columna no hay forma de distinguir un retiro de un aporte
     * al guardar en el servidor.
     */
    public function up(): void
    {
        Schema::table('cargas_capital', function (Blueprint $table) {
            $table->enum('tipo', ['carga', 'retiro'])->default('carga')->after('monto');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('cargas_capital', function (Blueprint $table) {
            $table->dropColumn('tipo');
        });
    }
};
