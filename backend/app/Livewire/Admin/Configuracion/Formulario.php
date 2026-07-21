<?php

namespace App\Livewire\Admin\Configuracion;

use App\Services\ConfiguracionAdminService;
use Livewire\Component;

/**
 * Configuración global (`configuracion_global`): tasas de interés sugeridas, política de mora
 * por defecto, intentos antes de ofrecer el PIN maestro, y el PIN maestro global — llama a
 * `ConfiguracionAdminService` (misma lógica que ya usa `Api\Admin\AdminConfiguracionController`).
 * El hash del PIN maestro nunca se lee ni se muestra: solo si está configurado o no.
 */
class Formulario extends Component
{
    /** @var array<int, float|int|string> */
    public array $tasas = [];

    public string $politicaMoraDefault = 'mantener';

    public int $intentosPinAntesDeMaestro = 3;

    public bool $pinMaestroConfigurado = false;

    public string $nuevoPinMaestro = '';

    public bool $quitarPinMaestro = false;

    public ?string $mensaje = null;

    /**
     * Preferencia personal del admin logueado (`users.atajo_miles_activado`), no de
     * `configuracion_global` — cada admin la edita para sí mismo, se guarda al instante (no
     * espera al botón "Guardar" del resto del formulario, ver `cambiarAtajoMiles()`). Mismo
     * criterio que `AtajoMilesRepository` del lado móvil.
     */
    public bool $atajoMilesActivado = true;

    public function mount(): void
    {
        $this->cargarDesdeServicio();
        $this->atajoMilesActivado = (bool) auth('web')->user()->atajo_miles_activado;
    }

    public function cambiarAtajoMiles(): void
    {
        auth('web')->user()->update(['atajo_miles_activado' => $this->atajoMilesActivado]);
    }

    private function cargarDesdeServicio(): void
    {
        $actual = app(ConfiguracionAdminService::class)->configuracionActual();

        $this->tasas = $actual['tasas_interes_default'];
        $this->politicaMoraDefault = $actual['politica_mora_default'];
        $this->intentosPinAntesDeMaestro = $actual['intentos_pin_antes_de_maestro'];
        $this->pinMaestroConfigurado = $actual['pin_maestro_configurado'];
    }

    public function agregarTasa(): void
    {
        $this->tasas[] = 0;
    }

    public function quitarTasa(int $indice): void
    {
        unset($this->tasas[$indice]);
        $this->tasas = array_values($this->tasas);
    }

    /**
     * @return array<string, mixed>
     */
    protected function rules(): array
    {
        return [
            'tasas' => ['array'],
            'tasas.*' => ['numeric', 'min:0'],
            'politicaMoraDefault' => ['required', 'in:mantener,siguiente_pago,sumar_total'],
            'intentosPinAntesDeMaestro' => ['required', 'integer', 'min:1', 'max:10'],
            'nuevoPinMaestro' => ['nullable', 'string', 'min:4', 'max:10'],
        ];
    }

    public function guardar(): void
    {
        $datos = $this->validate();

        $cambios = [
            'tasas_interes_default' => array_map(fn ($tasa) => (float) $tasa, $datos['tasas']),
            'politica_mora_default' => $datos['politicaMoraDefault'],
            'intentos_pin_antes_de_maestro' => $datos['intentosPinAntesDeMaestro'],
        ];

        // El checkbox "Quitar el PIN maestro actual" manda null explícito (distinto de no
        // incluir la clave, que significa "no cambiar nada") — mismo criterio que ya usa la API
        // y `AdminConfiguracionScreen` del móvil.
        if ($this->quitarPinMaestro) {
            $cambios['pin_maestro'] = null;
        } elseif (filled($datos['nuevoPinMaestro'])) {
            $cambios['pin_maestro'] = $datos['nuevoPinMaestro'];
        }

        app(ConfiguracionAdminService::class)->actualizar($cambios, auth('web')->user());

        $this->nuevoPinMaestro = '';
        $this->quitarPinMaestro = false;
        $this->mensaje = 'Configuración actualizada correctamente.';
        $this->cargarDesdeServicio();
    }

    public function render()
    {
        return view('livewire.admin.configuracion.formulario');
    }
}
