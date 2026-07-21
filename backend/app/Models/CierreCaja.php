<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable([
    'usuario_id',
    'fecha',
    'capital_inicio',
    'capital_cierre',
    'justificacion_diferencia',
    'gastos_total',
    'uuid_local',
])]
class CierreCaja extends Model
{
    // Sin esto Eloquent infiere "cierre_cajas" (pluraliza "Caja" en vez de "CierreCaja" como
    // una sola unidad) en vez de "cierres_caja", el nombre real de la tabla — mismo bug ya
    // documentado y corregido en CargaCapital (ver create_cargas_capital_table).
    protected $table = 'cierres_caja';

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'fecha' => 'date',
            'capital_inicio' => 'decimal:2',
            'capital_cierre' => 'decimal:2',
            'gastos_total' => 'decimal:2',
        ];
    }

    /**
     * @return BelongsTo<User, CierreCaja>
     */
    public function usuario(): BelongsTo
    {
        return $this->belongsTo(User::class, 'usuario_id');
    }

    /**
     * @return HasMany<CierreCajaGasto>
     */
    public function gastos(): HasMany
    {
        return $this->hasMany(CierreCajaGasto::class, 'cierre_caja_id');
    }
}
