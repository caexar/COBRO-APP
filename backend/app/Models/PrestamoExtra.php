<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['prestamo_id', 'concepto', 'valor'])]
class PrestamoExtra extends Model
{
    protected $table = 'prestamos_extras';

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'valor' => 'decimal:2',
        ];
    }

    /**
     * @return BelongsTo<Prestamo, PrestamoExtra>
     */
    public function prestamo(): BelongsTo
    {
        return $this->belongsTo(Prestamo::class, 'prestamo_id');
    }
}
