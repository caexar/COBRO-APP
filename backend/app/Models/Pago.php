<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable([
    'prestamo_id',
    'cuota_id',
    'monto_abonado',
    'monto_aplicado',
    'fecha_pago',
    'dias_mora',
    'saldo_restante_despues',
])]
class Pago extends Model
{
    use SoftDeletes;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'monto_abonado' => 'decimal:2',
            'monto_aplicado' => 'decimal:2',
            'fecha_pago' => 'date',
            'saldo_restante_despues' => 'decimal:2',
        ];
    }

    /**
     * @return BelongsTo<Prestamo, Pago>
     */
    public function prestamo(): BelongsTo
    {
        return $this->belongsTo(Prestamo::class, 'prestamo_id');
    }

    /**
     * @return BelongsTo<Cuota, Pago>
     */
    public function cuota(): BelongsTo
    {
        return $this->belongsTo(Cuota::class, 'cuota_id');
    }
}
