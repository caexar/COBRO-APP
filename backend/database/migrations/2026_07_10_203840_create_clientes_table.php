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
        Schema::create('clientes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('usuario_id')->constrained('users')->cascadeOnDelete();
            $table->string('nombre');
            $table->string('cedula');
            $table->string('telefono');
            $table->string('direccion');
            $table->string('referencia')->nullable();
            $table->string('foto_url')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['usuario_id', 'nombre']);
            $table->unique(['usuario_id', 'cedula']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('clientes');
    }
};
