@props(['etiqueta', 'valor', 'resaltar' => false])

<div class="bg-white rounded-lg shadow p-4">
    <p class="text-xs font-medium text-gray-500">{{ $etiqueta }}</p>
    <p class="mt-1 text-lg font-semibold {{ $resaltar && $valor > 0 ? 'text-red-600' : 'text-gray-900' }}">
        {{ \App\Support\Dinero::formatear($valor) }}
    </p>
</div>
