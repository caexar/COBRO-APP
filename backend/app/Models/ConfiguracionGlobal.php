<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['clave', 'valor'])]
class ConfiguracionGlobal extends Model
{
    protected $table = 'configuracion_global';
}
