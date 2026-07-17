<div class="space-y-6">
    <div>
        <h2 class="text-sm font-medium text-gray-500 mb-3">Totales globales</h2>
        <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
            <x-admin.tarjeta-metrica etiqueta="Capital prestado" :valor="$global['capital_prestado']" />
            <x-admin.tarjeta-metrica etiqueta="Total cobrado" :valor="$global['total_cobrado']" />
            <x-admin.tarjeta-metrica etiqueta="Cartera en mora" :valor="$global['cartera_en_mora']" resaltar />
            <x-admin.tarjeta-metrica etiqueta="Ganancia interés" :valor="$global['ganancia_interes']" />
            <x-admin.tarjeta-metrica etiqueta="Ganancia extra" :valor="$global['ganancia_extra']" />
            <x-admin.tarjeta-metrica etiqueta="Saldo disponible" :valor="$global['saldo_disponible']" />
        </div>
    </div>

    <div>
        <h2 class="text-sm font-medium text-gray-500 mb-3">Por cobrador</h2>

        @if (empty($porCobrador))
            <div class="bg-white rounded-lg shadow p-8 text-center text-gray-500">
                No hay cobradores registrados.
            </div>
        @else
            <div class="bg-white rounded-lg shadow overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200">
                    <thead class="bg-gray-50">
                        <tr>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Cobrador</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Estado</th>
                            <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Capital prestado</th>
                            <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Total cobrado</th>
                            <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Cartera en mora</th>
                            <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Ganancia interés</th>
                            <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Ganancia extra</th>
                            <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Saldo disponible</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-200">
                        @foreach ($porCobrador as $fila)
                            <tr wire:key="cobrador-{{ $fila['usuario_id'] }}"
                                class="cursor-pointer hover:bg-gray-50"
                                onclick="window.location='{{ route('admin.resumen.detalle', $fila['usuario_id']) }}'">
                                <td class="px-4 py-3 text-sm font-medium text-indigo-600">{{ $fila['nombre'] }}</td>
                                <td class="px-4 py-3 text-sm">
                                    <span class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium {{ $fila['activo'] ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-600' }}">
                                        {{ $fila['activo'] ? 'Activo' : 'Inactivo' }}
                                    </span>
                                </td>
                                <td class="px-4 py-3 text-sm text-right">{{ \App\Support\Dinero::formatear($fila['capital_prestado']) }}</td>
                                <td class="px-4 py-3 text-sm text-right">{{ \App\Support\Dinero::formatear($fila['total_cobrado']) }}</td>
                                <td class="px-4 py-3 text-sm text-right {{ $fila['cartera_en_mora'] > 0 ? 'text-red-600 font-medium' : '' }}">
                                    {{ \App\Support\Dinero::formatear($fila['cartera_en_mora']) }}
                                </td>
                                <td class="px-4 py-3 text-sm text-right">{{ \App\Support\Dinero::formatear($fila['ganancia_interes']) }}</td>
                                <td class="px-4 py-3 text-sm text-right">{{ \App\Support\Dinero::formatear($fila['ganancia_extra']) }}</td>
                                <td class="px-4 py-3 text-sm text-right">{{ \App\Support\Dinero::formatear($fila['saldo_disponible']) }}</td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        @endif
    </div>
</div>
