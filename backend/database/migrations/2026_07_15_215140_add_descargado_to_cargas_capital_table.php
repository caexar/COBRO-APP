<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Solo tiene sentido para `origen = admin` (una carga que el propio cobrador registró ya
     * nace "conocida" en su dispositivo, nunca hace falta bajarla): marca si ya se incluyó en
     * una respuesta de `POST /sync` para el cobrador dueño, para no reenviarla en cada
     * sincronización. Se marca `true` recién después de construir la respuesta exitosamente
     * (ver `SyncService`) — si la sincronización se corta a mitad de camino, se reintenta en
     * la próxima en vez de perderse.
     */
    public function up(): void
    {
        Schema::table('cargas_capital', function (Blueprint $table) {
            $table->boolean('descargado')->default(false)->after('creado_por_usuario_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('cargas_capital', function (Blueprint $table) {
            $table->dropColumn('descargado');
        });
    }
};
