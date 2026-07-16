<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable([
    'usuario_id',
    'nombre',
    'cedula',
    'telefono',
    'direccion',
    'referencia',
    'foto_url',
    'uuid_local',
])]
class Cliente extends Model
{
    use SoftDeletes;

    /**
     * @return BelongsTo<User, Cliente>
     */
    public function usuario(): BelongsTo
    {
        return $this->belongsTo(User::class, 'usuario_id');
    }

    /**
     * @return HasMany<Prestamo>
     */
    public function prestamos(): HasMany
    {
        return $this->hasMany(Prestamo::class, 'cliente_id');
    }
}
