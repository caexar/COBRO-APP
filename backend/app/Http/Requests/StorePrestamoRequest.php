<?php

namespace App\Http\Requests;

use App\Models\Prestamo;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StorePrestamoRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', Prestamo::class);
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $usuarioId = $this->user()->id;

        return [
            'cliente_id' => [
                'required', 'integer',
                Rule::exists('clientes', 'id')->where(
                    fn ($query) => $query->where('usuario_id', $usuarioId)->whereNull('deleted_at')
                ),
            ],
            'referencia' => ['nullable', 'string', 'max:255'],
            'monto_capital' => ['required', 'numeric', 'min:0.01'],
            'porcentaje_interes' => ['required', 'numeric', 'min:0'],
            'extras' => ['nullable', 'array'],
            'extras.*.concepto' => ['required_with:extras', 'string', 'max:255'],
            'extras.*.valor' => ['required_with:extras', 'numeric', 'min:0'],
            'frecuencia_pago' => ['required', 'in:diario,semanal,mensual,personalizado'],
            'dias_personalizado' => ['required_if:frecuencia_pago,personalizado', 'integer', 'min:1'],
            'plazo_cuotas' => ['required', 'integer', 'min:1'],
            'fecha_inicio' => ['required', 'date'],
            'politica_mora' => ['nullable', 'in:mantener,siguiente_pago,sumar_total'],
        ];
    }
}
