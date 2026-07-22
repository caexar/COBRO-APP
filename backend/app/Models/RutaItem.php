<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'ruta_id',
    'prestamo_id',
    'orden',
    'estado',
    'cobrado_en',
    'uuid_local',
])]
class RutaItem extends Model
{
    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'cobrado_en' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<Ruta, RutaItem>
     */
    public function ruta(): BelongsTo
    {
        return $this->belongsTo(Ruta::class, 'ruta_id');
    }

    /**
     * @return BelongsTo<Prestamo, RutaItem>
     */
    public function prestamo(): BelongsTo
    {
        return $this->belongsTo(Prestamo::class, 'prestamo_id');
    }
}
