<?php

namespace App\Services;

use App\Models\CargaCapital;
use App\Models\CierreCaja;
use App\Models\Cliente;
use App\Models\ConfiguracionGlobal;
use App\Models\Pago;
use App\Models\Prestamo;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Procesa un batch de sincronización enviado por la app móvil: clientes -> prestamos -> pagos
 * (cargas_capital es independiente). Por cada registro decide, usando `uuid_local`, si hay que
 * crearlo, si ya existe (confirma sin duplicar), si hay que actualizarlo (solo campos
 * realmente editables desde el móvil) o si hubo un conflicto con una versión más reciente ya
 * guardada — nunca lanza una excepción por un resultado de negocio esperado, cada registro
 * reporta su propio resultado.
 *
 * IMPORTANTE sobre pagos: acá NO se vuelve a correr PagoProcessor. Los pagos que llegan por
 * este servicio ya fueron calculados localmente por su equivalente en Dart (dias_mora,
 * monto_aplicado, saldo_restante_despues, qué cuotas quedaron afectadas y en qué estado) — se
 * persiste tal cual, como fuente de verdad. PagoProcessor sigue siendo la única fuente de
 * verdad para pagos creados directo contra POST /pagos (fuera de sync).
 */
class SyncService
{
    public function __construct(
        private readonly PrestamoCalculator $calculator,
        private readonly AuditoriaLogger $auditoria,
    ) {}

    /**
     * @param  array{clientes?: array<int, array<string, mixed>>, prestamos?: array<int, array<string, mixed>>, pagos?: array<int, array<string, mixed>>, cargas_capital?: array<int, array<string, mixed>>, cierres_caja?: array<int, array<string, mixed>>}  $datos
     * @return array{clientes: array<int, array<string, mixed>>, prestamos: array<int, array<string, mixed>>, pagos: array<int, array<string, mixed>>, cargas_capital: array<int, array<string, mixed>>, cierres_caja: array<int, array<string, mixed>>}
     */
    public function sincronizar(User $usuario, array $datos): array
    {
        $resultado = ['clientes' => [], 'prestamos' => [], 'pagos' => [], 'cargas_capital' => [], 'cierres_caja' => []];

        /** @var array<string, Cliente> $clientesPorUuid */
        $clientesPorUuid = [];
        foreach ($datos['clientes'] ?? [] as $item) {
            [$itemResultado, $cliente] = $this->sincronizarCliente($usuario, $item);
            $resultado['clientes'][] = $itemResultado;

            if ($cliente) {
                $clientesPorUuid[$item['uuid_local']] = $cliente;
            }
        }

        /** @var array<string, Prestamo> $prestamosPorUuid */
        $prestamosPorUuid = [];
        foreach ($datos['prestamos'] ?? [] as $item) {
            [$itemResultado, $prestamo] = $this->sincronizarPrestamo($usuario, $item, $clientesPorUuid);
            $resultado['prestamos'][] = $itemResultado;

            if ($prestamo) {
                $prestamosPorUuid[$item['uuid_local']] = $prestamo;
            }
        }

        foreach ($datos['pagos'] ?? [] as $item) {
            $resultado['pagos'][] = $this->sincronizarPago($usuario, $item, $prestamosPorUuid);
        }

        foreach ($datos['cargas_capital'] ?? [] as $item) {
            $resultado['cargas_capital'][] = $this->sincronizarCargaCapital($usuario, $item);
        }

        foreach ($datos['cierres_caja'] ?? [] as $item) {
            $resultado['cierres_caja'][] = $this->sincronizarCierreCaja($usuario, $item);
        }

        return $resultado;
    }

