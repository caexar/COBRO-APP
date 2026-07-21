<?php

namespace App\Http\Requests;

use App\Services\PrestamoCalculator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Validación puramente estructural/de tipo del batch de sincronización (mismas reglas de
 * campo que StoreClienteRequest/StorePrestamoRequest/StorePagoRequest/StoreCargaCapitalRequest,
 * más `uuid_local`). Un fallo acá es un batch malformado (bug del cliente) y responde 422 para
 * todo el request.
 *
 * Lo que NO se valida acá (porque no es un error de forma, es un resultado de negocio esperado
 * en cualquier sincronización real) son las referencias cruzadas entre arrays
 * (`cliente_uuid_local`, `prestamo_uuid_local`) y los conflictos por `uuid_local` repetido:
 * eso lo resuelve `SyncService`, que reporta el resultado por registro con `estado 200`, no
 * con una excepción de validación.
 */
class StoreSyncRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->isCobrador();
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'clientes' => ['nullable', 'array'],
            'clientes.*.uuid_local' => ['required', 'string', 'max:255', 'distinct'],
            'clientes.*.actualizado_en' => ['required', 'date'],
            'clientes.*.nombre' => ['required', 'string', 'max:255'],
            'clientes.*.cedula' => ['required', 'string', 'max:50'],
            'clientes.*.telefono' => ['required', 'string', 'max:30'],
            'clientes.*.direccion' => ['required', 'string', 'max:255'],
            'clientes.*.referencia' => ['nullable', 'string', 'max:255'],
            'clientes.*.foto_url' => ['nullable', 'string', 'max:2048'],

            'prestamos' => ['nullable', 'array'],
            'prestamos.*.uuid_local' => ['required', 'string', 'max:255', 'distinct'],
            'prestamos.*.actualizado_en' => ['required', 'date'],
            'prestamos.*.cliente_uuid_local' => ['required', 'string', 'max:255'],
            'prestamos.*.referencia' => ['nullable', 'string', 'max:255'],
            'prestamos.*.monto_capital' => ['required', 'numeric', 'min:0.01'],
            'prestamos.*.porcentaje_interes' => ['required', 'numeric', 'min:0'],
            'prestamos.*.extras' => ['nullable', 'array'],
            'prestamos.*.extras.*.concepto' => ['required_with:prestamos.*.extras', 'string', 'max:255'],
            'prestamos.*.extras.*.valor' => ['required_with:prestamos.*.extras', 'numeric', 'min:0'],
            'prestamos.*.frecuencia_pago' => ['required', Rule::in(PrestamoCalculator::FRECUENCIAS_VALIDAS)],
            'prestamos.*.dias_personalizado' => ['required_if:prestamos.*.frecuencia_pago,personalizado', 'nullable', 'integer', 'min:1'],
            'prestamos.*.plazo_cuotas' => ['required', 'integer', 'min:1'],
            'prestamos.*.fecha_inicio' => ['required', 'date'],
            'prestamos.*.politica_mora' => ['nullable', 'in:mantener,siguiente_pago,sumar_total'],

            // No se valida "required" arriba porque un pago existente (reintento) no necesita
            // traer todo el detalle de nuevo salvo uuid_local — SyncService decide si el resto
            // hace falta según si ya existe.
            'pagos' => ['nullable', 'array'],
            'pagos.*.uuid_local' => ['required', 'string', 'max:255', 'distinct'],
            'pagos.*.prestamo_uuid_local' => ['required', 'string', 'max:255'],
            'pagos.*.numero_cuota' => ['required', 'integer', 'min:1'],
            'pagos.*.monto_abonado' => ['required', 'numeric', 'min:0.01'],
            'pagos.*.monto_aplicado' => ['required', 'numeric', 'min:0'],
            'pagos.*.fecha_pago' => ['required', 'date'],
            'pagos.*.dias_mora' => ['required', 'integer', 'min:0'],
            'pagos.*.saldo_restante_despues' => ['required', 'numeric', 'min:0'],
            'pagos.*.estado_prestamo' => ['required', 'in:activo,pagado,en_mora,anulado'],
            'pagos.*.cuotas_afectadas' => ['required', 'array', 'min:1'],
            'pagos.*.cuotas_afectadas.*.numero_cuota' => ['required', 'integer', 'min:1'],
            'pagos.*.cuotas_afectadas.*.estado' => ['required', 'in:pendiente,pagada,en_mora'],
            'pagos.*.cuotas_afectadas.*.monto_esperado' => ['nullable', 'numeric', 'min:0'],

            'cargas_capital' => ['nullable', 'array'],
            'cargas_capital.*.uuid_local' => ['required', 'string', 'max:255', 'distinct'],
            'cargas_capital.*.tipo' => ['required', 'in:carga,retiro'],
            'cargas_capital.*.monto' => ['required', 'numeric', 'min:0.01'],
            'cargas_capital.*.descripcion' => ['nullable', 'string', 'max:255'],

            // Igual que cargas_capital: solo se crea o se confirma, sin flujo de edición desde
            // el móvil para un cierre ya registrado.
            'cierres_caja' => ['nullable', 'array'],
            'cierres_caja.*.uuid_local' => ['required', 'string', 'max:255', 'distinct'],
            'cierres_caja.*.fecha' => ['required', 'date'],
            'cierres_caja.*.capital_inicio' => ['required', 'numeric', 'min:0'],
            'cierres_caja.*.capital_cierre' => ['required', 'numeric', 'min:0'],
            'cierres_caja.*.justificacion_diferencia' => ['nullable', 'string', 'max:1000'],
            'cierres_caja.*.gastos' => ['nullable', 'array'],
            'cierres_caja.*.gastos.*.monto' => ['required_with:cierres_caja.*.gastos', 'numeric', 'min:0.01'],
            'cierres_caja.*.gastos.*.detalle' => ['required_with:cierres_caja.*.gastos', 'string', 'max:255'],
        ];
    }
}
