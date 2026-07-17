<?php

namespace App\Livewire\Admin\Resumen;

use App\Exceptions\SaldoInsuficienteException;
use App\Models\User;
use App\Services\CapitalService;
use App\Services\ResumenAdminService;
use Illuminate\Validation\Rule;
use Livewire\Component;

/**
 * Drill-down de un cobrador: préstamos, clientes, movimientos de capital e historial de pagos
 * (todo vía `ResumenAdminService`), más el formulario de asignar saldo (`CapitalService::asignar`
 * — misma lógica y misma validación de saldo insuficiente que ya usa
 * `Api\Admin\AdminCargaCapitalController`).
 */
class DetalleCobrador extends Component
{
    public User $usuario;

    public string $tipoMovimiento = 'carga';

    public string $monto = '';

    public string $categoria = '';

    public string $descripcion = '';

    public ?string $errorCapital = null;

    public ?string $mensajeCapital = null;

    public function mount(User $usuario): void
    {
        abort_if($usuario->rol !== 'cobrador', 404, 'El usuario indicado no es un cobrador.');

        $this->usuario = $usuario;
    }

    /**
     * @return array<string, mixed>
     */
    protected function rules(): array
    {
        return [
            'tipoMovimiento' => ['required', 'in:carga,retiro'],
            'monto' => ['required', 'numeric', 'min:0.01'],
            // Solo se exige/valida cuando el movimiento es un retiro (mismo criterio que
            // StoreAdminCargaCapitalRequest del lado API); para una carga se descarta abajo en
            // asignarSaldo() sin importar lo que quedó seleccionado en el <select>.
            'categoria' => [
                Rule::excludeIf(fn () => $this->tipoMovimiento !== 'retiro'),
                'required', 'in:gasto_operativo,decision_jefe,salario,otro',
            ],
            'descripcion' => ['nullable', 'string', 'max:255'],
        ];
    }

    public function asignarSaldo(): void
    {
        $datos = $this->validate();

        $this->errorCapital = null;
        $this->mensajeCapital = null;

        try {
            app(CapitalService::class)->asignar(
                usuarioId: $this->usuario->id,
                tipo: $datos['tipoMovimiento'],
                monto: (float) $datos['monto'],
                descripcion: filled($datos['descripcion']) ? $datos['descripcion'] : null,
                actor: auth('web')->user(),
                categoria: $datos['categoria'] ?? null,
            );

            $this->mensajeCapital = 'Saldo asignado correctamente.';
            $this->monto = '';
            $this->categoria = '';
            $this->descripcion = '';
        } catch (SaldoInsuficienteException $e) {
            $this->errorCapital = $e->getMessage();
        }
    }

    public function render()
    {
        $servicio = app(ResumenAdminService::class);

        return view('livewire.admin.resumen.detalle-cobrador', [
            'clientes' => $servicio->clientesConConteo($this->usuario->id),
            'prestamos' => $servicio->prestamosDeCobrador($this->usuario->id),
            'cargasCapital' => $servicio->cargasCapitalDeCobrador($this->usuario->id),
            'historialPagos' => $servicio->historialPagosAgrupado($this->usuario->id),
            'saldoDisponible' => app(CapitalService::class)->calcularSaldoDisponible($this->usuario->id),
        ]);
    }
}
