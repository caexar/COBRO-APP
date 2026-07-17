<?php

namespace App\Exceptions;

use RuntimeException;

/**
 * Resultado de negocio esperado (no un error de programación) al gestionar un usuario desde el
 * panel de administración: un admin intentando desactivarse a sí mismo, o (re)activar un usuario
 * que ya estaba en ese estado. Tanto la API (`AdminUsuarioController`, la convierte a 422) como el
 * panel web (Livewire, la muestra como error de formulario) capturan esta misma excepción.
 */
class UsuarioAdminException extends RuntimeException {}
