<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Agrega "quincenal" (cada 15 días) a las frecuencias de pago ya existentes (diario,
     * semanal, mensual, personalizado) — ver `App\Services\PrestamoCalculator`. Laravel 11+
     * reescribe la tabla completa en SQLite para un `enum(...)->change()` (no soporta ALTER
     * COLUMN nativo), así que hay que redeclarar `estado`/`politica_mora` tal cual estaban en
     * el mismo `Schema::table()`, o el rebuild los deja sin su CHECK constraint (confirmado
     * probándolo: sin esto, esas dos columnas quedan como `varchar` suelto, sin validar nada a
     * nivel de base de datos). En MySQL esto es un simple `MODIFY COLUMN` nativo (Laravel 11+
     * ya no necesita `doctrine/dbal` para `->change()`), sin este efecto secundario.
     */
    public function up(): void
    {
        Schema::table('prestamos', function (Blueprint $table) {
            $table->enum('frecuencia_pago', ['diario', 'semanal', 'quincenal', 'mensual', 'personalizado'])->change();
            $table->enum('estado', ['activo', 'pagado', 'en_mora', 'anulado'])->default('activo')->change();
            $table->enum('politica_mora', ['mantener', 'siguiente_pago', 'sumar_total'])->nullable()->change();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('prestamos', function (Blueprint $table) {
            $table->enum('frecuencia_pago', ['diario', 'semanal', 'mensual', 'personalizado'])->change();
            $table->enum('estado', ['activo', 'pagado', 'en_mora', 'anulado'])->default('activo')->change();
            $table->enum('politica_mora', ['mantener', 'siguiente_pago', 'sumar_total'])->nullable()->change();
        });
    }
};