    /**
     * @param  array<string, mixed>  $item
     * @return array{0: array<string, mixed>, 1: ?Cliente}
     */
    private function sincronizarCliente(User $usuario, array $item): array
    {
        $campos = [
            'nombre' => $item['nombre'],
            'cedula' => $item['cedula'],
            'telefono' => $item['telefono'],
            'direccion' => $item['direccion'],
            'referencia' => $item['referencia'] ?? null,
            'foto_url' => $item['foto_url'] ?? null,
        ];

        $existente = Cliente::withTrashed()
            ->where('usuario_id', $usuario->id)
            ->where('uuid_local', $item['uuid_local'])
            ->first();

        if (! $existente) {
            try {
                $cliente = Cliente::create([...$campos, 'usuario_id' => $usuario->id, 'uuid_local' => $item['uuid_local']]);
            } catch (QueryException) {
                return [$this->itemError($item['uuid_local'], 'Ya existe otro cliente con este nombre o cédula para este cobrador.'), null];
            }

            return [$this->itemCreado($item['uuid_local'], $cliente->id), $cliente];
        }

        $huboCambios = collect($campos)->contains(fn ($valor, $clave) => $existente->{$clave} !== $valor);

        if (! $huboCambios) {
            return [$this->itemYaExistia($item['uuid_local'], $existente->id), $existente];
        }

        if (Carbon::parse($item['actualizado_en'])->gt($existente->updated_at)) {
            $existente->update($campos);

            return [$this->itemActualizado($item['uuid_local'], $existente->id), $existente];
        }

        $this->registrarConflicto($usuario, 'Cliente', $existente->id, $campos, $existente->only(array_keys($campos)));

        return [$this->itemConflicto($item['uuid_local'], $existente->id), $existente];
    }

    /**
     * Único campo de un préstamo ya existente que puede llegar cambiado por sync es
     * `politica_mora` (ver `PagosRepository.registrar` en la app móvil: cuando el cobrador
     * elige una política distinta al registrar un pago con faltante, el préstamo local se
     * actualiza y se vuelve a encolar solo con ese campo). El resto de los datos del préstamo
     * (capital, interés, extras, cuotas) nunca se reescriben después de creado.
     *
     * @param  array<string, mixed>  $item
     * @param  array<string, Cliente>  $clientesPorUuid
     * @return array{0: array<string, mixed>, 1: ?Prestamo}
     */
    private function sincronizarPrestamo(User $usuario, array $item, array $clientesPorUuid): array
    {
        $existente = Prestamo::where('usuario_id', $usuario->id)->where('uuid_local', $item['uuid_local'])->first();

        if ($existente) {
            return [$this->reconciliarPoliticaMora($usuario, $existente, $item), $existente];
        }

        $cliente = $clientesPorUuid[$item['cliente_uuid_local']]
            ?? Cliente::where('usuario_id', $usuario->id)->where('uuid_local', $item['cliente_uuid_local'])->first();

        if (! $cliente) {
            return [$this->itemError($item['uuid_local'], 'El cliente referenciado (cliente_uuid_local) no se encontró; sincronízalo primero.'), null];
        }

        $resultado = $this->calculator->calcular($item);

        $prestamo = DB::transaction(function () use ($item, $usuario, $cliente, $resultado) {
            $prestamo = Prestamo::create([
                'cliente_id' => $cliente->id,
                'referencia' => $item['referencia'] ?? null,
                'usuario_id' => $usuario->id,
                'monto_capital' => $item['monto_capital'],
                'porcentaje_interes' => $item['porcentaje_interes'],
                'frecuencia_pago' => $item['frecuencia_pago'],
                'dias_personalizado' => $item['dias_personalizado'] ?? null,
                'plazo_cuotas' => $item['plazo_cuotas'],
                'fecha_inicio' => $item['fecha_inicio'],
                'estado' => 'activo',
                'politica_mora' => $item['politica_mora'] ?? ConfiguracionGlobal::obtener('politica_mora_default', 'mantener'),
                'uuid_local' => $item['uuid_local'],
            ]);

            foreach ($item['extras'] ?? [] as $extra) {
                $prestamo->extras()->create($extra);
            }

            foreach ($resultado['cuotas'] as $cuota) {
                $prestamo->cuotas()->create($cuota);
            }

            return $prestamo;
        });

        $this->auditoria->registrar(
            usuario: $usuario,
            accion: 'crear_prestamo',
            entidad: 'Prestamo',
            entidadId: $prestamo->id,
            datosAnteriores: null,
            datosNuevos: [
                'cliente_id' => $prestamo->cliente_id,
                'monto_capital' => $resultado['monto_capital'],
                'porcentaje_interes' => $prestamo->porcentaje_interes,
                'monto_extras' => $resultado['monto_extras'],
                'monto_total' => $resultado['monto_total'],
                'plazo_cuotas' => $prestamo->plazo_cuotas,
                'frecuencia_pago' => $prestamo->frecuencia_pago,
                'origen' => 'sync',
            ],
        );

        return [$this->itemCreado($item['uuid_local'], $prestamo->id), $prestamo];
    }

