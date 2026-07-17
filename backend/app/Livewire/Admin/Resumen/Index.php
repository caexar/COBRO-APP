<?php

namespace App\Livewire\Admin\Resumen;

use App\Services\ResumenAdminService;
use Livewire\Component;

/**
 * Resumen global + por cobrador (capital_prestado, total_cobrado, cartera_en_mora,
 * ganancia_interes, ganancia_extra, saldo_disponible) — llama directamente a
 * `ResumenAdminService` (mismo proceso, sin pasar por HTTP) en vez de consumir
 * `GET /api/admin/resumen`, aunque ambos comparten exactamente la misma lógica.
 */
class Index extends Component
{
    public function render()
    {
        $resumen = app(ResumenAdminService::class)->resumen();

        return view('livewire.admin.resumen.index', [
            'global' => $resumen['global'],
            'porCobrador' => $resumen['por_cobrador'],
        ]);
    }
}
