@extends('admin.layout')

@section('titulo', isset($usuario) ? 'Editar usuario' : 'Nuevo usuario')

@section('contenido')
    @livewire('admin.usuarios.formulario', ['usuario' => $usuario ?? null])
@endsection
