<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\UpdateConfiguracionRequest;
use App\Services\ConfiguracionAdminService;
use Illuminate\Http\JsonResponse;

class AdminConfiguracionController extends Controller
{
    public function __construct(
        private readonly ConfiguracionAdminService $configuracionAdminService,
    ) {}

    public function index(): JsonResponse
    {
        return response()->json(['data' => $this->configuracionAdminService->configuracionActual()]);
    }

    public function update(UpdateConfiguracionRequest $request): JsonResponse
    {
        $actual = $this->configuracionAdminService->actualizar($request->validated(), $request->user());

        return response()->json(['data' => $actual]);
    }
}
