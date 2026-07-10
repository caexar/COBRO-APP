<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateUsuarioRequest extends FormRequest
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
        $usuarioId = $this->route('usuario')->id;

        return [
            'nombre' => ['sometimes', 'required', 'string', 'max:255'],
            'email' => ['sometimes', 'required', 'email', Rule::unique('users', 'email')->ignore($usuarioId)],
            'password' => ['sometimes', 'required', 'string', 'min:8'],
            'rol' => ['sometimes', 'required', 'in:admin,cobrador'],
            'pin' => ['sometimes', 'required', 'string', 'min:4', 'max:10'],
            'pin_maestro' => ['sometimes', 'nullable', 'string', 'min:4', 'max:10'],
        ];
    }
}
