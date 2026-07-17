<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Services\ResumenAdminService;
use Illuminate\Http\JsonResponse;

class AdminResumenController extends Controller
{
    public function __construct(
        private readonly ResumenAdminService $resumenAdminService,
    ) {}

    public function index(): JsonResponse
    {
        return response()->json(['data' => $this->resumenAdminService->resumen()]);
    }
}
