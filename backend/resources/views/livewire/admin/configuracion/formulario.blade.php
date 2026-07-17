<div class="max-w-2xl space-y-6">
    @if ($mensaje)
        <div class="rounded-md bg-green-50 border border-green-200 px-4 py-3 text-sm text-green-700">{{ $mensaje }}</div>
    @endif

    <form wire:submit="guardar" class="space-y-6">
        <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-sm font-medium text-gray-500 mb-3">Tasas de interés sugeridas</h3>
            <p class="text-xs text-gray-500 mb-3">Solo informativas: no se validan los préstamos contra esta lista.</p>

            <div class="space-y-2">
                @foreach ($tasas as $indice => $tasa)
                    <div class="flex items-center gap-2">
                        <input type="number" step="0.01" min="0" wire:model="tasas.{{ $indice }}"
                               class="block w-32 rounded-md border-gray-300 shadow-sm">
                        <span class="text-sm text-gray-500">%</span>
                        <button type="button" wire:click="quitarTasa({{ $indice }})" class="text-sm text-red-600 hover:underline">
                            Quitar
                        </button>
                    </div>
                    @error("tasas.{$indice}") <p class="text-sm text-red-600">{{ $message }}</p> @enderror
                @endforeach
            </div>

            <button type="button" wire:click="agregarTasa" class="mt-3 text-sm text-indigo-600 hover:underline">
                + Agregar tasa
            </button>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-sm font-medium text-gray-500 mb-3">Préstamos</h3>

            <div class="space-y-4">
                <div>
                    <label class="block text-sm font-medium text-gray-700">Política de mora por defecto</label>
                    <select wire:model="politicaMoraDefault" class="mt-1 block w-full max-w-xs rounded-md border-gray-300 shadow-sm">
                        <option value="mantener">Mantener</option>
                        <option value="siguiente_pago">Sumar al siguiente pago</option>
                        <option value="sumar_total">Repartir entre el resto de cuotas</option>
                    </select>
                    @error('politicaMoraDefault') <p class="mt-1 text-sm text-red-600">{{ $message }}</p> @enderror
                </div>

                <div>
                    <label class="block text-sm font-medium text-gray-700">Intentos de PIN antes de ofrecer el PIN maestro</label>
                    <input type="number" min="1" max="10" wire:model="intentosPinAntesDeMaestro"
                           class="mt-1 block w-24 rounded-md border-gray-300 shadow-sm">
                    @error('intentosPinAntesDeMaestro') <p class="mt-1 text-sm text-red-600">{{ $message }}</p> @enderror
                </div>
            </div>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-sm font-medium text-gray-500 mb-1">PIN maestro global</h3>
            <p class="text-sm mb-4">
                Estado:
                <span class="font-medium {{ $pinMaestroConfigurado ? 'text-green-700' : 'text-gray-500' }}">
                    {{ $pinMaestroConfigurado ? 'Configurado' : 'No configurado' }}
                </span>
            </p>

            <div class="space-y-3">
                <div>
                    <label class="block text-sm font-medium text-gray-700">Nuevo PIN maestro (4 a 10 dígitos)</label>
                    <input type="password" wire:model="nuevoPinMaestro" maxlength="10"
                           wire:dirty.class="border-indigo-400"
                           @if ($quitarPinMaestro) disabled @endif
                           class="mt-1 block w-48 rounded-md border-gray-300 shadow-sm disabled:bg-gray-100">
                    @error('nuevoPinMaestro') <p class="mt-1 text-sm text-red-600">{{ $message }}</p> @enderror
                    <p class="mt-1 text-xs text-gray-500">Dejar en blanco para no cambiarlo.</p>
                </div>

                <label class="flex items-center gap-2 text-sm text-gray-700">
                    <input type="checkbox" wire:model="quitarPinMaestro">
                    Quitar el PIN maestro actual
                </label>
            </div>
        </div>

        <button type="submit" class="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700">
            Guardar configuración
        </button>
    </form>
</div>
