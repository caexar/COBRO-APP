<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * `uuid_local`: generado por la app móvil al crear cada registro localmente (offline) y
     * enviado en POST /sync. Permite detectar si un registro ya fue recibido antes y evitar
     * duplicados si una sincronización se reintenta tras cortarse a mitad de camino.
     *
     * Nullable porque los registros creados directo contra la API (fuera de sync, ej. un admin
     * usando Postman) nunca traen uuid_local — no existe un "local" del que haya venido.
     *
     * `pagos` no tiene columna `usuario_id` propia (el dueño se deriva de `prestamo_id" ->
     * `prestamos.usuario_id`, ver CLAUDE.md), así que ahí la unicidad se ancla a `prestamo_id`
     * en vez de `usuario_id` como en las otras tres tablas.
     */
    public function up(): void
    {
        Schema::table('clientes', function (Blueprint $table) {
            $table->string('uuid_local')->nullable()->after('id');
            $table->unique(['usuario_id', 'uuid_local']);
        });

        Schema::table('prestamos', function (Blueprint $table) {
            $table->string('uuid_local')->nullable()->after('id');
            $table->unique(['usuario_id', 'uuid_local']);
        });

        Schema::table('pagos', function (Blueprint $table) {
            $table->string('uuid_local')->nullable()->after('id');
            $table->unique(['prestamo_id', 'uuid_local']);
        });

        Schema::table('cargas_capital', function (Blueprint $table) {
            $table->string('uuid_local')->nullable()->after('id');
            $table->unique(['usuario_id', 'uuid_local']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('clientes', function (Blueprint $table) {
            $table->dropUnique(['usuario_id', 'uuid_local']);
            $table->dropColumn('uuid_local');
        });

        Schema::table('prestamos', function (Blueprint $table) {
            $table->dropUnique(['usuario_id', 'uuid_local']);
            $table->dropColumn('uuid_local');
        });

        Schema::table('pagos', function (Blueprint $table) {
            $table->dropUnique(['prestamo_id', 'uuid_local']);
            $table->dropColumn('uuid_local');
        });

        Schema::table('cargas_capital', function (Blueprint $table) {
            $table->dropUnique(['usuario_id', 'uuid_local']);
            $table->dropColumn('uuid_local');
        });
    }
};
