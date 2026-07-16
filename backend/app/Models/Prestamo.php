<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable([
    'cliente_id',
    'referencia',
    'usuario_id',
    'monto_capital',
    'porcentaje_interes',
    'frecuencia_pago',
    'dias_personalizado',
    'plazo_cuotas',
    'fecha_inicio',
    'estado',
    'politica_mora',
    'uuid_local',
])]
class Prestamo extends Model
{
    use SoftDeletes;

    /**
     * Sin esto, `monto_total` no aparecería en `toArray()`/`toJson()` (los accessors de
     * Eloquent son opt-in para serialización) pese a que sí es accesible como
     * `$prestamo->monto_total` en PHP.
     *
     * @var list<string>
     */
    protected $appends = ['monto_total'];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'monto_capital' => 'decimal:2',
            'porcentaje_interes' => 'decimal:2',
            'fecha_inicio' => 'date',
        ];
    }

    /**
     * @return BelongsTo<Cliente, Prestamo>
     */
    public function cliente(): BelongsTo
    {
        return $this->belongsTo(Cliente::class, 'cliente_id');
    }

    /**
     * @return BelongsTo<User, Prestamo>
     */
    public function usuario(): BelongsTo
    {
        return $this->belongsTo(User::class, 'usuario_id');
    }

    /**
     * @return HasMany<PrestamoExtra>
     */
    public function extras(): HasMany
    {
        return $this->hasMany(PrestamoExtra::class, 'prestamo_id');
    }

    /**
     * @return HasMany<Cuota>
     */
    public function cuotas(): HasMany
    {
        return $this->hasMany(Cuota::class, 'prestamo_id');
    }

    /**
     * @return HasMany<Pago>
     */
    public function pagos(): HasMany
    {
        return $this->hasMany(Pago::class, 'prestamo_id');
    }

    /**
     * Monto total a pagar del préstamo: capital + interés + extras. No se persiste como
     * columna; se deriva de monto_capital, porcentaje_interes y los extras — accesible como
     * `$prestamo->monto_total` (y serializado automáticamente, ver `$appends` arriba).
     */
    protected function montoTotal(): Attribute
    {
        return Attribute::make(
            get: function () {
                $capital = (float) $this->monto_capital;
                $interes = round($capital * ((float) $this->porcentaje_interes / 100), 2);
                $extras = round($this->extras()->sum('valor'), 2);

                return round($capital + $interes + $extras, 2);
            },
        );
    }
}
