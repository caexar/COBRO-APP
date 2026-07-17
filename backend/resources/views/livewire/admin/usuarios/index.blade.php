<div class="space-y-4">
    <div class="flex items-center justify-between">
        <p class="text-sm text-gray-500">{{ $usuarios->count() }} usuario(s) registrados.</p>
        <a href="{{ route('admin.usuarios.crear') }}" wire:navigate
           class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700">
            Nuevo usuario
        </a>
    </div>

    @if ($mensaje)
        <div class="rounded-md bg-green-50 border border-green-200 px-4 py-3 text-sm text-green-700">{{ $mensaje }}</div>
    @endif
    @if ($error)
        <div class="rounded-md bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700">{{ $error }}</div>
    @endif

    <div class="bg-white rounded-lg shadow overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
                <tr>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Nombre</th>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Email</th>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Rol</th>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Estado</th>
                    <th class="px-4 py-3"></th>
                </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
                @foreach ($usuarios as $usuario)
                    <tr wire:key="usuario-{{ $usuario->id }}">
                        <td class="px-4 py-3 text-sm">{{ $usuario->nombre }}</td>
                        <td class="px-4 py-3 text-sm text-gray-500">{{ $usuario->email }}</td>
                        <td class="px-4 py-3 text-sm capitalize">{{ $usuario->rol }}</td>
                        <td class="px-4 py-3 text-sm">
                            <span class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium {{ $usuario->activo ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-600' }}">
                                {{ $usuario->activo ? 'Activo' : 'Inactivo' }}
                            </span>
                        </td>
                        <td class="px-4 py-3 text-right text-sm space-x-3 whitespace-nowrap">
                            <a href="{{ route('admin.usuarios.editar', $usuario) }}" wire:navigate class="text-indigo-600 hover:underline">Editar</a>
                            @if ($usuario->activo)
                                <button type="button" wire:click="desactivar({{ $usuario->id }})"
                                        wire:confirm="¿Desactivar a {{ $usuario->nombre }}?"
                                        class="text-red-600 hover:underline">
                                    Desactivar
                                </button>
                            @else
                                <button type="button" wire:click="activar({{ $usuario->id }})" class="text-green-600 hover:underline">
                                    Reactivar
                                </button>
                            @endif
                        </td>
                    </tr>
                @endforeach
            </tbody>
        </table>
    </div>
</div>
