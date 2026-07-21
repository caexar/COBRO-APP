<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * `fecha` es la fecha operativa que el cobrador elige (default hoy, editable) — distinta
     * de `created_at`, que Laravel llena solo con el timestamp real de cuándo se registró el
     * cierre en el sistema (nunca editable). `capital_inicio`/`capital_cierre` vienen
     * prellenados por la app con el saldo disponible calculado localmente
     * (`DashboardRepository.calcularResumen`, mismo criterio que el backend
     * `CapitalService::calcularSaldoDisponible`), pero el cobrador puede editarlos antes de
     * guardar; `justificacion_diferencia` es la explicación cuando lo hace (esa comparación
     * "¿difiere del valor prellenado?" es una regla de UI, se resuelve en la app — el backend
     * no conoce el valor prellenado, solo persiste lo que llega). `gastos_total` se deriva en
     * el backend como la suma de `cierre_caja_gastos.monto` al crear el registro, no se confía
     * en un total que mande el cliente.
     */
    public function up(): void
    {
        Schema::create('cierres_caja', function (Blueprint $table) {
            $table->id();
            $table->foreignId('usuario_id')->constrained('users')->cascadeOnDelete();
            $table->date('fecha');
            $table->decimal('capital_inicio', 12, 2);
            $table->decimal('capital_cierre', 12, 2);
            $table->text('justificacion_diferencia')->nullable();
            $table->decimal('gastos_total', 12, 2)->default(0);
            // Nullable: un cierre creado directo contra la API (fuera de sync) no trae uno.
            // Mismo criterio de unicidad que clientes/prestamos/cargas_capital (ver
            // add_uuid_local_to_..._tables) — clave de deduplicación para POST /api/sync.
            $table->string('uuid_local')->nullable();
            $table->timestamps();

            $table->unique(['usuario_id', 'uuid_local']);
            $table->index(['usuario_id', 'fecha']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('cierres_caja');
    }
};