    /**
     * @param  array<string, mixed>  $item
     * @return array<string, mixed>
     */
    private function reconciliarPoliticaMora(User $usuario, Prestamo $existente, array $item): array
    {
        $politicaEntrante = $item['politica_mora'] ?? null;

        if ($politicaEntrante === null || $politicaEntrante === $existente->politica_mora) {
            return $this->itemYaExistia($item['uuid_local'], $existente->id);
        }

        if (Carbon::parse($item['actualizado_en'])->gt($existente->updated_at)) {
            $existente->update(['politica_mora' => $politicaEntrante]);

            return $this->itemActualizado($item['uuid_local'], $existente->id);
        }

        $this->registrarConflicto(
            $usuario,
            'Prestamo',
            $existente->id,
            ['politica_mora' => $politicaEntrante],
            ['politica_mora' => $existente->politica_mora],
        );

        return $this->itemConflicto($item['uuid_local'], $existente->id);
    }

    /**
     * @param  array<string, mixed>  $item
     * @param  array<string, Prestamo>  $prestamosPorUuid
     * @return array<string, mixed>
     */
    private function sincronizarPago(User $usuario, array $item, array $prestamosPorUuid): array
    {
        $prestamo = $prestamosPorUuid[$item['prestamo_uuid_local']]
            ?? Prestamo::where('usuario_id', $usuario->id)->where('uuid_local', $item['prestamo_uuid_local'])->first();

        if (! $prestamo) {
            return $this->itemError($item['uuid_local'], 'El préstamo referenciado (prestamo_uuid_local) no se encontró; sincronízalo primero.');
        }

        $existente = Pago::where('prestamo_id', $prestamo->id)->where('uuid_local', $item['uuid_local'])->first();

        if ($existente) {
            return $this->itemYaExistia($item['uuid_local'], $existente->id);
        }

        $cuotaPrincipal = $prestamo->cuotas()->where('numero_cuota', $item['numero_cuota'])->first();

        if (! $cuotaPrincipal) {
            return $this->itemError($item['uuid_local'], "La cuota número {$item['numero_cuota']} no existe para este préstamo.");
        }

        $pago = DB::transaction(function () use ($item, $prestamo, $cuotaPrincipal) {
            $pago = Pago::create([
                'prestamo_id' => $prestamo->id,
                'cuota_id' => $cuotaPrincipal->id,
                'monto_abonado' => $item['monto_abonado'],
                'monto_aplicado' => $item['monto_aplicado'],
                'fecha_pago' => $item['fecha_pago'],
                'dias_mora' => $item['dias_mora'],
                'saldo_restante_despues' => $item['saldo_restante_despues'],
                'uuid_local' => $item['uuid_local'],
            ]);

            // Estado (y, si aplica, nuevo monto_esperado por la política de mora) de cada
            // cuota tocada por este pago, tal como ya lo calculó PagoProcessor.dart — nunca se
            // recalcula acá.
            foreach ($item['cuotas_afectadas'] as $cuotaAfectada) {
                $cambios = ['estado' => $cuotaAfectada['estado']];

                if (array_key_exists('monto_esperado', $cuotaAfectada) && $cuotaAfectada['monto_esperado'] !== null) {
                    $cambios['monto_esperado'] = $cuotaAfectada['monto_esperado'];
                }

                $prestamo->cuotas()->where('numero_cuota', $cuotaAfectada['numero_cuota'])->update($cambios);
            }

            if ($item['estado_prestamo'] !== $prestamo->estado) {
                $prestamo->update(['estado' => $item['estado_prestamo']]);
            }

            return $pago;
        });

        $this->auditoria->registrar(
            usuario: $usuario,
            accion: 'registrar_pago',
            entidad: 'Pago',
            entidadId: $pago->id,
            datosAnteriores: null,
            datosNuevos: [
                'prestamo_id' => $prestamo->id,
                'monto_abonado' => (float) $pago->monto_abonado,
                'monto_aplicado' => (float) $pago->monto_aplicado,
                'dias_mora' => $pago->dias_mora,
                'saldo_restante_despues' => (float) $pago->saldo_restante_despues,
                'origen' => 'sync',
            ],
        );

        return $this->itemCreado($item['uuid_local'], $pago->id);
    }

