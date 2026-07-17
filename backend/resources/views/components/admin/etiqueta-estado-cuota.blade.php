@props(['estado'])

@php
    $estilos = match ($estado) {
        'pagada' => 'bg-green-100 text-green-800',
        'en_mora' => 'bg-red-100 text-red-800',
        default => 'bg-gray-200 text-gray-600',
    };
    $texto = match ($estado) {
        'pagada' => 'Pagada',
        'en_mora' => 'En mora',
        default => 'Pendiente',
    };
@endphp

<span class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium shrink-0 {{ $estilos }}">{{ $texto }}</span>
