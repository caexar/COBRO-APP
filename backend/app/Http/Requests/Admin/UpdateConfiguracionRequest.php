<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;

class UpdateConfiguracionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->isAdmin();
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'tasas_interes_default' => ['sometimes', 'array'],
            'tasas_interes_default.*' => ['numeric', 'min:0'],
            'politica_mora_default' => ['sometimes', 'in:mantener,siguiente_pago,sumar_total'],
            'pin_maestro' => ['sometimes', 'nullable', 'string', 'min:4', 'max:10'],
            'intentos_pin_antes_de_maestro' => ['sometimes', 'integer', 'min:1', 'max:10'],
        ];
    }
}
