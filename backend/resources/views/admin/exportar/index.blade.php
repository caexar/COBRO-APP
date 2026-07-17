@extends('admin.layout')

@section('titulo', 'Exportar reporte')

@section('contenido')
    <div class="max-w-2xl bg-white rounded-lg shadow p-6">
        <p class="text-sm text-gray-500 mb-4">
            El rango de fechas filtra el historial de pagos por fecha de pago; si lo dejas vacío, se exporta todo.
        </p>

        @if ($errors->any())
            <div class="mb-4 rounded-md bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700">
                <ul class="list-disc list-inside">
                    @foreach ($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </div>
        @endif

        <form method="POST" action="{{ route('admin.exportar.descargar') }}" class="space-y-5">
            @csrf

            <div class="grid grid-cols-2 gap-4">
                <div>
                    <label class="block text-sm font-medium text-gray-700">Desde (opcional)</label>
                    <input type="date" name="desde" value="{{ old('desde') }}" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700">Hasta (opcional)</label>
                    <input type="date" name="hasta" value="{{ old('hasta') }}" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                </div>
            </div>

            <div>
                <div class="flex items-center justify-between mb-2">
                    <label class="block text-sm font-medium text-gray-700">Cobradores</label>
                    <label class="text-sm text-indigo-600">
                        <input type="checkbox" onclick="document.querySelectorAll('.cobrador-checkbox').forEach(c => c.checked = this.checked)" checked>
                        Seleccionar todos
                    </label>
                </div>
                <div class="border rounded-md divide-y max-h-64 overflow-y-auto">
                    @forelse ($cobradores as $cobrador)
                        <label class="flex items-center gap-3 px-3 py-2 text-sm">
                            <input type="checkbox" class="cobrador-checkbox" name="usuario_ids[]" value="{{ $cobrador->id }}" checked>
                            {{ $cobrador->nombre }}
                            <span class="text-gray-400">({{ $cobrador->email }})</span>
                        </label>
                    @empty
                        <p class="px-3 py-2 text-sm text-gray-500">No hay cobradores registrados.</p>
                    @endforelse
                </div>
            </div>

            <button type="submit" class="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700">
                Exportar CSV
            </button>
        </form>
    </div>
@endsection
