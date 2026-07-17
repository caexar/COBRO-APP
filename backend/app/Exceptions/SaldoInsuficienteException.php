<?php

namespace App\Exceptions;

use RuntimeException;

/**
 * Un retiro de capital (`CapitalService::asignar`) pedido para un monto mayor al saldo
 * disponible del cobrador — resultado de negocio esperado, no un error de programación. Tanto
 * `Api\Admin\AdminCargaCapitalController` (la convierte a 422) como el panel web (Livewire, la
 * muestra como error de formulario) capturan esta misma excepción.
 */
class SaldoInsuficienteException extends RuntimeException {}
