<div class="space-y-6">
    <div class="flex items-center justify-between">
        <div>
            <a href="{{ route('admin.resumen') }}" wire:navigate class="text-sm text-indigo-600 hover:underline">&larr; Volver al resumen</a>
            <h2 class="text-lg font-semibold mt-1">{{ $usuario->nombre }}</h2>
            <p class="text-sm text-gray-500">{{ $usuario->email }}</p>
        </div>
        <span class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium {{ $usuario->activo ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-600' }}">
            {{ $usuario->activo ? 'Activo' : 'Inactivo' }}
        </span>
    </div>

    {{-- Asignar saldo --}}
    <div class="bg-white rounded-lg shadow p-6">
        <div class="flex items-center justify-between mb-4">
            <h3 class="text-sm font-medium text-gray-500">Asignar saldo</h3>
            <span class="text-sm text-gray-500">
                Saldo disponible: <strong class="text-gray-900">{{ \App\Support\Dinero::formatear($saldoDisponible) }}</strong>
            </span>
        </div>

        @if ($mensajeCapital)
            <div class="mb-4 rounded-md bg-green-50 border border-green-200 px-4 py-3 text-sm text-green-700">{{ $mensajeCapital }}</div>
        @endif
        @if ($errorCapital)
            <div class="mb-4 rounded-md bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700">{{ $errorCapital }}</div>
        @endif

        <form wire:submit="asignarSaldo" class="flex flex-wrap items-end gap-4">
            <div>
                <label class="block text-sm font-medium text-gray-700">Tipo</label>
                <select wire:model="tipoMovimiento" class="mt-1 rounded-md border-gray-300 shadow-sm">
                    <option value="carga">Carga</option>
                    <option value="retiro">Retiro</option>
                </select>
            </div>
            <div x-data="{
                    raw: $wire.entangle('monto'),
                    atajoMilesActivado: @js($atajoMilesActivado),
                    get display() {
                        return this.raw ? Number(this.raw).toLocaleString('en-US') : '';
                    },
                    get textoAyudaAtajoMiles() {
                        if (!this.atajoMilesActivado || !this.raw) return null;
                        return 'Se agregarán tres ceros: $ ' + (Number(this.raw) * 1000).toLocaleString('en-US').replaceAll(',', '.');
                    },
                    actualizar(valor) {
                        this.raw = valor.replace(/[^0-9]/g, '');
                    },
                 }">
                <label class="block text-sm font-medium text-gray-700">Monto</label>
                <input type="text" inputmode="numeric" :value="display" @input="actualizar($event.target.value)"
                       class="mt-1 rounded-md border-gray-300 shadow-sm">
                <p x-show="textoAyudaAtajoMiles" x-text="textoAyudaAtajoMiles" class="mt-1 text-xs text-gray-500"></p>
                @error('monto') <p class="mt-1 text-sm text-red-600">{{ $message }}</p> @enderror
            </div>
            <div x-show="$wire.tipoMovimiento === 'retiro'" x-cloak>
                <label class="block text-sm font-medium text-gray-700">Categoría</label>
                <select wire:model="categoria" class="mt-1 rounded-md border-gray-300 shadow-sm">
                    <option value="">Selecciona una categoría</option>
                    <option value="gasto_operativo">Gasto operativo</option>
                    <option value="decision_jefe">Decisión del jefe</option>
                    <option value="salario">Salario</option>
                    <option value="otro">Otro</option>
                </select>
                @error('categoria') <p class="mt-1 text-sm text-red-600">{{ $message }}</p> @enderror
            </div>
            <div class="flex-1 min-w-[200px]">
                <label class="block text-sm font-medium text-gray-700">Descripción (opcional)</label>
                <input type="text" wire:model="descripcion" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
            </div>
            <div>
                <button type="submit" class="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700">
                    Asignar
                </button>
            </div>
        </form>
    </div>

    {{-- Tabs --}}
    <div x-data="{ tab: 'prestamos' }" class="bg-white rounded-lg shadow overflow-hidden">
        <div class="border-b flex text-sm">
            <button type="button" @click="tab = 'prestamos'"
                    :class="tab === 'prestamos' ? 'border-indigo-600 text-indigo-600' : 'border-transparent text-gray-500 hover:text-gray-700'"
                    class="px-4 py-3 border-b-2 font-medium">
                Préstamos ({{ count($prestamos) }})
            </button>
            <button type="button" @click="tab = 'clientes'"
                    :class="tab === 'clientes' ? 'border-indigo-600 text-indigo-600' : 'border-transparent text-gray-500 hover:text-gray-700'"
                    class="px-4 py-3 border-b-2 font-medium">
                Clientes ({{ count($clientes) }})
            </button>
            <button type="button" @click="tab = 'capital'"
                    :class="tab === 'capital' ? 'border-indigo-600 text-indigo-600' : 'border-transparent text-gray-500 hover:text-gray-700'"
                    class="px-4 py-3 border-b-2 font-medium">
                Movimientos de capital ({{ $cargasCapital->count() }})
            </button>
            <button type="button" @click="tab = 'pagos'"
                    :class="tab === 'pagos' ? 'border-indigo-600 text-indigo-600' : 'border-transparent text-gray-500 hover:text-gray-700'"
                    class="px-4 py-3 border-b-2 font-medium">
                Historial de pagos ({{ count($historialPagos) }})
            </button>
        </div>

        {{-- Préstamos --}}
        <div x-show="tab === 'prestamos'">
            @forelse ($prestamos as $item)
                <div x-data="{ open: false }" class="border-b last:border-b-0">
                    <button type="button" @click="open = !open" class="w-full flex items-center justify-between gap-4 px-4 py-3 text-left hover:bg-gray-50">
                        <div class="min-w-0">
                            <p class="text-sm font-medium truncate">{{ $item->titulo }}</p>
                            <p class="text-xs text-gray-500 truncate">
                                {{ \App\Support\Dinero::formatear($item->montoTotal) }} ·
                                {{ number_format((float) $item->prestamo->porcentaje_interes, 0) }}% ·
                                {{ $item->prestamo->plazo_cuotas }} cuotas ·
                                {{ $item->prestamo->fecha_inicio->format('d/m/Y') }}
                            </p>
                        </div>
                        <x-admin.etiqueta-estado :estado="$item->prestamo->estado" />
                    </button>
                    <div x-show="open" class="px-4 pb-4 bg-gray-50 text-sm">
                        <div class="grid grid-cols-2 sm:grid-cols-3 gap-3 py-3">
                            <div>
                                <p class="text-xs text-gray-500">Capital</p>
                                <p class="font-medium">{{ \App\Support\Dinero::formatear((float) $item->prestamo->monto_capital) }}</p>
                            </div>
                            <div>
                                <p class="text-xs text-gray-500">Interés</p>
                                <p class="font-medium">{{ \App\Support\Dinero::formatear($item->montoInteres) }}</p>
                            </div>
                            @if ($item->montoExtras > 0)
                                <div>
                                    <p class="text-xs text-gray-500">Extras</p>
                                    <p class="font-medium">{{ \App\Support\Dinero::formatear($item->montoExtras) }}</p>
                                </div>
                            @endif
                            <div>
                                <p class="text-xs text-gray-500">Total de la deuda</p>
                                <p class="font-medium">{{ \App\Support\Dinero::formatear($item->montoTotal) }}</p>
                            </div>
                            <div>
                                <p class="text-xs text-gray-500">Total pagado</p>
                                <p class="font-medium">{{ \App\Support\Dinero::formatear($item->totalPagado) }}</p>
                            </div>
                            @if ($item->extraCobrado > 0)
                                <div>
                                    <p class="text-xs text-gray-500">Extra cobrado (no aplica a la deuda)</p>
                                    <p class="font-medium">{{ \App\Support\Dinero::formatear($item->extraCobrado) }}</p>
                                </div>
                            @endif
                            <div>
                                <p class="text-xs text-gray-500">Saldo pendiente</p>
                                <p class="font-semibold">{{ \App\Support\Dinero::formatear($item->saldoPendiente) }}</p>
                            </div>
                        </div>

                        <p class="text-xs font-medium text-gray-500 mb-2">Cuotas</p>
                        <div class="divide-y divide-gray-200 bg-white rounded border">
                            @foreach ($item->prestamo->cuotas as $cuota)
                                <div class="flex items-center justify-between px-3 py-2">
                                    <div>
                                        <span class="font-medium">Cuota {{ $cuota->numero_cuota }}</span>
                                        — {{ \App\Support\Dinero::formatear((float) $cuota->monto_esperado) }}
                                        <div class="text-xs text-gray-500">
                                            Esperada: {{ $cuota->fecha_esperada->format('d/m/Y') }}
                                            @isset($item->fechaPagoPorCuota[$cuota->id])
                                                · <span class="text-green-700 font-medium">Pagada: {{ $item->fechaPagoPorCuota[$cuota->id]->format('d/m/Y') }}</span>
                                            @endisset
                                        </div>
                                    </div>
                                    <x-admin.etiqueta-estado-cuota :estado="$cuota->estado" />
                                </div>
                            @endforeach
                        </div>
                    </div>
                </div>
            @empty
                <p class="text-gray-500 p-4">Sin préstamos registrados.</p>
            @endforelse
        </div>

        {{-- Clientes --}}
        <div x-show="tab === 'clientes'" x-cloak class="divide-y divide-gray-200">
            @forelse ($clientes as $fila)
                <div class="flex items-center justify-between px-4 py-3">
                    <div>
                        <p class="text-sm font-medium">{{ $fila['cliente']->nombre }}</p>
                        <p class="text-xs text-gray-500">CC {{ $fila['cliente']->cedula }} · {{ $fila['cliente']->telefono }}</p>
                    </div>
                    <span class="inline-flex items-center rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-700">
                        {{ $fila['pagados'] }}/{{ $fila['totales'] }}
                    </span>
                </div>
            @empty
                <p class="text-gray-500 p-4">Sin clientes registrados.</p>
            @endforelse
        </div>

        {{-- Movimientos de capital --}}
        <div x-show="tab === 'capital'" x-cloak class="divide-y divide-gray-200">
            @forelse ($cargasCapital as $carga)
                <div class="flex items-center justify-between px-4 py-3">
                    <div>
                        <p class="text-sm font-medium {{ $carga->tipo === 'retiro' ? 'text-red-600' : 'text-green-700' }}">
                            {{ $carga->tipo === 'retiro' ? '-' : '+' }} {{ \App\Support\Dinero::formatear((float) $carga->monto) }}
                        </p>
                        <p class="text-xs text-gray-500">
                            {{ $carga->created_at->format('d/m/Y') }}
                            @if ($carga->descripcion)
                                · {{ $carga->descripcion }}
                            @endif
                        </p>
                    </div>
                    @if ($carga->origen === 'admin')
                        <span class="inline-flex items-center rounded-full bg-indigo-100 px-2 py-0.5 text-xs font-medium text-indigo-700">
                            Asignado por administrador
                        </span>
                    @endif
                </div>
            @empty
                <p class="text-gray-500 p-4">Sin movimientos de capital registrados.</p>
            @endforelse
        </div>

        {{-- Historial de pagos --}}
        <div x-show="tab === 'pagos'" x-cloak>
            @forelse ($historialPagos as $grupo)
                <div x-data="{ open: false }" class="border-b last:border-b-0">
                    <button type="button" @click="open = !open" class="w-full flex items-center justify-between gap-4 px-4 py-3 text-left hover:bg-gray-50">
                        <div class="min-w-0">
                            <p class="text-sm font-medium truncate">{{ $grupo->tituloPrestamo }} — {{ $grupo->resumenCorto }}</p>
                            <p class="text-xs text-gray-500 truncate">
                                {{ \Illuminate\Support\Carbon::parse($grupo->fecha)->format('d/m/Y') }}
                                @if ($grupo->diasMora > 0)
                                    · {{ $grupo->diasMora }} días de mora
                                @endif
                                · Saldo restante: {{ \App\Support\Dinero::formatear($grupo->saldoRestanteDespues) }}
                            </p>
                        </div>
                        <span class="text-sm font-semibold shrink-0">{{ \App\Support\Dinero::formatear($grupo->montoTotalAbonado) }}</span>
                    </button>
                    <div x-show="open" class="px-4 pb-3 bg-gray-50 divide-y divide-gray-200">
                        @foreach ($grupo->filas as $fila)
                            <div class="flex items-center justify-between py-2 text-sm">
                                <span>{{ $fila->descripcion }}</span>
                                <span class="font-medium">{{ \App\Support\Dinero::formatear((float) $fila->pago->monto_abonado) }}</span>
                            </div>
                        @endforeach
                    </div>
                </div>
            @empty
                <p class="text-gray-500 p-4">Todavía no hay pagos registrados.</p>
            @endforelse
        </div>
    </div>
</div>
