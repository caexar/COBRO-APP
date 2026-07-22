<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * `ids`: los ids de TODAS las rutas del cobrador en el nuevo orden deseado (posición en el
 * array = nuevo `orden`, 0-indexado) — el mismo contrato simple que usa el drag-and-drop de la
 * app: solo manda la lista final, no pares {id, orden}.
 */
class ReordenarRutasRequest extends FormRequest
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
        $usuarioId = $this->user()->id;

        return [
            'ids' => ['required', 'array', 'min:1'],
            'ids.*' => [
                'required', 'integer', 'distinct',
                Rule::exists('rutas', 'id')->where(fn ($query) => $query->where('usuario_id', $usuarioId)),
            ],
        ];
    }
}