    /**
     * cargas_capital solo se crea o se confirma (no hay flujo de edición desde el móvil para
     * un movimiento ya creado, a diferencia de clientes/prestamos), así que acá no hace falta
     * lógica de actualización ni de conflicto.
     *
     * @param  array<string, mixed>  $item
     * @return array<string, mixed>
     */
    private function sincronizarCargaCapital(User $usuario, array $item): array
    {
        $existente = CargaCapital::where('usuario_id', $usuario->id)->where('uuid_local', $item['uuid_local'])->first();

        if ($existente) {
            return $this->itemYaExistia($item['uuid_local'], $existente->id);
        }

        $carga = CargaCapital::create([
            'usuario_id' => $usuario->id,
            'tipo' => $item['tipo'],
            'monto' => $item['monto'],
            'descripcion' => $item['descripcion'] ?? null,
            'origen' => 'cobrador',
            'uuid_local' => $item['uuid_local'],
        ]);

        $this->auditoria->registrar(
            usuario: $usuario,
            accion: 'registrar_carga_capital',
            entidad: 'CargaCapital',
            entidadId: $carga->id,
            datosAnteriores: null,
            datosNuevos: ['tipo' => $carga->tipo, 'monto' => (float) $carga->monto, 'descripcion' => $carga->descripcion],
        );

        return $this->itemCreado($item['uuid_local'], $carga->id);
    }

    /**
     * cierres_caja sigue el mismo criterio que cargas_capital: solo se crea o se confirma
     * (sin flujo de edición desde el móvil para un cierre ya registrado). `gastos_total` se
     * deriva acá de la suma de los gastos recibidos, igual que en `CierreCajaController::store`
     * — no se confía en un total que mande el cliente.
     *
     * @param  array<string, mixed>  $item
     * @return array<string, mixed>
     */
    private function sincronizarCierreCaja(User $usuario, array $item): array
    {
        $existente = CierreCaja::where('usuario_id', $usuario->id)->where('uuid_local', $item['uuid_local'])->first();

        if ($existente) {
            return $this->itemYaExistia($item['uuid_local'], $existente->id);
        }

        $gastos = $item['gastos'] ?? [];
        $gastosTotal = round(collect($gastos)->sum('monto'), 2);

        $cierre = DB::transaction(function () use ($usuario, $item, $gastos, $gastosTotal) {
            $cierre = CierreCaja::create([
                'usuario_id' => $usuario->id,
                'fecha' => $item['fecha'],
                'capital_inicio' => $item['capital_inicio'],
                'capital_cierre' => $item['capital_cierre'],
                'justificacion_diferencia' => $item['justificacion_diferencia'] ?? null,
                'gastos_total' => $gastosTotal,
                'uuid_local' => $item['uuid_local'],
            ]);

            foreach ($gastos as $gasto) {
                $cierre->gastos()->create($gasto);
            }

            return $cierre;
        });

        $this->auditoria->registrar(
            usuario: $usuario,
            accion: 'registrar_cierre_caja',
            entidad: 'CierreCaja',
            entidadId: $cierre->id,
            datosAnteriores: null,
            datosNuevos: [
                'fecha' => $cierre->fecha->toDateString(),
                'capital_inicio' => (float) $cierre->capital_inicio,
                'capital_cierre' => (float) $cierre->capital_cierre,
                'gastos_total' => (float) $cierre->gastos_total,
                'origen' => 'sync',
            ],
        );

        return $this->itemCreado($item['uuid_local'], $cierre->id);
    }

