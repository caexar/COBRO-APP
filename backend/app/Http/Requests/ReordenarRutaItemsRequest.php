<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Mismo contrato que ReordenarRutasRequest (`ids` en el orden final deseado), pero acotado a
 * los ítems de la ruta de la URL — un id de otra ruta (aunque sea del mismo cobrador) no pasa
 * la validación `exists`.
 */
class ReordenarRutaItemsRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('update', $this->route('ruta'));
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $rutaId = $this->route('ruta')->id;

        return [
            'ids' => ['required', 'array', 'min:1'],
            'ids.*' => [
                'required', 'integer', 'distinct',
                Rule::exists('ruta_items', 'id')->where(fn ($query) => $query->where('ruta_id', $rutaId)),
            ],
        ];
    }
}
