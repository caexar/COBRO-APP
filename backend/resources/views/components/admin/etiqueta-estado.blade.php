@props(['estado'])

@php
    $estilos = match ($estado) {
        'pagado' => 'bg-green-100 text-green-800',
        'en_mora' => 'bg-red-100 text-red-800',
        'anulado' => 'bg-gray-200 text-gray-600',
        default => 'bg-blue-100 text-blue-800',
    };
    $texto = match ($estado) {
        'pagado' => 'Pagado',
        'en_mora' => 'En mora',
        'anulado' => 'Anulado',
        default => 'Activo',
    };
@endphp

<span class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium shrink-0 {{ $estilos }}">{{ $texto }}</span>
