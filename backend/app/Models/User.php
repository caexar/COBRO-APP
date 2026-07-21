<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

#[Fillable(['nombre', 'email', 'password', 'rol', 'pin_hash', 'pin_maestro_hash', 'activo'])]
#[Hidden(['password', 'pin_hash', 'pin_maestro_hash', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable, SoftDeletes;

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'password' => 'hashed',
            'activo' => 'boolean',
        ];
    }

    /**
     * @return HasMany<Cliente>
     */
    public function clientes(): HasMany
    {
        return $this->hasMany(Cliente::class, 'usuario_id');
    }

    /**
     * @return HasMany<Prestamo>
     */
    public function prestamos(): HasMany
    {
        return $this->hasMany(Prestamo::class, 'usuario_id');
    }

    /**
     * @return HasMany<Auditoria>
     */
    public function auditorias(): HasMany
    {
        return $this->hasMany(Auditoria::class, 'usuario_id');
    }

    /**
     * @return HasMany<CargaCapital>
     */
    public function cargasCapital(): HasMany
    {
        return $this->hasMany(CargaCapital::class, 'usuario_id');
    }

    /**
     * @return HasMany<CierreCaja>
     */
    public function cierresCaja(): HasMany
    {
        return $this->hasMany(CierreCaja::class, 'usuario_id');
    }

    public function isAdmin(): bool
    {
        return $this->rol === 'admin';
    }

    public function isCobrador(): bool
    {
        return $this->rol === 'cobrador';
    }
}
