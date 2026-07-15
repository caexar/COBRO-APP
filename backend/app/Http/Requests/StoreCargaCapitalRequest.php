<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreCargaCapitalRequest extends FormRequest
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
            'monto' => ['required', 'numeric', 'min:0.01'],
            'descripcion' => ['nullable', 'string', 'max:255'],
        ];
    }
}