    /**
     * Movimientos de capital que un admin le asignó a este cobrador
     * (`POST /admin/cargas-capital`) y que su dispositivo todavía no tiene — el cobrador nunca
     * llama a un endpoint de lectura para esto, viaja empaquetado en la misma respuesta de
     * `POST /sync` para no gastar un segundo viaje de red.
     *
     * Marca `descargado = true` recién acá, al construir la lista que se va a devolver — si el
     * request se cae antes de llegar a este punto (excepción en el batch de arriba), no se
     * marcan y se reintentan en el próximo `/sync`. Nota: esto no protege contra que la
     * respuesta HTTP se pierda ya en camino de vuelta al dispositivo (el servidor no tiene forma
     * de saber si el cliente la recibió) — ver CLAUDE.md para el detalle de este trade-off.
     *
     * @return array<int, array<string, mixed>>
     */
    public function cargasCapitalAdminPendientes(User $usuario): array
    {
        $pendientes = CargaCapital::where('usuario_id', $usuario->id)
            ->where('origen', 'admin')
            ->where('descargado', false)
            ->get();

        if ($pendientes->isEmpty()) {
            return [];
        }

        $datos = $pendientes->map(fn (CargaCapital $carga) => [
            'id' => $carga->id,
            'tipo' => $carga->tipo,
            'monto' => (float) $carga->monto,
            'descripcion' => $carga->descripcion,
            'creado_en' => $carga->created_at?->toIso8601String(),
        ])->all();

        CargaCapital::whereIn('id', $pendientes->pluck('id'))->update(['descargado' => true]);

        return $datos;
    }

    /**
     * @param  array<string, mixed>  $datosAnteriores  Versión perdedora (la que llegó en este sync).
     * @param  array<string, mixed>  $datosNuevos  Versión ganadora (la que ya estaba guardada).
     */
    private function registrarConflicto(User $usuario, string $entidad, int $entidadId, array $datosAnteriores, array $datosNuevos): void
    {
        $this->auditoria->registrar(
            usuario: $usuario,
            accion: 'conflicto_resuelto',
            entidad: $entidad,
            entidadId: $entidadId,
            datosAnteriores: $datosAnteriores,
            datosNuevos: $datosNuevos,
        );
    }

    /**
     * @return array<string, mixed>
     */
    private function itemCreado(string $uuidLocal, int $id): array
    {
        return ['uuid_local' => $uuidLocal, 'estado' => 'creado', 'id' => $id];
    }

    /**
     * @return array<string, mixed>
     */
    private function itemActualizado(string $uuidLocal, int $id): array
    {
        return ['uuid_local' => $uuidLocal, 'estado' => 'actualizado', 'id' => $id];
    }

    /**
     * @return array<string, mixed>
     */
    private function itemYaExistia(string $uuidLocal, int $id): array
    {
        return ['uuid_local' => $uuidLocal, 'estado' => 'ya_existia', 'id' => $id];
    }

    /**
     * @return array<string, mixed>
     */
    private function itemConflicto(string $uuidLocal, int $id): array
    {
        return ['uuid_local' => $uuidLocal, 'estado' => 'conflicto', 'id' => $id];
    }

    /**
     * @return array<string, mixed>
     */
    private function itemError(string $uuidLocal, string $mensaje): array
    {
        return ['uuid_local' => $uuidLocal, 'estado' => 'error', 'message' => $mensaje];
    }
}
