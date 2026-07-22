<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Una "ruta" es una lista organizada de préstamos a cobrar, propiedad de un cobrador.
     * `fecha` nullable: con valor, la ruta está asociada a un día específico (ej. la generada
     * por `POST /rutas/autogenerar-hoy`); `null` es una ruta general/reutilizable sin fecha
     * fija. `orden` es la posición manual (drag-and-drop) de esta ruta dentro de la LISTA de
     * rutas del cobrador — no tiene relación con el orden de sus `ruta_items`.
     */
    public function up(): void
    {
        Schema::create('rutas', function (Blueprint $table) {
            $table->id();
            $table->foreignId('usuario_id')->constrained('users')->cascadeOnDelete();
            $table->string('nombre');
            $table->text('descripcion')->nullable();
            $table->date('fecha')->nullable();
            $table->integer('orden')->default(0);
            // Nullable: igual que clientes/prestamos/cargas_capital/cierres_caja, una ruta
            // creada directo contra la API (fuera de sync) no trae uuid_local.
            $table->string('uuid_local')->nullable();
            $table->timestamps();

            $table->unique(['usuario_id', 'uuid_local']);
            $table->index(['usuario_id', 'orden']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('rutas');
    }
};
