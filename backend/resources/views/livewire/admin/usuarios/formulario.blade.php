<div class="max-w-xl bg-white rounded-lg shadow p-6">
    @if ($error)
        <div class="mb-4 rounded-md bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700">{{ $error }}</div>
    @endif

    <form wire:submit="guardar" class="space-y-4">
        <div>
            <label class="block text-sm font-medium text-gray-700">Nombre</label>
            <input type="text" wire:model="nombre" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
            @error('nombre') <p class="mt-1 text-sm text-red-600">{{ $message }}</p> @enderror
        </div>

        <div>
            <label class="block text-sm font-medium text-gray-700">Email</label>
            <input type="email" wire:model="email" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
            @error('email') <p class="mt-1 text-sm text-red-600">{{ $message }}</p> @enderror
        </div>

        <div>
            <label class="block text-sm font-medium text-gray-700">
                Contraseña
                @if ($usuario)
                    <span class="text-gray-400 font-normal">(dejar en blanco para no cambiarla)</span>
                @endif
            </label>
            <input type="password" wire:model="password" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
            @error('password') <p class="mt-1 text-sm text-red-600">{{ $message }}</p> @enderror
        </div>

        <div>
            <label class="block text-sm font-medium text-gray-700">Rol</label>
            <select wire:model="rol" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                <option value="cobrador">Cobrador</option>
                <option value="admin">Admin</option>
            </select>
            @error('rol') <p class="mt-1 text-sm text-red-600">{{ $message }}</p> @enderror
        </div>

        <div>
            <label class="block text-sm font-medium text-gray-700">
                PIN
                @if ($usuario)
                    <span class="text-gray-400 font-normal">(dejar en blanco para no cambiarlo)</span>
                @else
                    <span class="text-gray-400 font-normal">(opcional, "0000" por defecto)</span>
                @endif
            </label>
            <input type="text" wire:model="pin" maxlength="10" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
            @error('pin') <p class="mt-1 text-sm text-red-600">{{ $message }}</p> @enderror
        </div>

        <div class="flex items-center gap-3 pt-2">
            <button type="submit" class="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700">
                {{ $usuario ? 'Guardar cambios' : 'Crear usuario' }}
            </button>
            <a href="{{ route('admin.usuarios.index') }}" wire:navigate class="text-sm text-gray-500 hover:underline">Cancelar</a>
        </div>
    </form>
</div>
