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
        Schema::create('prestamos', function (Blueprint $table) {
            $table->id();
            $table->foreignId('cliente_id')->constrained('clientes')->cascadeOnDelete();
            $table->foreignId('usuario_id')->constrained('users')->cascadeOnDelete();
            $table->decimal('monto_capital', 12, 2);
            $table->decimal('porcentaje_interes', 5, 2);
            $table->enum('frecuencia_pago', ['diario', 'semanal', 'mensual', 'personalizado']);
            $table->unsignedInteger('dias_personalizado')->nullable();
            $table->unsignedInteger('plazo_cuotas');
            $table->date('fecha_inicio');
            $table->enum('estado', ['activo', 'pagado', 'en_mora', 'anulado'])->default('activo');
            $table->enum('politica_mora', ['mantener', 'siguiente_pago', 'sumar_total'])->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['usuario_id', 'estado']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('prestamos');
    }
};
