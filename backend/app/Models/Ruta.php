<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable([
    'usuario_id',
    'nombre',
    'descripcion',
    'fecha',
    'orden',
    'uuid_local',
])]
class Ruta extends Model
{
    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'fecha' => 'date',
        ];
    }

    /**
     * @return BelongsTo<User, Ruta>
     */
    public function usuario(): BelongsTo
    {
        return $this->belongsTo(User::class, 'usuario_id');
    }

    /**
     * @return HasMany<RutaItem>
     */
    public function items(): HasMany
    {
        return $this->hasMany(RutaItem::class, 'ruta_id')->orderBy('orden');
    }
}
