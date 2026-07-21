<?php

namespace App\Http\Requests;

use App\Services\PrestamoCalculator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SimularPrestamoRequest extends FormRequest
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
        return [
            'monto_capital' => ['required', 'numeric', 'min:0.01'],
            'porcentaje_interes' => ['required', 'numeric', 'min:0'],
            'extras' => ['nullable', 'array'],
            'extras.*.concepto' => ['required_with:extras', 'string', 'max:255'],
            'extras.*.valor' => ['required_with:extras', 'numeric', 'min:0'],
            'frecuencia_pago' => ['required', Rule::in(PrestamoCalculator::FRECUENCIAS_VALIDAS)],
            'dias_personalizado' => ['required_if:frecuencia_pago,personalizado', 'integer', 'min:1'],
            'plazo_cuotas' => ['required', 'integer', 'min:1'],
            'fecha_inicio' => ['required', 'date'],
        ];
    }
}
