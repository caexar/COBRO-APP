<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StorePagoRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->isCobrador();
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $usuarioId = $this->user()->id;

        return [
            'prestamo_id' => [
                'required', 'integer',
                Rule::exists('prestamos', 'id')->where(
                    fn ($query) => $query->where('usuario_id', $usuarioId)->whereNull('deleted_at')
                ),
            ],
            'monto_abonado' => ['required', 'numeric', 'min:0.01'],
            'fecha_pago' => ['required', 'date'],
            'manejo_excedente' => ['nullable', 'in:abono_deuda,cobro_extra'],
        ];
    }
}
