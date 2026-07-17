<?php

namespace App\Livewire\Admin\Auditoria;

use App\Models\Auditoria;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * Visor de auditoría: puramente de consulta (sin editar ni eliminar), con filtro por `accion` y
 * por rango de fecha. Los valores de `datos_anteriores`/`datos_nuevos` se muestran vía
 * `App\Support\AuditoriaPresentador::datosSeguros()` para no exponer nada relacionado a PIN,
 * aunque `AuditoriaLogger` ya garantiza que eso nunca debería llegar a guardarse en crudo.
 */
class Index extends Component
{
    use WithPagination;

    public string $accion = '';

    public string $desde = '';

    public string $hasta = '';

    public function updatingAccion(): void
    {
        $this->resetPage();
    }

    public function updatingDesde(): void
    {
        $this->resetPage();
    }

    public function updatingHasta(): void
    {
        $this->resetPage();
    }

    public function render()
    {
        $consulta = Auditoria::with('usuario')->latest('created_at');

        if (filled($this->accion)) {
            $consulta->where('accion', $this->accion);
        }
        if (filled($this->desde)) {
            $consulta->whereDate('created_at', '>=', $this->desde);
        }
        if (filled($this->hasta)) {
            $consulta->whereDate('created_at', '<=', $this->hasta);
        }

        return view('livewire.admin.auditoria.index', [
            'registros' => $consulta->paginate(20),
            'acciones' => Auditoria::select('accion')->distinct()->orderBy('accion')->pluck('accion'),
        ]);
    }
}
