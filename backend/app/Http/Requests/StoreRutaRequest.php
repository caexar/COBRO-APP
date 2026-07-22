<?php

namespace App\Http\Requests;

use App\Models\Ruta;
use Illuminate\Foundation\Http\FormRequest;

class StoreRutaRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', Ruta::class);
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'nombre' => ['required', 'string', 'max:255'],
            'descripcion' => ['nullable', 'string', 'max:1000'],
            'fecha' => ['nullable', 'date'],
        ];
    }
}
