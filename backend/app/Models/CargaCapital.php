<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'usuario_id',
    'monto',
    'tipo',
    'categoria',
    'descripcion',
    'origen',
    'creado_por_usuario_id',
    'uuid_local',
    'descargado',
])]
class CargaCapital extends Model
{
    // Sin esto Eloquent infiere "carga_capitals" (pluraliza "CargaCapital" como una sola
    // palabra) en vez de "cargas_capital", el nombre real de la tabla (ver migración
    // create_cargas_capital_table) — bug preexistente que no se detectaba porque no había
    // tests automatizados tocando este modelo hasta ahora.
    protected $table = 'cargas_capital';

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'monto' => 'decimal:2',
            'descargado' => 'boolean',
        ];
    }

    /**
     * @return BelongsTo<User, CargaCapital>
     */
    public function usuario(): BelongsTo
    {
        return $this->belongsTo(User::class, 'usuario_id');
    }

    /**
     * Admin que la asignó (solo cuando origen = admin); null en el flujo normal del cobrador.
     *
     * @return BelongsTo<User, CargaCapital>
     */
    public function creadoPor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'creado_por_usuario_id');
    }
}
