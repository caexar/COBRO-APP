<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreCierreCajaRequest extends FormRequest
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
            'fecha' => ['required', 'date'],
            'capital_inicio' => ['required', 'numeric', 'min:0'],
            'capital_cierre' => ['required', 'numeric', 'min:0'],
            'justificacion_diferencia' => ['nullable', 'string', 'max:1000'],
            'gastos' => ['nullable', 'array'],
            'gastos.*.monto' => ['required_with:gastos', 'numeric', 'min:0.01'],
            'gastos.*.detalle' => ['required_with:gastos', 'string', 'max:255'],
        ];
    }
}
