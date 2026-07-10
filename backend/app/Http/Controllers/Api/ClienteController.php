<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreClienteRequest;
use App\Http\Requests\UpdateClienteRequest;
use App\Models\Cliente;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ClienteController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $this->authorize('viewAny', Cliente::class);

        $query = Cliente::where('usuario_id', $request->user()->id);
        $termino = $request->query('q');

        if (filled($termino)) {
            $clientes = (clone $query)->where('nombre', 'like', "%{$termino}%")->orderBy('nombre')->get();

            if ($clientes->isEmpty()) {
                $clientes = (clone $query)->where('cedula', 'like', "%{$termino}%")->orderBy('nombre')->get();
            }
        } else {
            $clientes = $query->orderBy('nombre')->get();
        }

        return response()->json(['data' => $clientes]);
    }

    public function store(StoreClienteRequest $request): JsonResponse
    {
        $cliente = Cliente::create([
            ...$request->validated(),
            'usuario_id' => $request->user()->id,
        ]);

        return response()->json(['data' => $cliente], 201);
    }

    public function update(UpdateClienteRequest $request, Cliente $cliente): JsonResponse
    {
        $cliente->update($request->validated());

        return response()->json(['data' => $cliente]);
    }

    public function destroy(Cliente $cliente): JsonResponse
    {
        $this->authorize('delete', $cliente);

        $cliente->delete();

        return response()->json(['message' => 'Cliente eliminado correctamente.']);
    }
}
