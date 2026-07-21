<?php

namespace App\Http\Controllers\Api\Admin;

use App\Exceptions\UsuarioAdminException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\StoreUsuarioRequest;
use App\Http\Requests\Admin\UpdateUsuarioRequest;
use App\Models\User;
use App\Services\UsuarioAdminService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminUsuarioController extends Controller
{
    public function __construct(
        private readonly UsuarioAdminService $usuarioAdminService,
    ) {}

    public function index(): JsonResponse
    {
        return response()->json([
            'data' => User::where('rol', 'cobrador')->orderBy('nombre')->get(),
        ]);
    }

    public function store(StoreUsuarioRequest $request): JsonResponse
    {
        $usuario = $this->usuarioAdminService->crear($request->validated(), $request->user());

        return response()->json(['data' => $usuario], 201);
    }

    public function update(UpdateUsuarioRequest $request, User $usuario): JsonResponse
    {
        $usuario = $this->usuarioAdminService->actualizar($usuario, $request->validated(), $request->user());

        return response()->json(['data' => $usuario]);
    }

    public function desactivar(Request $request, User $usuario): JsonResponse
    {
        try {
            $usuario = $this->usuarioAdminService->desactivar($usuario, $request->user());
        } catch (UsuarioAdminException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json(['data' => $usuario]);
    }

    public function reactivar(Request $request, User $usuario): JsonResponse
    {
        try {
            $usuario = $this->usuarioAdminService->reactivar($usuario, $request->user());
        } catch (UsuarioAdminException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json(['data' => $usuario]);
    }

    public function detalle(User $usuario): JsonResponse
    {
        if ($usuario->rol !== 'cobrador') {
            return response()->json(['message' => 'El usuario indicado no es un cobrador.'], 404);
        }

        $usuario->load([
            'clientes' => fn ($query) => $query->orderBy('nombre'),
            'prestamos' => fn ($query) => $query->with(['cliente', 'extras', 'cuotas', 'pagos'])->latest('fecha_inicio'),
            'cargasCapital' => fn ($query) => $query->orderByDesc('created_at'),
            'cierresCaja' => fn ($query) => $query->with('gastos')->orderByDesc('fecha'),
        ]);

        return response()->json(['data' => $usuario]);
    }
}
