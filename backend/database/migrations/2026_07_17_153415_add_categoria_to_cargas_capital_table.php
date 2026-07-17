<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Solo tiene sentido cuando tipo = retiro (clasifica en qué se fue el dinero); para
     * tipo = carga queda siempre null. No se valida a nivel de base de datos que un `carga`
     * no tenga categoria (esa regla vive en `StoreAdminCargaCapitalRequest`), igual que el
     * resto de reglas condicionales de este proyecto.
     */
    public function up(): void
    {
        Schema::table('cargas_capital', function (Blueprint $table) {
            $table->enum('categoria', ['gasto_operativo', 'decision_jefe', 'salario', 'otro'])
                ->nullable()
                ->after('tipo');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('cargas_capital', function (Blueprint $table) {
            $table->dropColumn('categoria');
        });
    }
};
