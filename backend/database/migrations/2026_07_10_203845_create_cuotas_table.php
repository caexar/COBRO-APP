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
        Schema::create('cuotas', function (Blueprint $table) {
            $table->id();
            $table->foreignId('prestamo_id')->constrained('prestamos')->cascadeOnDelete();
            $table->unsignedInteger('numero_cuota');
            $table->date('fecha_esperada');
            $table->decimal('monto_esperado', 12, 2);
            $table->enum('estado', ['pendiente', 'pagada', 'en_mora'])->default('pendiente');
            $table->timestamps();

            $table->unique(['prestamo_id', 'numero_cuota']);
            $table->index(['prestamo_id', 'estado']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('cuotas');
    }
};
