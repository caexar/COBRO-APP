<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('titulo', 'Panel') · CobroApp Admin</title>
    @vite(['resources/css/app.css', 'resources/js/app.js'])
    @livewireStyles
</head>
<body class="bg-gray-50 text-gray-900 antialiased">
    <div class="flex min-h-screen">
        <aside class="w-64 shrink-0 bg-gray-900 text-gray-100 flex flex-col">
            <div class="px-6 py-5 text-lg font-semibold border-b border-gray-800">CobroApp · Admin</div>
            <nav class="flex-1 px-3 py-4 space-y-1">
                <a href="{{ route('admin.usuarios.index') }}" wire:navigate
                   class="block px-3 py-2 rounded-md text-sm font-medium {{ request()->routeIs('admin.usuarios.*') ? 'bg-gray-800 text-white' : 'text-gray-300 hover:bg-gray-800 hover:text-white' }}">
                    Usuarios
                </a>
                <a href="{{ route('admin.resumen') }}" wire:navigate
                   class="block px-3 py-2 rounded-md text-sm font-medium {{ request()->routeIs('admin.resumen') ? 'bg-gray-800 text-white' : 'text-gray-300 hover:bg-gray-800 hover:text-white' }}">
                    Resumen
                </a>
                <a href="{{ route('admin.configuracion') }}" wire:navigate
                   class="block px-3 py-2 rounded-md text-sm font-medium {{ request()->routeIs('admin.configuracion') ? 'bg-gray-800 text-white' : 'text-gray-300 hover:bg-gray-800 hover:text-white' }}">
                    Configuración
                </a>
                <a href="{{ route('admin.auditoria') }}" wire:navigate
                   class="block px-3 py-2 rounded-md text-sm font-medium {{ request()->routeIs('admin.auditoria') ? 'bg-gray-800 text-white' : 'text-gray-300 hover:bg-gray-800 hover:text-white' }}">
                    Auditoría
                </a>
                <a href="{{ route('admin.exportar') }}" wire:navigate
                   class="block px-3 py-2 rounded-md text-sm font-medium {{ request()->routeIs('admin.exportar') ? 'bg-gray-800 text-white' : 'text-gray-300 hover:bg-gray-800 hover:text-white' }}">
                    Exportar
                </a>
            </nav>
            <div class="px-3 py-4 border-t border-gray-800">
                <form method="POST" action="{{ route('admin.logout') }}">
                    @csrf
                    <button type="submit" class="w-full text-left px-3 py-2 rounded-md text-sm font-medium text-gray-300 hover:bg-gray-800 hover:text-white">
                        Cerrar sesión
                    </button>
                </form>
            </div>
        </aside>

        <div class="flex-1 flex flex-col min-w-0">
            <header class="bg-white border-b px-6 py-4 flex items-center justify-between">
                <h1 class="text-xl font-semibold">@yield('titulo', 'Panel')</h1>
                @auth('web')
                    <span class="text-sm text-gray-500">{{ auth('web')->user()->nombre }}</span>
                @endauth
            </header>

            <main class="flex-1 p-6">
                @if (session('error'))
                    <div class="mb-4 rounded-md bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700">
                        {{ session('error') }}
                    </div>
                @endif
                @if (session('status'))
                    <div class="mb-4 rounded-md bg-green-50 border border-green-200 px-4 py-3 text-sm text-green-700">
                        {{ session('status') }}
                    </div>
                @endif

                @yield('contenido')
            </main>
        </div>
    </div>

    @livewireScripts
</body>
</html>
