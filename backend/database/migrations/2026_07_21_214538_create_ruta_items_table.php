<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Un préstamo dentro de una ruta. `orden` es la posición manual (drag-and-drop) DENTRO de
     * esa ruta — independiente del `orden` de `rutas`. `cobrado_en` se llena al marcar el ítem
     * como cobrado, ya sea directo desde esta pantalla o porque se registró un pago real para
     * ese préstamo (ver App\Services\RutaService / integración pendiente en el flujo de pagos).
     *
     * `uuid_local` único junto con `ruta_id` (no `usuario_id`, que esta tabla no tiene propio)
     * — mismo criterio que `pagos.uuid_local`, único junto con `prestamo_id`.
     */
    public function up(): void
    {
        Schema::create('ruta_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ruta_id')->constrained('rutas')->cascadeOnDelete();
            $table->foreignId('prestamo_id')->constrained('prestamos')->cascadeOnDelete();
            $table->integer('orden')->default(0);
            $table->enum('estado', ['pendiente', 'cobrado'])->default('pendiente');
            $table->timestamp('cobrado_en')->nullable();
            $table->string('uuid_local')->nullable();
            $table->timestamps();

            $table->unique(['ruta_id', 'uuid_local']);
            $table->index(['ruta_id', 'orden']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('ruta_items');
    }
};
