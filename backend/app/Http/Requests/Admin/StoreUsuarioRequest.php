<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreUsuarioRequest extends FormRequest
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
            'nombre' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', Rule::unique('users', 'email')],
            'password' => ['required', 'string', 'min:8'],
            'rol' => ['required', 'in:admin,cobrador'],
            'pin' => ['nullable', 'string', 'min:4', 'max:10'],
            'pin_maestro' => ['nullable', 'string', 'min:4', 'max:10'],
        ];
    }
}
