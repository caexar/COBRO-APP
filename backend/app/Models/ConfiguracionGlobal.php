<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['clave', 'valor'])]
class ConfiguracionGlobal extends Model
{
    protected $table = 'configuracion_global';

    public static function obtener(string $clave, mixed $default = null): mixed
    {
        return static::where('clave', $clave)->value('valor') ?? $default;
    }

    public static function guardar(string $clave, string $valor): void
    {
        static::updateOrCreate(['clave' => $clave], ['valor' => $valor]);
    }
}
