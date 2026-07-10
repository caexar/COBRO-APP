<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable([
    'prestamo_id',
    'numero_cuota',
    'fecha_esperada',
    'monto_esperado',
    'estado',
])]
class Cuota extends Model
{
    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'fecha_esperada' => 'date',
            'monto_esperado' => 'decimal:2',
        ];
    }

    /**
     * @return BelongsTo<Prestamo, Cuota>
     */
    public function prestamo(): BelongsTo
    {
        return $this->belongsTo(Prestamo::class, 'prestamo_id');
    }

    /**
     * @return HasMany<Pago>
     */
    public function pagos(): HasMany
    {
        return $this->hasMany(Pago::class, 'cuota_id');
    }
}
