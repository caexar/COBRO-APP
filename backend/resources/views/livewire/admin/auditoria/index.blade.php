<div class="space-y-4">
    <div class="bg-white rounded-lg shadow p-4 flex flex-wrap items-end gap-4">
        <div>
            <label class="block text-sm font-medium text-gray-700">Acción</label>
            <select wire:model.live="accion" class="mt-1 rounded-md border-gray-300 shadow-sm">
                <option value="">Todas</option>
                @foreach ($acciones as $opcion)
                    <option value="{{ $opcion }}">{{ $opcion }}</option>
                @endforeach
            </select>
        </div>
        <div>
            <label class="block text-sm font-medium text-gray-700">Desde</label>
            <input type="date" wire:model.live="desde" class="mt-1 rounded-md border-gray-300 shadow-sm">
        </div>
        <div>
            <label class="block text-sm font-medium text-gray-700">Hasta</label>
            <input type="date" wire:model.live="hasta" class="mt-1 rounded-md border-gray-300 shadow-sm">
        </div>
    </div>

    <div class="bg-white rounded-lg shadow overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
                <tr>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Fecha</th>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Usuario</th>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Acción</th>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Entidad</th>
                    <th class="px-4 py-3"></th>
                </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
                @forelse ($registros as $registro)
                    <tr x-data="{ open: false }">
                        <td class="px-4 py-3 text-sm whitespace-nowrap">{{ $registro->created_at->format('d/m/Y H:i') }}</td>
                        <td class="px-4 py-3 text-sm">{{ $registro->usuario?->nombre ?? "Usuario #{$registro->usuario_id}" }}</td>
                        <td class="px-4 py-3 text-sm">{{ $registro->accion }}</td>
                        <td class="px-4 py-3 text-sm">{{ $registro->entidad }} #{{ $registro->entidad_id }}</td>
                        <td class="px-4 py-3 text-sm text-right">
                            <button type="button" @click="open = !open" class="text-indigo-600 hover:underline">
                                Detalle
                            </button>
                        </td>
                    </tr>
                    <tr x-show="open" x-cloak>
                        <td colspan="5" class="px-4 pb-4 bg-gray-50 text-xs">
                            <div class="grid grid-cols-2 gap-4">
                                <div>
                                    <p class="font-medium text-gray-500 mb-1">Datos anteriores</p>
                                    <pre class="whitespace-pre-wrap break-all bg-white border rounded p-2">{{ json_encode(\App\Support\AuditoriaPresentador::datosSeguros($registro->datos_anteriores), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) }}</pre>
                                </div>
                                <div>
                                    <p class="font-medium text-gray-500 mb-1">Datos nuevos</p>
                                    <pre class="whitespace-pre-wrap break-all bg-white border rounded p-2">{{ json_encode(\App\Support\AuditoriaPresentador::datosSeguros($registro->datos_nuevos), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) }}</pre>
                                </div>
                            </div>
                        </td>
                    </tr>
                @empty
                    <tr>
                        <td colspan="5" class="px-4 py-6 text-center text-gray-500">No hay registros de auditoría.</td>
                    </tr>
                @endforelse
            </tbody>
        </table>
    </div>

    <div>{{ $registros->links() }}</div>
</div>
