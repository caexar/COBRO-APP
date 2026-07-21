<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Varios gastos por cierre (almuerzo, gasolina, etc.) — `detalle` es texto libre
     * obligatorio, no una categoría cerrada (a diferencia de `cargas_capital.categoria`).
     */
    public function up(): void
    {
        Schema::create('cierre_caja_gastos', function (Blueprint $table) {
            $table->id();
            $table->foreignId('cierre_caja_id')->constrained('cierres_caja')->cascadeOnDelete();
            $table->decimal('monto', 12, 2);
            $table->string('detalle');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('cierre_caja_gastos');
    }
};
