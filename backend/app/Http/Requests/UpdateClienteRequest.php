<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateClienteRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('update', $this->route('cliente'));
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $usuarioId = $this->user()->id;
        $clienteId = $this->route('cliente')->id;

        return [
            'nombre' => [
                'sometimes', 'required', 'string', 'max:255',
                Rule::unique('clientes')->where(fn ($query) => $query->where('usuario_id', $usuarioId))->ignore($clienteId),
            ],
            'cedula' => [
                'sometimes', 'required', 'string', 'max:50',
                Rule::unique('clientes')->where(fn ($query) => $query->where('usuario_id', $usuarioId))->ignore($clienteId),
            ],
            'telefono' => ['sometimes', 'required', 'string', 'max:30'],
            'direccion' => ['sometimes', 'required', 'string', 'max:255'],
            'referencia' => ['nullable', 'string', 'max:255'],
            'foto_url' => ['nullable', 'string', 'max:2048'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'nombre.unique' => 'Ya tienes registrado un cliente con este nombre.',
            'cedula.unique' => 'Ya tienes registrado un cliente con esta cédula.',
        ];
    }
}
