<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\StoreUsuarioRequest;
use App\Http\Requests\Admin\UpdateUsuarioRequest;
use App\Models\User;
use App\Services\AuditoriaLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AdminUsuarioController extends Controller
{
    public function __construct(
        private readonly AuditoriaLogger $auditoria,
    ) {}

    public function index(): JsonResponse
    {
        return response()->json([
            'data' => User::where('rol', 'cobrador')->orderBy('nombre')->get(),
        ]);
    }

    public function store(StoreUsuarioRequest $request): JsonResponse
    {
        $datos = $request->validated();

        $usuario = User::create([
            'nombre' => $datos['nombre'],
            'email' => $datos['email'],
            'password' => $datos['password'],
            'rol' => $datos['rol'],
            'pin_hash' => Hash::make($datos['pin'] ?? '0000'),
            'pin_maestro_hash' => isset($datos['pin_maestro']) ? Hash::make($datos['pin_maestro']) : null,
            'activo' => true,
        ]);

        $this->auditoria->registrar(
            usuario: $request->user(),
            accion: 'crear_usuario',
            entidad: 'User',
            entidadId: $usuario->id,
            datosAnteriores: null,
            datosNuevos: ['nombre' => $usuario->nombre, 'email' => $usuario->email, 'rol' => $usuario->rol],
        );

        return response()->json(['data' => $usuario], 201);
    }

    public function update(UpdateUsuarioRequest $request, User $usuario): JsonResponse
    {
        $datos = $request->validated();
        $anterior = $usuario->only(['nombre', 'email', 'rol']);

        $cambios = collect($datos)->only(['nombre', 'email', 'rol', 'password'])->all();

        if (array_key_exists('pin', $datos)) {
            $cambios['pin_hash'] = Hash::make($datos['pin']);
        }

        if (array_key_exists('pin_maestro', $datos)) {
            $cambios['pin_maestro_hash'] = $datos['pin_maestro'] !== null ? Hash::make($datos['pin_maestro']) : null;
        }

        $usuario->update($cambios);

        $this->auditoria->registrar(
            usuario: $request->user(),
            accion: 'actualizar_usuario',
            entidad: 'User',
            entidadId: $usuario->id,
            datosAnteriores: $anterior,
            datosNuevos: $usuario->only(['nombre', 'email', 'rol']),
        );

        return response()->json(['data' => $usuario]);
    }

    public function desactivar(Request $request, User $usuario): JsonResponse
    {
        if ($usuario->id === $request->user()->id) {
            return response()->json(['message' => 'No puedes desactivar tu propio usuario.'], 422);
        }

        if (! $usuario->activo) {
            return response()->json(['message' => 'Este usuario ya está desactivado.'], 422);
        }

        $usuario->update(['activo' => false]);

        $this->auditoria->registrar(
            usuario: $request->user(),
            accion: 'desactivar_usuario',
            entidad: 'User',
            entidadId: $usuario->id,
            datosAnteriores: ['activo' => true],
            datosNuevos: ['activo' => false],
        );

        return response()->json(['data' => $usuario]);
    }

    public function reactivar(Request $request, User $usuario): JsonResponse
    {
        if ($usuario->activo) {
            return response()->json(['message' => 'Este usuario ya está activo.'], 422);
        }

        $usuario->update(['activo' => true]);

        $this->auditoria->registrar(
            usuario: $request->user(),
            accion: 'reactivar_usuario',
            entidad: 'User',
            entidadId: $usuario->id,
            datosAnteriores: ['activo' => false],
            datosNuevos: ['activo' => true],
        );

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
        ]);

        return response()->json(['data' => $usuario]);
    }
}
