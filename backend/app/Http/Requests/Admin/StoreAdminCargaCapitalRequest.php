<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreAdminCargaCapitalRequest extends FormRequest
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
            'usuario_id' => [
                'required', 'integer',
                Rule::exists('users', 'id')->where(fn ($query) => $query->where('rol', 'cobrador')),
            ],
            'tipo' => ['required', 'in:carga,retiro'],
            'monto' => ['required', 'numeric', 'min:0.01'],
            // Solo tiene sentido para un retiro (clasifica en qué se fue el dinero); para una
            // carga se excluye de los datos validados sin importar lo que mande el cliente, así
            // el registro siempre queda con categoria = null.
            'categoria' => [
                Rule::excludeIf(fn () => $this->input('tipo') !== 'retiro'),
                'required', 'in:gasto_operativo,decision_jefe,salario,otro',
            ],
            'descripcion' => ['nullable', 'string', 'max:255'],
        ];
    }
}
