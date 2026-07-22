<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreRutaItemRequest extends FormRequest
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
        $usuarioId = $this->user()->id;

        return [
            'prestamo_id' => [
                'required', 'integer',
                Rule::exists('prestamos', 'id')->where(fn ($query) => $query->where('usuario_id', $usuarioId)),
            ],
        ];
    }
}
