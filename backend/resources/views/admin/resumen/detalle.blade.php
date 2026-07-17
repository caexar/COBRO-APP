@extends('admin.layout')

@section('titulo', $usuario->nombre)

@section('contenido')
    @livewire('admin.resumen.detalle-cobrador', ['usuario' => $usuario])
@endsection
