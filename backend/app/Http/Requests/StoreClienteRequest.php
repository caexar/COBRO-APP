<?php

namespace App\Http\Requests;

use App\Models\Cliente;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreClienteRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', Cliente::class);
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $usuarioId = $this->user()->id;

        return [
            'nombre' => [
                'required', 'string', 'max:255',
                Rule::unique('clientes')->where(fn ($query) => $query->where('usuario_id', $usuarioId)),
            ],
            'cedula' => [
                'required', 'string', 'max:50',
                Rule::unique('clientes')->where(fn ($query) => $query->where('usuario_id', $usuarioId)),
            ],
            'telefono' => ['required', 'string', 'max:30'],
            'direccion' => ['required', 'string', 'max:255'],
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
