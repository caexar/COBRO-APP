# CobroApp

## Resumen del proyecto

CobroApp es una app móvil offline-first de cobro diario (cobradiario). El proyecto es un
monorepo compuesto por:

- `/mobile` — app Flutter (offline-first)
- `/backend` — API REST en Laravel

## Nombres del proyecto

- Nombre del producto (visible para humanos): **CobroApp**
- Nombre técnico (código, identificadores): **cobro_app** (snake_case, sin guiones)

Este nombre técnico debe usarse consistentemente en:

- Nombre de la base de datos: `cobro_app`
- Package name de Flutter (pubspec `name`): `cobro_app`
- Application ID de Android: `com.cobroapp.cobro_app` (o equivalente basado en `cobro_app`)
- Nombre del proyecto Laravel (`APP_NAME`, composer package): `cobro_app`
- Nombres de carpetas y módulos internos: `cobro_app`
- Títulos visibles en la UI de la app: **CobroApp**

No usar variaciones como `cobro-app`, `cobroApp`, `CobroDiario`, etc. en identificadores técnicos.

## Autenticación y autorización (backend)

- API por token vía Laravel Sanctum (`POST /api/login`, `POST /api/logout`). Ver `API.md`.
- Todas las rutas de negocio (`clientes`, `prestamos`, `pagos`) están protegidas con
  `auth:sanctum` + middleware `role:cobrador`: **solo el rol `cobrador` puede usarlas**, y
  siempre filtradas por `usuario_id` del cobrador autenticado.
- `admin` tiene sus propios endpoints bajo `/api/admin/*` (middleware `role:admin`), en
  `App\Http\Controllers\Api\Admin\*`; no reutiliza las rutas de cobrador para editar datos
  operativos. `ClientePolicy` y `PrestamoPolicy` (`app/Policies/`) contemplan que `admin`
  puede leer (`view`/`viewAny`) pero no crear/editar/eliminar clientes/préstamos — el CRUD de
  esos recursos sigue siendo exclusivo del cobrador dueño.
- Las rutas `/api/admin/*` no usan Policies de objeto (no hay "dueño" que proteger: el admin
  ve/gestiona todos los cobradores) — la única barrera es el middleware `role:admin`.
- Además de la API por token, existe un **panel de administración web** (sesión, guard `web`)
  bajo `/admin/*` — coexiste con Sanctum sin tocarlo. Ver sección "Panel de administración web
  (Livewire)" más abajo para el detalle completo (auth, rutas, Services compartidos).

## Reglas de negocio de préstamos, cuotas y pagos

Implementadas en `app/Services/PrestamoCalculator.php` y `app/Services/PagoProcessor.php`.
Cualquier cambio a esta lógica en el futuro debe modificar esos servicios, no reimplementarla
en un controlador.

### Cálculo del préstamo (`PrestamoCalculator`)

- `monto_interes = monto_capital * (porcentaje_interes / 100)` — interés simple, una sola
  vez sobre el capital (no interés compuesto ni por periodo).
- `monto_total = monto_capital + monto_interes + suma(extras.valor)`.
- Las cuotas se generan repartiendo `monto_total` entre `plazo_cuotas` a partes iguales
  (`monto_total / plazo_cuotas`, redondeado a 2 decimales); la **última cuota absorbe el
  residuo de redondeo** para que la suma exacta de todas las cuotas sea igual a `monto_total`.
- La fecha de la cuota `n` (1-indexada) se calcula sumando `n` periodos a `fecha_inicio`
  (la cuota 1 vence un periodo después del inicio, no el mismo día):
  - `diario` → `+n` días
  - `semanal` → `+n` semanas
  - `quincenal` → `+n * 15` días
  - `mensual` → `+n` meses (sin overflow de fin de mes)
  - `personalizado` → `+n * dias_personalizado` días
- `POST /api/prestamos/simular` usa exactamente el mismo cálculo que `POST /api/prestamos`
  (mismo servicio), solo que no persiste nada.

### Registro de pagos y mora (`PagoProcessor`)

Un pago siempre se aplica contra **la cuota pendiente más antigua** (`numero_cuota` menor
con `estado != pagada`) del préstamo. `dias_mora` se calcula comparando `fecha_pago` contra
la `fecha_esperada` de esa cuota (0 si se paga a tiempo o antes).

Tres escenarios al comparar `monto_abonado` contra lo que falta de esa cuota
(`pendienteEnCuota`, que descuenta abonos parciales previos ya aplicados a la misma cuota):

1. **Exacto**: la cuota queda `pagada`.
2. **Menos de lo esperado (faltante)** → se aplica `politica_mora` del préstamo:
   - `mantener`: no se toca nada más; la cuota queda `en_mora` (o `pendiente` si aún no
     vencía) con el faltante pendiente para un pago futuro sobre la misma cuota.
   - `siguiente_pago`: el faltante se suma al `monto_esperado` de la siguiente cuota
     pendiente; la cuota actual se da por saldada (`pagada`) aunque quedó incompleta.
   - `sumar_total`: el faltante se reparte en partes iguales entre **todas** las demás
     cuotas pendientes (último reparto absorbe el residuo); la cuota actual queda `pagada`.
   - Si no hay una siguiente cuota / otras cuotas pendientes donde aplicar la política,
     se hace fallback a `mantener`.
3. **Más de lo esperado (excedente)** → requiere que la petición incluya
   `manejo_excedente` (`abono_deuda` | `cobro_extra`); si falta, la API devuelve 422 pidiéndolo
   (la app debe preguntárselo al cobrador en el momento).
   - `abono_deuda`: el excedente se va aplicando en cascada a las siguientes cuotas
     pendientes (reduce su saldo pendiente y las marca `pagada` si alcanza).
   - `cobro_extra`: el excedente se registra en `monto_abonado` pero **no** reduce la deuda
     (no toca ninguna otra cuota).

Cada cuota realmente afectada por un pago (la original + las tocadas por una cascada de
`abono_deuda`) genera **su propia fila en `pagos`**, porque `pagos.cuota_id` es una FK
singular — por eso `POST /api/pagos` puede devolver un array. La columna `pagos.monto_aplicado`
(añadida en la migración `add_monto_aplicado_to_pagos_table`, no estaba en el esquema
original) registra cuánto de cada fila realmente redujo la deuda — es distinta de
`monto_abonado` solo en el caso `cobro_extra`.

`saldo_restante_despues` de cada pago se calcula como
`Prestamo::monto_total - suma_total_de(pagos.monto_aplicado)` **hasta ese momento**
(`monto_total` es un *accessor* de Eloquent — `protected function montoTotal(): Attribute` +
`protected $appends = ['monto_total']` — no una columna; se serializa solo en cualquier
respuesta que incluya el modelo, incluida `GET /api/admin/usuarios/{id}/detalle`. Antes era un
método PHP plano (`->montoTotal()`) que no aparecía en el JSON; si se necesita en código PHP
ahora se usa como propiedad: `$prestamo->monto_total`, no `$prestamo->montoTotal()`). El
estado del préstamo se
recalcula después de cada pago: `pagado` si ya no quedan cuotas sin pagar, `en_mora` si
alguna cuota quedó en `en_mora`, si no `activo`. `anulado` es un estado aparte que solo se
setea vía `PUT /api/prestamos/{id}/anular` y bloquea nuevos pagos.

### Auditoría

`crear_prestamo`, `registrar_pago`, `anular_prestamo`, `registrar_carga_capital`, y del lado
admin `crear_usuario`, `actualizar_usuario`, `desactivar_usuario`, `actualizar_configuracion`,
`asignar_capital` dejan registro en `auditoria` vía `App\Services\AuditoriaLogger`. Cualquier
acción nueva que el negocio considere "relevante" debe usar ese mismo servicio en lugar de
escribir en el modelo `Auditoria` directamente. Nunca se registra un PIN en texto plano en
`auditoria` (ver `actualizar_configuracion`, que solo guarda si el PIN maestro cambió, no su
valor). `conflicto_resuelto` (ver sección de sincronización más abajo) sigue el mismo patrón:
`datos_anteriores` es la versión perdedora, `datos_nuevos` la ganadora.

## Administración: usuarios, resumen y configuración global

### PIN maestro: individual vs. global

Existen **dos** niveles de PIN maestro, coexistiendo a propósito (decisión explícita, no
descuido):
- `users.pin_maestro_hash` (por cobrador, nullable): lo gestiona el admin vía
  `PUT /api/admin/usuarios/{id}` (campo `pin_maestro`; enviarlo como `null` lo limpia).
- `configuracion_global` (clave `pin_maestro_hash`, gestionada vía
  `PUT /api/admin/configuracion`): PIN maestro **global**, usado como respaldo cuando un
  cobrador no tiene el suyo propio.

`GET /api/admin/configuracion` (solo admin) nunca expone ninguno de los dos hashes, solo
`pin_maestro_configurado: true/false`. Para que la app móvil pueda validar el PIN maestro
**sin conexión**, existe un endpoint aparte, para cobradores, que sí entrega los hashes:
`GET /api/pin-maestro` (`App\Http\Controllers\Api\PinMaestroController`), devuelve
`pin_maestro_individual_hash` (del cobrador autenticado), `pin_maestro_global_hash` (de
`configuracion_global`, ambos nullable) y también `intentos_pin_antes_de_maestro` (mismo
patrón: es una config de admin, pero el cobrador necesita descargarla para que el bloqueo
funcione offline). La app intenta primero el individual y, si no coincide o no existe, cae
al global (implementado en `mobile/lib/features/auth/data/bloqueo_repository.dart`).
**Cualquier configuración nueva que el cobrador necesite offline debe seguir este mismo
patrón** — agregarla a `GET /api/pin-maestro`, no asumir que se puede leer directo de
`/api/admin/configuracion` (esa ruta seguirá siendo 403 para cualquier cobrador).

### Usuarios (admin)

- `POST /api/admin/usuarios` puede crear tanto `cobrador` como `admin` (campo `rol` libre).
- `pin` es opcional al crear un usuario; si se omite, queda `0000` por defecto (debilidad
  intencional temporal — el usuario debería cambiarlo desde la app apenas entre).
- `PUT /api/admin/usuarios/{id}` **no acepta `activo`** — ese campo solo cambia vía
  `PUT /api/admin/usuarios/{id}/desactivar` (nunca borra el registro, ni soft delete, y no
  deja que un admin se desactive a sí mismo) y `PUT /api/admin/usuarios/{id}/reactivar`
  (mismas protecciones: solo admin, auditoría).

### Resumen consolidado (`GET /api/admin/resumen`)

Toda esta lógica vive en `App\Services\ResumenAdminService` (extraída de
`AdminResumenController`, que ahora es un delegado delgado) — es la misma que consume el panel
web (Livewire) sin pasar por HTTP, ver sección de panel web más abajo. No reimplementar estos
cálculos en un controlador ni en un componente Livewire nuevo.

- `capital_prestado` excluye préstamos con `estado = anulado`.
- `total_cobrado` es la suma de `pagos.monto_aplicado` (no `monto_abonado` — así excedentes
  registrados como `cobro_extra` no inflan el total cobrado más allá de lo que realmente
  redujo deuda).
- `cartera_en_mora` es el saldo **pendiente real** de las cuotas en `estado = en_mora`
  (`monto_esperado` menos lo ya aplicado a esa cuota), no el monto bruto de la cuota.
- `ganancia_interes`/`ganancia_extra` (por cobrador y global,
  `ResumenAdminService::calcularGananciaPorCobrador()`, privado): réplica en PHP de la misma
  lógica de reparto proporcional que ya existía en `DashboardRepository` del lado móvil — por
  cada préstamo del cobrador (**cualquier estado**, uno ya `pagado`/`anulado` sigue contando
  históricamente) se reparte `Σpagos.monto_aplicado` proporcional al peso de interés/extras
  sobre `monto_total`; el excedente de un pago `cobro_extra` se suma íntegro a `ganancia_extra`.
  Si se vuelve a tocar la fórmula de ganancia en el móvil, hay que replicar el cambio acá
  también (mismo cuidado que ya existe entre `PrestamoCalculator` y su equivalente en Dart).
  El cálculo por-préstamo se extrajo a **`ResumenAdminService::gananciaDePrestamo(Prestamo
  $prestamo, ?Carbon $desde = null, ?Carbon $hasta = null)`** (público): sin rango, es
  exactamente lo mismo de siempre (histórico completo); con rango, prorratea solo sobre los
  pagos con `fecha_pago` dentro de `[$desde, $hasta]` — usado por `ExportarReporteService`
  para el reporte financiero (ver esa sección más abajo), no solo por el resumen consolidado.
- `saldo_disponible` (por cobrador y global): `App\Services\CapitalService::calcularSaldoDisponible()`
  — misma fórmula que `DashboardRepository.calcularResumen` del lado móvil (cargas − retiros +
  Σ`pagos.monto_abonado` − Σ`monto_capital` de préstamos no anulados). Única fuente de verdad,
  reutilizada también para validar un retiro (ver `CapitalService::asignar()` más abajo) — no
  duplicar la fórmula.
- Se calcula por cobrador y como total global; incluye cobradores sin actividad (con ceros).
- No existe (ni se agregó) un endpoint `GET /admin/prestamos/{id}` para el detalle de un solo
  préstamo con sus cuotas — confirmado explícitamente que no existe. El detalle completo
  (extras + cuotas + pagos por préstamo) sigue viajando solo dentro de
  `GET /api/admin/usuarios/{id}/detalle` (todos los préstamos del cobrador de una vez); el
  panel admin del móvil arma su modal de detalle de préstamo con esos datos ya descargados, sin
  pedir nada nuevo (ver sección de móvil más abajo). Tampoco existe un endpoint que devuelva
  conteo de préstamos por cliente — se resuelve agrupando en memoria del lado móvil. El panel
  web tampoco necesita este endpoint: `ResumenAdminService::prestamosDeCobrador()` (Livewire,
  mismo proceso) hace el eager-load directo con Eloquent — sigue sin existir una ruta HTTP para
  esto, ni falta hace.

### Configuración global (`configuracion_global`)

Tabla clave/valor genérica; el admin gestiona 4 claves conocidas vía
`GET`/`PUT /api/admin/configuracion` (lectura/escritura extraída a
`App\Services\ConfiguracionAdminService`, reutilizada tal cual por el panel web — ver sección
de panel web más abajo, incluido el mismo manejo de `pin_maestro: null` explícito):
- `tasas_interes_default`: array JSON de tasas sugeridas (ej. `[10,20,30,40]`) — **no se
  valida** `porcentaje_interes` de un préstamo contra esta lista, es solo un valor de UI.
- `politica_mora_default`: si `POST /api/prestamos` no envía `politica_mora`, se usa este
  valor (lookup vía `ConfiguracionGlobal::obtener('politica_mora_default', 'mantener')` en
  `PrestamoController::store`) en lugar de un default hardcodeado.
- `pin_maestro_hash`: ver sección de PIN maestro arriba.
- `intentos_pin_antes_de_maestro`: entero (default `3`, guardado como string en la tabla,
  como todo en `configuracion_global`); cuántos intentos fallidos del PIN personal tolera la
  app móvil antes de ofrecer el PIN maestro. Se lee/escribe igual que las demás claves, pero
  **también se expone vía `GET /api/pin-maestro`** (endpoint de cobrador, no solo de admin) —
  ver esa sección arriba y la nota en "App móvil: autenticación y bloqueo" más abajo sobre por
  qué esto vive ahí y no solo en el endpoint de admin.

`ConfiguracionGlobal::obtener()`/`::guardar()` son los helpers para leer/escribir por clave;
usarlos en vez de consultar la tabla directamente.

## Panel de administración web (Livewire, `/backend`)

Construido en Livewire puro + Blade (sin Filament ni otro framework de admin) — **costo cero
adicional**: vive en el mismo proyecto/despliegue Laravel que la API móvil, misma base de
datos, mismo `composer install`. Tailwind (ya disponible vía Vite/`@tailwindcss/vite`, no se
agregó como dependencia nueva) para estilos.

### Autenticación web (separada de la API móvil)

- Guard `web` (sesión, `Auth::guard('web')`) coexiste con el guard `sanctum`/`api` que usa el
  móvil, sin tocarlo — son completamente independientes (el guard `web` ya venía en
  `config/auth.php` por defecto, no hizo falta crearlo). Login en `/admin/login`
  (`App\Http\Controllers\Admin\AdminAuthController`, formulario simple, `Auth::attempt`, no
  emite token de Sanctum) — `test_login_web_crea_una_sesion_independiente_del_token_sanctum_de_la_api`
  confirma explícitamente que `personal_access_tokens` sigue en 0 tras un login web.
- **`App\Http\Middleware\EnsureUserHasRole` es el mismo middleware que ya usaba la API**
  (`role:admin|cobrador`), extendido para no reimplementar la condición de rol dos veces: si
  `$user` no tiene el rol pedido, responde JSON 403 cuando `$request->is('api/*')`, o si no
  (panel web) cierra la sesión (`Auth::guard('web')->logout()` + invalidar sesión) y redirige a
  `admin.login` con un mensaje flash claro — nunca un 403 crudo sin contexto. Protege TODAS las
  rutas `/admin/*` salvo login (`Route::middleware(['auth', 'role:admin'])` en `routes/web.php`).
- `bootstrap/app.php` configura `$middleware->redirectGuestsTo(fn () => route('admin.login'))`
  — sin esto, un acceso no autenticado a `/admin/*` lanzaría `RouteNotFoundException` al buscar
  la ruta `login` por defecto de Laravel (que no existe en esta app, la única auth por sesión es
  la del panel admin).

### Rutas (`routes/web.php`, prefijo `admin.`)

```
GET|POST /admin/login                    admin.login / admin.login.submit
POST     /admin/logout                   admin.logout
GET      /admin/usuarios                 admin.usuarios.index
GET      /admin/usuarios/crear           admin.usuarios.crear
GET      /admin/usuarios/{usuario}/editar admin.usuarios.editar
GET      /admin/resumen                  admin.resumen
GET      /admin/resumen/{usuario}        admin.resumen.detalle   (drill-down de un cobrador)
GET      /admin/configuracion            admin.configuracion
GET      /admin/auditoria                admin.auditoria         (solo lectura)
GET|POST /admin/exportar                 admin.exportar / admin.exportar.descargar
```

Layout base (`resources/views/admin/layout.blade.php`) con sidebar: los 5 enlaces (Usuarios,
Resumen, Configuración, Auditoría, Exportar) están todos activos y enlazados — ninguno quedó
como placeholder.

### Services compartidos con la API móvil (extraídos de los controllers `Api\Admin\*`)

Mismo patrón en los cuatro: la lógica vivía embebida en un controller de
`App\Http\Controllers\Api\Admin\*`; se extrajo a un Service para que tanto ese controller (que
ahora es un delegado delgado, mismas respuestas/tests) como los componentes Livewire lo llamen
**directo, en el mismo proceso, sin pasar por HTTP interno**:

- **`App\Services\UsuarioAdminService`**: crear/actualizar/desactivar/reactivar usuarios
  (extraído de `AdminUsuarioController`), incluida la auditoría vía `AuditoriaLogger` y las
  protecciones ya existentes (PIN por defecto `"0000"`, `activo` nunca editable por
  `actualizar()`, un admin no puede desactivarse a sí mismo). Lanza
  `App\Exceptions\UsuarioAdminException` para esas dos reglas de negocio — capturada distinto
  en cada lado (422 en la API, mensaje de formulario en Livewire).
- **`App\Services\CapitalService::asignar()`** (junto al ya existente `calcularSaldoDisponible()`):
  extraído de `AdminCargaCapitalController`. Lanza `App\Exceptions\SaldoInsuficienteException`
  si un `retiro` excede el saldo disponible del cobrador destino — mismo manejo que
  `UsuarioAdminException` (422 API / mensaje de formulario web).
- **`App\Services\ResumenAdminService`**: todo lo de `GET /api/admin/resumen` (los 6 campos
  global/por cobrador) más las consultas de drill-down exclusivas del panel web —
  `clientesConConteo()` (badge "pagados/totales", **no** "activos/totales", mismo criterio ya
  corregido del lado móvil), `prestamosDeCobrador()` (con título "Cliente - Referencia",
  "extra cobrado" y fecha de pago real por cuota ya calculados — misma lógica de
  `admin_models.dart`/`admin_cobrador_detalle_screen.dart` del móvil, replicada en PHP porque
  esa lógica vive en Dart y no es reutilizable desde el backend), `cargasCapitalDeCobrador()` y
  `historialPagosAgrupado()` (ver bullet de `HistorialPagosScreen` en la sección de pagos móvil).
- **`App\Services\ConfiguracionAdminService`**: lectura/escritura de `configuracion_global`
  (extraído de `AdminConfiguracionController`), mismo manejo de `pin_maestro: null` explícito
  para borrarlo vs. no incluir la clave para no tocarlo.

`App\Support\Dinero::formatear()` (formato de dinero para las vistas Blade, mismo criterio que
`formatearMoneda()` del móvil — sin decimales, separador de miles con punto, prefijo `$ `) y
`App\Support\AuditoriaPresentador::datosSeguros()` (oculta cualquier clave que mencione "pin" en
`datos_anteriores`/`datos_nuevos` antes de mostrarlos en el visor de auditoría — puramente de
presentación, `AuditoriaLogger` ya garantiza que un PIN nunca debería llegar a guardarse en
crudo) son los únicos helpers de presentación nuevos, sin lógica de negocio.

### Componentes Livewire (`App\Livewire\Admin\*`, vistas en `resources/views/livewire/admin/*`)

Convención: multi-file components (`--mfc --class`, generados con `php artisan make:livewire`),
namespace `App\Livewire\Admin\<Módulo>\<Nombre>`. Cada página Blade (`resources/views/admin/*`)
extiende `admin.layout` y solo hace `@livewire('admin.modulo.nombre', [...])`.

- **`Usuarios\Index`/`Usuarios\Formulario`**: listado (cobradores y admins, estado
  activo/inactivo) y un solo componente de formulario para crear/editar (según si `?User
  $usuario` llega en `mount()`) — llaman a `UsuarioAdminService`, nunca reimplementan sus
  reglas. **Gotcha real corregido**: un campo de PIN vacío en el formulario Livewire (`pin =
  ''`, nunca realmente ausente como en un request HTTP) no disparaba el default `"0000"` de
  `UsuarioAdminService::crear()` (que usa `?? '0000'`, solo dispara con `null`) — hay que
  normalizar explícitamente `''` a `null` antes de llamar al Service.
- **`Resumen\Index`**: totales globales + tabla por cobrador (filas clickeables →
  `admin.resumen.detalle`).
- **`Resumen\DetalleCobrador`**: drill-down de un cobrador en 4 pestañas (Alpine.js
  `x-data`/`x-show`, sin round-trip de Livewire para cambiar de pestaña, porque los 4 datasets
  ya se cargan completos en `render()`): Préstamos (expandible, capital/interés/extras/total/
  pagado/**extra cobrado**/saldo pendiente + cuotas con fecha esperada vs. fecha de pago real),
  Clientes (badge "pagados/totales"), Movimientos de capital (chip visual para `origen = admin`
  vs. `cobrador`, mismo criterio que el chip "Asignado por administrador" de
  `HistorialCapitalScreen` en mobile — **nota**: `HistorialCapitalScreen` ya no tiene botón de
  eliminar, ver sección de capital móvil más abajo, pero este chip visual sigue igual, no era
  el mismo control), Historial de pagos (agrupado por préstamo+`fecha_pago`, resumen corto
  expandible — ver `ResumenAdminService::historialPagosAgrupado()`). Incluye el formulario de
  asignar saldo (carga/retiro + monto + **categoria** + descripción), llamando a
  `CapitalService::asignar()`:
  - **Campo "Monto"**: no es un `<input type="number">` — es un `<input type="text">` con
    Alpine.js (`x-data="{ raw: $wire.entangle('monto'), get display() {...} }"`) que formatea
    con separador de miles (`toLocaleString('en-US')`, coma) **mientras se escribe**, sin
    round-trip a Livewire por cada tecla (`$wire.entangle` sincroniza el valor crudo, no el
    formateado); solo el valor limpio (sin comas) llega a `$wire.monto`. Distinto del criterio
    de "punto" que usa `formatearMoneda()`/`FormateadorDinero` del lado móvil — decisión
    explícita para este campo puntual, no una inconsistencia a corregir.
  - **Campo "Categoría"** (`categoria`, select): solo visible (`x-show="$wire.tipoMovimiento
    === 'retiro'"`) y solo requerido/validado cuando `tipoMovimiento = 'retiro'`
    (`Rule::excludeIf` en las `rules()` del componente — para una carga, el valor del `<select>`
    se descarta sin importar lo que haya quedado seleccionado, así el registro siempre queda
    con `categoria = null`). Mismas 4 opciones que la API (`gasto_operativo`, `decision_jefe`,
    `salario`, `otro`) — ver `cargas_capital.categoria` en la sección del reporte financiero
    más abajo.
- **`Configuracion\Formulario`**: tasas de interés (array editable), política de mora por
  defecto (select), intentos antes del PIN maestro, y el PIN maestro global — **nunca** muestra
  el hash, solo `pin_maestro_configurado` (bool); un campo de texto para uno nuevo y un
  checkbox explícito "Quitar el PIN maestro actual" que manda `null` (distinto de dejar el
  campo vacío, que no cambia nada) — mismo comportamiento que `AdminConfiguracionScreen` del
  móvil y que la API.
- **`Auditoria\Index`**: listado paginado (`Livewire\WithPagination`) de `auditoria`, filtro por
  `accion` (select) y rango de fecha — puramente de consulta, **sin ningún método de
  mutación** en el componente. El detalle de `datos_anteriores`/`datos_nuevos` de cada fila pasa
  por `AuditoriaPresentador::datosSeguros()` antes de mostrarse.
- **Exportar (`/admin/exportar`) es la única pantalla del panel que NO usa Livewire a
  propósito**: es un `<form>` HTML plano que hace POST directo a
  `App\Http\Controllers\Admin\AdminExportarController@descargar`, para que la descarga sea una
  respuesta HTTP normal (`Content-Disposition: attachment`) en vez de depender de streaming vía
  AJAX. Ya no genera un `.csv`: desde la fase del "reporte financiero" genera un **`.xlsx` de 3
  hojas** (`maatwebsite/excel`, `Excel::raw()` — devuelve los bytes directo, sin tocar disco).
  Filtro nuevo de **categoria** (select, mismas 4 opciones que `cargas_capital.categoria`) que
  solo afecta la Hoja 3. Ver la sección "Reporte financiero (.xlsx web / CSV mobile)" más abajo
  para el detalle completo de las 3 hojas y por qué se abandonó el CSV plano en la web.

### Tests (`backend/tests/Feature/Admin/*LivewireTest.php`, `AdminPanelAccessTest.php`)

Cada módulo tiene tests mínimos usando `Livewire::actingAs($admin)->test(Componente::class)`
— no se duplicó la cobertura ya existente de los controllers `Api\Admin\*` (que siguen
pasando sin cambios tras cada extracción a Service). `AdminPanelAccessTest` cubre el guard/
middleware: guest redirigido, admin entra, cobrador rechazado con mensaje y sesión cerrada.

## Reporte financiero: categoría de retiros y exportación (.xlsx en los 3 frentes: web, admin mobile, cobrador mobile)

### `cargas_capital.categoria`

Migración `add_categoria_to_cargas_capital_table`: enum nullable (`gasto_operativo`,
`decision_jefe`, `salario`, `otro`), después de `tipo`. Solo aplica a un **retiro**; para una
`carga` siempre queda `null`, sin importar lo que mande el cliente — reforzado con el mismo
criterio en 3 lugares, no uno solo (`Rule::excludeIf(fn () => tipo !== 'retiro')` +
`required`/`in:...` cuando sí aplica):
- `StoreAdminCargaCapitalRequest` (`POST /api/admin/cargas-capital`).
- `App\Livewire\Admin\Resumen\DetalleCobrador::rules()` (formulario "Asignar saldo" web).
- `CapitalService::asignar()` recibe `categoria` como parámetro opcional y fuerza `null` si
  `$tipo !== 'retiro'` como última línea de defensa.

**Fuera de alcance a propósito**: `StoreCargaCapitalRequest` (la ruta del propio cobrador,
`POST /cargas-capital`) y el lado móvil (`AgregarCapitalScreen`/`CargasCapitalRepository`) **no**
tienen este campo — `categoria` es exclusivamente una clasificación que hace el admin al
asignar/retirar saldo, no algo que el cobrador declare sobre sus propios movimientos.

### `ExportarReporteService`: una sola fuente de verdad para 2 formatos

`datosReporte(array $usuarioIds, ?Carbon $desde, ?Carbon $hasta, ?string $categoriaCapital):
array` es el método central — arma los 3 bloques (`prestamos`, `resumen_por_cobrador`,
`movimientos_capital`), cada uno como `{titulo, columnas, filas}` (filas ya en el mismo orden
que las columnas, sin formatear: números crudos, sin símbolo de moneda). **Dos consumidores, un
solo cálculo**:
- `generarXlsx(...)` (panel web, `/admin/exportar`): llama a `datosReporte()` y arma un
  `App\Exports\Admin\ReporteAdminExport` (`WithMultipleSheets`) con 3
  `App\Exports\Admin\ArraySheetExport` (clase genérica reutilizable — no 3 clases casi
  idénticas), devuelve `Excel::raw($export, Excel::XLSX)` (bytes directo, sin tocar disco).
- `GET /api/admin/reporte` (`App\Http\Controllers\Api\Admin\AdminReporteController`, móvil):
  llama al mismo `datosReporte()` y lo devuelve tal cual como JSON.

Si se necesita ajustar una fórmula o agregar una columna, **tocar solo `datosReporte()`** (o los
métodos privados `filasPrestamos()`/`filasResumenCobrador()`/`filasMovimientosCapital()` que
llama) — nunca duplicar el cálculo en el controller de la API ni en el de la web.

**Hoja/bloque 1 — Detalle de préstamos** (`Cobrador, Cliente, Cédula, Capital, % Interés, Valor
de cada cuota, Ganancia, Capital + Interés (sin extras), Plazo (cuotas), Frecuencia de pago,
Estado`): todos los préstamos existentes de los cobradores filtrados, **sin importar estado ni
fecha_inicio** — el rango de fechas del formulario NO aplica acá (a propósito: es un detalle
punto-en-el-tiempo, no una evolución; ver Hoja 2 para eso). "Ganancia" es
`gananciaDePrestamo($prestamo)` sin rango (interés + extra, histórico completo de ESE préstamo,
no el total del cobrador). Reutiliza `ResumenAdminService::prestamosDeCobrador()`.

**Hoja/bloque 2 — Resumen por cobrador** (`Cobrador, Cartera pendiente al inicio, Total cobrado
en el periodo, Total prestado en el periodo, Cartera pendiente al final, Ganancia por interés
(periodo), Ganancia por extra (periodo)`): evolución **dentro** del rango filtrado.
- "Cartera pendiente al inicio/al final" (`ExportarReporteService::carteraPendienteAlCorte()`):
  reconstrucción histórica, no el estado actual de las cuotas — suma el saldo pendiente
  (`monto_esperado - Σpagos.monto_aplicado con fecha_pago hasta ese corte`) de las cuotas cuya
  `fecha_esperada` es anterior (o anterior-o-igual, para "al final") al corte. Si `desde` es
  `null`, "al inicio" es `0` (no hay nada "antes" de un rango sin arrancar); si `hasta` es
  `null`, "al final" usa `Carbon::now()` como corte.
- "Total cobrado en el periodo"/"Total prestado en el periodo": `Σpagos.monto_aplicado`/
  `Σprestamos.monto_capital` filtrados por `fecha_pago`/`fecha_inicio` dentro del rango.
- "Ganancia por interés/extra (periodo)": `Σ gananciaDePrestamo($prestamo, $desde, $hasta)`
  sobre todos los préstamos del cobrador — a diferencia de la Hoja 1, acá sí se acota a los
  pagos con `fecha_pago` en el rango.

**Hoja/bloque 3 — Movimientos de capital** (`Cobrador, Fecha, Tipo, Monto, Categoría,
Descripción, Origen`): una fila por `cargas_capital` de los cobradores filtrados, con
`created_at` dentro del rango y, si se dio, filtrada además por `categoria` (el filtro
naturalmente no afecta las `carga`, porque esas siempre tienen `categoria = null`).

**Bug real encontrado y corregido**: `PhpSpreadsheet\Worksheet::fromArray()` compara cada valor
contra `null` con `!=` (comparación floja) por defecto — y en PHP `0.0 != null` es `false` (son
"iguales" con comparación floja), así que cualquier celda con el número **0** quedaba en blanco
en vez de mostrar "0" (se detectó con los totales en cero de la Hoja 2). Se corrigió
implementando `Maatwebsite\Excel\Concerns\WithStrictNullComparison` en `ArraySheetExport` —
**cualquier Export nuevo basado en `FromArray` con datos que puedan ser exactamente `0` debe
implementar esta interfaz también**, si no, no hay warning ni error, la celda simplemente sale
vacía.

### `GET /api/admin/reporte` (móvil) — descarga el `.xlsx` binario tal cual, ya no JSON

Decisión revisada (antes devolvía JSON con los 5 bloques y `AdminReportesRepository` armaba su
propio CSV en Dart): ahora `Api\Admin\AdminReporteController::index()` responde el mismo
`.xlsx` binario que ya arma `ExportarReporteService::generarXlsx()` para el panel web
(`Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`,
`Content-Disposition: attachment`) — mismos filtros `usuario_ids[]`/`desde`/`hasta`/`categoria`,
protegido por `role:admin` igual que el resto de `/api/admin/*`. `AdminReportesRepository`
(mobile) ya no genera ni parsea nada: `ApiClient.getBytes()` descarga los bytes tal cual y
`exportarArchivoYCompartir()` (`core/utils/archivo_exportador.dart`) los escribe a un archivo
temporal y los comparte con `share_plus` — el panel admin nunca trabaja offline (ver más abajo),
así que no hay ninguna razón para generar el archivo en el dispositivo. `ReporteAdminFinanciero`/
`SeccionReporte` (los modelos que parseaban el JSON viejo) se eliminaron del todo: no tenían
ningún otro consumidor.

## Sincronización con la app móvil (backend)

`POST /api/sync` (`App\Http\Controllers\Api\SyncController`, `App\Services\SyncService`) recibe
el batch de `clientes`/`prestamos`/`pagos`/`cargas_capital` pendientes que la app arrastra en su
cola local `cambios_pendientes`. Ver `API.md` para el contrato completo del request/response;
acá quedan las decisiones de diseño que no son obvias del código.

- **`uuid_local`** (columna nueva, nullable, en `clientes`/`prestamos`/`pagos`/`cargas_capital`)
  es la clave de deduplicación: la genera la app al crear el registro localmente. Sirve para
  dos cosas a la vez: decidir si un registro ya se recibió antes (reintento tras un corte a
  mitad de sync) y resolver las referencias cruzadas **dentro del mismo batch**
  (`prestamos[].cliente_uuid_local`, `pagos[].prestamo_uuid_local`) sin que la app tenga que
  aprenderse ids del servidor — coherente con que el resto de la app es offline-first.
  Único junto con `usuario_id` en clientes/prestamos/cargas_capital; en `pagos` es único junto
  con `prestamo_id` en su lugar, porque `pagos` no tiene columna `usuario_id` propia (ver nota
  ya existente sobre esto en la sección de reglas de negocio de pagos).
- **Pagos: `PagoProcessor.php` NO se vuelve a correr sobre lo que llega por sync.** Cada
  registro de `pagos[]` ya trae `monto_aplicado`, `dias_mora`, `saldo_restante_despues` y
  `cuotas_afectadas` (qué cuotas cambiaron de estado/`monto_esperado` como resultado del pago,
  identificadas por `numero_cuota` — no por id, porque `PrestamoCalculator`/su réplica en Dart
  generan siempre las mismas cuotas 1..N en ambos lados) calculados por el equivalente en Dart
  del mismo servicio. `SyncService` solo persiste esos valores tal cual y aplica
  `estado_prestamo` (también recibido, no recalculado) al préstamo. `PagoProcessor.php` sigue
  siendo la única fuente de verdad para pagos creados directo contra `POST /pagos` (fuera de
  sync) — no reimplementar su lógica de mora/excedente acá.
- **Reconciliación es deliberadamente angosta, no un PATCH genérico**: cuando un `uuid_local` de
  `prestamos` ya existe, el único campo que se reconcilia es `politica_mora` (el único que la
  app realmente vuelve a encolar como `actualizar` — ver `PagosRepository.registrar` en
  Flutter). El resto de un préstamo (capital, interés, cuotas) nunca se reescribe después de
  creado. `clientes` sí acepta reconciliar todos sus campos editables (coherente con que
  `ClientesRepository.actualizar()` sí permite edición completa). `cargas_capital` no
  reconcilia nada — solo crea o confirma que ya existe — porque no hay flujo de edición de una
  carga ya sincronizada desde el móvil.
- **Conflictos** (`clientes`/`prestamos` con el mismo `uuid_local` pero contenido distinto):
  gana quien tenga `actualizado_en` más reciente comparado contra `updated_at` del registro ya
  guardado. Si gana el que ya estaba guardado (el cambio entrante llegó con fecha más vieja o
  igual), se descarta el entrante y se registra `auditoria` (`accion = conflicto_resuelto`,
  `datos_anteriores` = versión perdedora, `datos_nuevos` = versión ganadora) — nunca se lanza
  una excepción por esto, es un resultado de negocio esperado, no un error.
- **Validación de forma vs. resultado de negocio**: `StoreSyncRequest` solo valida tipos/formas
  (lo mismo que `StoreClienteRequest`/`StorePrestamoRequest`/etc., más `uuid_local`); un fallo
  ahí es 422 para todo el batch (bug real del cliente). Referencias cruzadas rotas
  (`cliente_uuid_local` que no aparece ni en este batch ni en la base) y conflictos **no** son
  422 — son un `estado: "error"`/`"conflicto"` por registro dentro de una respuesta 200, porque
  son resultados esperados de una sincronización real, no errores de formato.
- **`configuracion` viaja en la misma respuesta de `/sync`** (no es un endpoint aparte) para que
  el móvil no gaste un segundo viaje de red: mismas claves que `GET /admin/configuracion`
  (`tasas_interes_default`, `politica_mora_default`, `pin_maestro_configurado`,
  `intentos_pin_antes_de_maestro`), **sin** el hash del PIN maestro — eso sigue siendo
  exclusivo de `GET /pin-maestro`, no se duplica acá.
- **`cargas_capital`: `origen` (`cobrador`|`admin`) y `creado_por_usuario_id`** distinguen un
  aporte/retiro que el propio cobrador registró (vía `/cargas-capital` o `/sync`, `origen`
  siempre `cobrador`, `creado_por_usuario_id` siempre `null`) de uno que un admin le asignó
  directamente (`POST /admin/cargas-capital`, `App\Http\Controllers\Api\Admin\AdminCargaCapitalController`,
  `origen = admin`, `creado_por_usuario_id` = id del admin). El admin gestiona sus propios
  cobradores igual que en el resto del panel admin (sin Policy de objeto, la única barrera es
  `role:admin` — mismo patrón que el resto de `/admin/*`).
- **`cargas_capital.tipo` (`carga`|`retiro`, default `carga`)** no estaba pedida en el encargo
  original de esta tarea de sync, pero se agregó como gap-fill necesario: el lado móvil
  (Drift) ya tenía este campo de una fase anterior (retiros de capital), y sin la columna en el
  servidor ni `POST /admin/cargas-capital` ni `POST /sync` podían aceptar/persistir un retiro.
- **Bug real encontrado y corregido de paso**: el modelo `CargaCapital` nunca definió
  `protected $table`, así que Eloquent infería `carga_capitals` (pluraliza "CargaCapital" como
  una sola palabra) en vez de `cargas_capital` (el nombre real de la tabla, ver
  `create_cargas_capital_table`). No se había detectado porque no existía ningún test
  automatizado tocando este modelo hasta los tests de esta tarea — cualquier interacción real
  vía Eloquent con `cargas_capital` (incluida `POST /cargas-capital`, la ruta de cobrador que
  ya existía) estaba silenciosamente rota antes de este fix.

## Recuperación de datos ante dispositivo nuevo (`GET /api/restaurar`)

Para cuando un cobrador entra en un dispositivo nuevo (o reinstaló la app) y su Drift local
está vacío — caso distinto de `POST /api/sync` (incremental): acá el móvil no sube nada, solo
descarga de una vez **todo** lo que ya existe en el servidor para ese cobrador.

- **Backend** (`App\Http\Controllers\Api\RestaurarController`, protegido por
  `auth:sanctum` + `role:cobrador`, sin Service propio — es solo lectura, no hay lógica de
  negocio que extraer): devuelve `clientes` (no eliminados), `prestamos` (con `extras`/`cuotas`
  anidadas), `pagos` (lista plana de todos los pagos de esos préstamos, no anidados bajo cada
  préstamo — a propósito, para que el móvil no tenga que recorrer préstamo por préstamo) y
  `cargas_capital`, todo filtrado por `usuario_id` del cobrador autenticado (nunca de otro).
  Serialización de modelos Eloquent tal cual, mismo criterio que el resto de `/api/admin/*` (sin
  Resource/Transformer propio). Antes de devolver `cargas_capital`, marca `descargado = true`
  en las de `origen = admin` pendientes — mismo campo y mismo criterio que ya usa
  `SyncService::cargasCapitalAdminPendientes()`, para que el siguiente `POST /sync` no las
  vuelva a ofrecer como si fueran nuevas.
- **Móvil** (`RestauracionRepository`, `mobile/lib/features/sincronizacion/data/`): inserta todo
  ya con `sincronizado = true` y el mismo `servidorId`/`uuidLocal` que trae cada registro —
  **nunca** encola nada en `cambios_pendientes` (esto no es un cambio local pendiente de subir,
  ya está sincronizado por definición). Idempotente: si el proceso se corta a mitad de camino y
  se reintenta, cada registro se busca primero por `uuid_local` antes de insertarlo — igual que
  cuotas/extras/cargas de origen `admin` (que no tienen `uuid_local` propio) se buscan por
  `servidorId`, mismo criterio que ya usa `CargasCapitalRepository.guardarDescargadaDeAdmin()`.
  Preserva `creadoEn`/`actualizadoEn` del servidor (`created_at`/`updated_at` del JSON) en vez
  de dejar el default `currentDateAndTime` de Drift, para no distorsionar el orden de
  `HistorialCapitalScreen` (que ordena por `creadoEn`).
- **Gotcha real corregido**: los campos `decimal:N` de Eloquent (`monto_capital`,
  `porcentaje_interes`, `valor` de extras, `monto_esperado`, `monto_abonado`/`monto_aplicado`/
  `saldo_restante_despues`) llegan en el JSON como **string** (ej. `"100000.00"`), no como
  número — un cast directo `as num`/`as double` revienta apenas el valor llega como `String`.
  Se corrigió con un helper único, `mobile/lib/core/utils/json_numero.dart` (`comoDouble()`),
  reutilizado también por `admin_models.dart` (antes tenía su propia copia privada duplicada de
  la misma función) — **cualquier parseo nuevo de un JSON del backend con campos decimales debe
  usar este helper**, no un cast directo.
- **Detección y disparo** (`mobile/lib/app.dart`, `AppEntryPoint`): justo después de un login
  exitoso (no en cada reapertura de la app, para no ser invasivo), si `RestauracionRepository.
  hayDatosLocales()` es `false` (la tabla `clientes` está vacía para el `usuario_id` activo, y
  solo para rol `cobrador` — el panel admin no trabaja offline, no tiene nada que restaurar) se
  muestra `RestaurarDatosScreen` antes del dashboard, con "Restaurar mis datos" o "Continuar sin
  restaurar" (útil sin conexión). Si el cobrador sigue sin datos, `DashboardScreen` muestra
  además un botón "Restaurar datos" en la tarjeta de sincronización (mismo lugar que
  "Sincronizar") mientras `hayDatosLocales()` siga siendo `false` — se oculta solo apenas tenga
  algún cliente local.

## App móvil: autenticación y bloqueo (`mobile/lib/features/auth`)

- `AuthRepository` (login/logout) y `BloqueoRepository` (PIN personal, biometría, PIN
  maestro) son las dos piezas de datos del módulo; las pantallas
  (`login_screen.dart`, `bloqueo_config_screen.dart`, `bloqueo_screen.dart`) solo llaman a
  estos repositorios, no tienen lógica propia de negocio.
- Todo lo sensible (token de Sanctum, hash del PIN personal, hashes de PIN maestro,
  preferencia de biometría, contador de intentos fallidos) vive en `flutter_secure_storage`
  (`core/storage/secure_storage_service.dart`) — **nunca** en `SharedPreferences` ni en la
  base de datos Drift.
- El **PIN personal** (4-6 dígitos) es local al dispositivo: se hashea con `bcrypt`
  (paquete `bcrypt`, no nativo) y **no se sincroniza con el backend** — es un concepto
  distinto de `users.pin_hash` (que sigue siendo el PIN que gestiona el admin vía
  `PUT /api/admin/usuarios/{id}`, sin relación con el bloqueo local de la app todavía). Si
  más adelante se quiere unificar ambos, es una decisión de producto pendiente, no un bug.
- El **PIN maestro** se descarga vía `GET /api/pin-maestro` (ver sección de PIN maestro más
  arriba) y se guarda cifrado; funciona offline hasta la siguiente sincronización exitosa.
  Ahora mismo `AuthRepository.sincronizarPinMaestro()` se llama justo después del login; el
  próximo módulo que implemente sincronización general de datos debe llamarlo también ahí.
- **`intentosMaximosPinPersonal` ya no es una constante**: cuántos intentos fallidos del PIN
  personal tolera `BloqueoScreen` antes de ofrecer el PIN maestro es configurable por el admin
  (`configuracion_global.intentos_pin_antes_de_maestro`, editable desde
  `AdminConfiguracionScreen`) y se descarga en el mismo `GET /api/pin-maestro` de arriba
  (`SecureStorageService.guardarIntentosMaximosPin`/`leerIntentosMaximosPin`, default `3` si
  el dispositivo nunca ha sincronizado). `BloqueoRepository.obtenerIntentosMaximosPin()` es
  ahora un método de instancia async, no un `static const` — `BloqueoScreen` lo carga una vez
  en `_inicializar()` y lo guarda en `_intentosMaximos`.
- `AppEntryPoint` (`mobile/lib/app.dart`) es el único lugar que decide qué pantalla mostrar
  (login → configurar bloqueo → bloqueo → dashboard) y el que re-exige el bloqueo cuando la
  app vuelve de segundo plano (`WidgetsBindingObserver`). No es un router de verdad, es
  render condicional sobre banderas de estado en memoria (`_haySesion`,
  `_bloqueoConfigurado`, `_desbloqueada`) — si se agrega un router (go_router, etc.) más
  adelante, esta lógica de "gate" debe migrar con cuidado de no perder el re-bloqueo al
  volver de segundo plano.
- `local_auth` (biometría) requiere que `MainActivity` (Android) extienda
  `FlutterFragmentActivity`, no `FlutterActivity` (ya configurado), y `minSdk >= 23`
  (forzado en `android/app/build.gradle.kts` con `maxOf(flutter.minSdkVersion, 23)`).
- **Gotcha ya corregido**: `ApiClient.logout()` llama al `http.Client` directo, sin pasar por
  `_procesar()` — por diseño, para no fallar si el servidor responde con un error de estado
  (no nos importa la respuesta). Pero eso significa que nunca lanza `ApiException`; un fallo
  real de conexión (sin internet, backend caído) lanza una excepción de red distinta
  (`SocketException`, `TimeoutException`, etc.). `AuthRepository.cerrarSesion()` debe atrapar
  **cualquier** excepción ahí (`catch (_)`, no `on ApiException`), porque cerrar sesión tiene
  que limpiar el token local sí o sí, sin conexión. Un `catch` demasiado específico en
  cualquier llamada de red que se considere "best effort" (revocar token, sincronizar algo
  en segundo plano) es el mismo error en potencia — repasar esto si se agregan más llamadas
  "best effort" en el futuro. Cubierto por
  `test/features/auth/auth_repository_test.dart` (fuerza un fallo de red real con un
  `http.BaseClient` falso y verifica que el token se borra igual, sin tocar el PIN maestro).
- `BloqueoScreen` tiene una salida alterna ("Cerrar sesión e iniciar con otra cuenta") además
  del flujo normal de biometría/PIN — usa la misma `AuthRepository.cerrarSesion()` que el
  botón del dashboard (vía el callback `onCerrarSesion` que le pasa `AppEntryPoint`), con un
  diálogo de confirmación porque esta pantalla se ve en cada apertura/reanudación de la app y
  un toque accidental no debería cerrar una sesión válida.
- **Verificación de rol tras el login**: `AppEntryPoint` (`mobile/lib/app.dart`) es el único
  lugar que decide si mostrar el dashboard de cobrador o el panel de admin (`AdminPanelScreen`,
  ver sección "App móvil: panel de administrador" más abajo), comparando `_rol` (leído de
  `AuthRepository.rolUsuarioActual()`, que viene de `SecureStorageService.leerRol()`) contra
  `'admin'`. Este chequeo se re-evalúa tanto en login fresco (`_alIniciarSesionExitoso`) como
  al reabrir una sesión ya guardada (`_evaluarEstadoInicial`, en frío) — por diseño **no** hay
  chequeo de rol en `BloqueoScreen` ni en pantallas de cobrador/admin individuales: el único
  punto de entrada a esas pantallas es el `build()` de `AppEntryPoint`, así que gatear ahí es
  suficiente mientras no exista navegación/deep-linking directa a
  `ClientesListScreen`/`PrestamoFormScreen`/`AdminUsuariosListScreen`/etc. Si eso cambia,
  revisar si hace falta un segundo chequeo.
- `AppEntryPoint`, `BloqueoScreen` y `BloqueoConfigScreen` aceptan sus repositorios
  (`AuthRepository`/`BloqueoRepository`) como parámetro opcional del constructor (`late final
  _x = widget.x ?? XReal()`), con la instancia real como default. Esto es lo que permite
  testear el flujo completo con dobles de prueba en
  `test/app_role_gating_test.dart` — antes de este cambio, `BloqueoScreen` y
  `BloqueoConfigScreen` construían su propio `BloqueoRepository()` por dentro, así que un
  repositorio falso pasado únicamente a `AppEntryPoint` nunca llegaba a la pantalla real. Si
  se agregan más pantallas de auth, seguir el mismo patrón de inyección opcional.
- **`ConfiguracionSeguridadScreen`** (`presentation/configuracion_seguridad_screen.dart`):
  a diferencia de `BloqueoConfigScreen` (solo se ve una vez, justo tras el primer login),
  esta pantalla es accesible en cualquier momento — ícono de ajustes (`Icons.security`) en el
  `AppBar` de `DashboardScreen` (cobrador) **y también** en `AdminPanelScreen` (admin, mismo
  ícono, misma pantalla — el bloqueo es una configuración del dispositivo, no del rol, así que
  no necesitó ningún cambio para servir a ambos). Reutiliza **exactamente** la misma lógica de
  `BloqueoRepository` que ya usa `BloqueoConfigScreen`/`BloqueoScreen` (biometría y PIN
  personal) — no reimplementa nada nuevo, solo expone los mismos controles fuera del flujo de
  setup inicial:
  - Toggle de biometría: si el dispositivo no la tiene configurada a nivel de sistema
    (`biometriaDisponibleEnDispositivo()` en `false`), el `SwitchListTile` queda deshabilitado
    (`onChanged: null`) con un mensaje explicando que hay que activarla primero en los ajustes
    del teléfono — nunca queda en un estado inconsistente ni crashea. Al desactivarla,
    `BloqueoScreen` la vuelve a leer (`false`) la próxima vez que se bloquee la app y cae
    directo al flujo de PIN personal, sin intentar biometría.
  - "Cambiar PIN personal" (diálogo separado, `_DialogoCambiarPin` en el mismo archivo): pide
    el PIN actual (verificado con `BloqueoRepository.verificarPinPersonal`, la misma
    verificación que usa `BloqueoScreen` para desbloquear), luego el nuevo PIN con las mismas
    reglas de `BloqueoConfigScreen` (4 a 6 dígitos) y lo guarda con
    `configurarPinPersonal()` (bcrypt) solo si el PIN actual fue correcto. No toca el PIN
    maestro (individual ni global) para nada.
  - **Gotcha de UI ya corregido**: el `AlertDialog` de cambiar PIN no tenía scroll — cuando
    aparece el teclado y el espacio disponible se reduce, el `Column` de 3 campos se
    desbordaba por unos pocos píxeles (franja amarilla/negra de overflow). Se corrigió
    envolviendo el `Form` en un `SingleChildScrollView`. Cualquier `AlertDialog`/diálogo nuevo
    con varios `TextFormField` debe seguir este mismo patrón.

## App móvil: clientes (`mobile/lib/features/clientes`)

- `ClientesRepository` es la única puerta de entrada al CRUD local de clientes; las
  pantallas (`clientes_list_screen.dart`, `cliente_form_screen.dart`) no tocan `ClientesDao`
  directamente. Cada `crear()`/`actualizar()` exitoso encola una fila en
  `cambios_pendientes` (payload en JSON) para el futuro botón de sincronización.
- **Duplicados de nombre/cédula se validan localmente**, en Dart, contra SQLite —
  independiente de la validación del backend (fase de sincronización). Están scoped por
  `usuarioId` (igual que la restricción del backend), así que solo choca contra clientes del
  mismo cobrador.
- Búsqueda (`ClientesRepository.buscar`): siempre por nombre (`LIKE`); si el texto contiene
  algún dígito, **además** busca por cédula y agrega esos resultados al final sin duplicar
  filas. No es "nombre, y si no hay resultados cédula" (así funciona el buscador del backend
  en `GET /api/clientes?q=`) — son búsquedas distintas a propósito, una es local/inmediata y
  la otra ya filtró contra el servidor.
- La foto (`fotoUrl`) se guarda como **ruta de archivo local** (copiada a
  `ApplicationDocumentsDirectory/fotos_clientes/` vía
  `core/utils/almacenamiento_fotos.dart`, nunca se usa el path temporal de `image_picker`
  directamente) hasta que se sincronice y el backend devuelva una URL real.
- **Gotcha de Drift**: `update(tabla).replace(companion)` exige que *todas* las columnas
  requeridas sin default estén presentes en el companion (lanza `InvalidDataException` si
  falta alguna), no es un update parcial pese al nombre. Para actualizar solo algunos campos
  usar `(update(tabla)..where((t) => t.id.equals(id))).write(companion)` (ver
  `ClientesDao.actualizar`). Ya se corrigió el mismo patrón en `PrestamosDao`,
  `PrestamosExtrasDao`, `CuotasDao` y `PagosDao` — cualquier DAO nuevo que necesite
  `actualizar()` debe seguir ese mismo patrón de `.write()`, no `.replace()`.
- Test de referencia: `test/features/clientes/clientes_repository_test.dart` corre contra
  Drift en memoria (`AppDatabase.paraPruebas(NativeDatabase.memory())`) con un
  `SecureStorageService` de prueba (subclase que fija `leerUsuarioId()`), sin tocar
  `flutter_secure_storage` real. Buen patrón a copiar para testear futuros repositorios.

## App móvil: préstamos (`mobile/lib/features/prestamos`)

- `PrestamoCalculator` (`data/prestamo_calculator.dart`) es una réplica **exacta** en Dart de
  `App\Services\PrestamoCalculator` del backend: mismo interés simple, mismo reparto de
  cuotas (última cuota absorbe el residuo de redondeo) y mismas fechas por frecuencia,
  incluyendo `_sumarMesesSinOverflow` (equivalente a `Carbon::addMonthsNoOverflow`). **Si la
  fórmula cambia en el backend, hay que replicar el cambio aquí también** — no hay forma
  automática de mantenerlos sincronizados. Cubierto por
  `test/features/prestamos/prestamo_calculator_test.dart` con los mismos valores usados para
  verificar el backend (100000 capital, 20%, 5000 extras, 10 cuotas diarias → total 125000).
- `PrestamoCalculadoraFormulario` (`presentation/`) es el widget de UI compartido entre
  "Nuevo préstamo" (`prestamo_form_screen.dart`) y "Simular préstamo"
  (`simular_prestamo_screen.dart`): captura capital/interés/extras/frecuencia/plazo/fecha y
  recalcula en tiempo real (sin botón "calcular"), avisando al padre vía
  `onDatosValidosCambiados` (callback con `null` mientras falten datos). El simulador no le
  pasa nada más; el formulario real además pide un cliente (bottom sheet
  `seleccionar_cliente_sheet.dart`, sobre `ClientesRepository`) y usa esos datos para guardar.
- `PrestamosRepository.crear()` calcula con `PrestamoCalculator`, inserta el préstamo, sus
  `PrestamosExtra` y todas sus `Cuota` (estado inicial `pendiente`) en una sola operación, y
  encola **una sola fila** en `cambios_pendientes` para el préstamo (no una por cuota/extra) —
  el payload JSON lleva todo lo necesario para que la sincronización recree el mismo cálculo
  del lado del servidor.
- `prestamos.referencia` (backend y Drift): texto corto opcional, solo informativo, para que
  el cobrador distinga préstamos cuando un mismo cliente tiene varios (ej. "Préstamo moto").
  No participa en `PrestamoCalculator`. Se muestra en el detalle del préstamo y en "Cobros
  pendientes" como `"Cliente — Referencia"`.
- `CobrosPendientesScreen` (`presentation/cobros_pendientes_screen.dart`): lista préstamos
  `activo`/`en_mora` del cobrador (vía `PrestamosRepository.listarPendientes`, que reutiliza
  `ClientesRepository.buscar` para el buscador) con saldo pendiente y chip "En mora". Tocar un
  ítem abre `PrestamoDetalleScreen` (no salta directo a registrar pago) — desde ahí se usa el
  botón "Registrar pago" que ya existe en esa pantalla.
- Los botones rápidos de interés (10/20/30/40%) están hardcodeados a propósito, tal como se
  pidió — no se leen de `configuracion_global.tasas_interes_default` (eso sigue siendo solo
  informativo para el panel admin).
- **Formato de dinero**: `core/utils/formato_dinero.dart` centraliza tanto el
  `TextInputFormatter` (`FormateadorDinero`, separador de miles con `.` mientras se escribe —
  no coma, para que coincida con `formatearMoneda` y la convención de pesos colombianos) como
  la función de solo-lectura `formatearMoneda()` (usada en la tarjeta de resultado y en
  `PrestamoDetalleScreen`). **Cualquier campo de dinero nuevo en la app** (capital, montos
  extra, y en el futuro `monto_abonado` de pagos, etc.) debe usar
  `inputFormatters: [FormateadorDinero()]` y leer el valor con
  `FormateadorDinero.valorNumerico(controller.text)` — nunca `double.tryParse` directo sobre
  el texto del controller, porque tendría los puntos de separador incluidos. El separador es
  puramente visual: nunca se guarda en Drift ni se envía al backend.

## App móvil: panel de administrador (`mobile/lib/features/admin`)

- A diferencia de clientes/préstamos, **el panel admin no trabaja offline**: no toca Drift ni
  `cambios_pendientes`, cada pantalla llama directo a `/api/admin/*` vía `AdminRepository`
  cada vez que se abre o se refresca (no hay razón de negocio para que un admin gestione
  usuarios/configuración sin conexión). Si eso cambia, tocaría rediseñar el repositorio.
- `ApiClient` ahora expone `get`/`post`/`put` genéricos (además de los métodos específicos de
  auth ya existentes) para que cada feature arme sus propias llamadas tipadas sin duplicar
  manejo de headers/errores — este es el patrón a seguir para pagos u otras features futuras
  que necesiten hablar con el backend fuera de auth.
- `AppEntryPoint` (`mobile/lib/app.dart`) es, de nuevo, el único punto de entrada: si
  `_rol == 'admin'` muestra `AdminPanelScreen` en vez de `DashboardPlaceholderScreen`. Ya no
  existe `AdminNoDisponibleScreen` (se eliminó al construir el panel real).
- `PUT /admin/usuarios/{id}` **nunca** debe recibir `activo` en el body — ese campo es
  exclusivo de `desactivarUsuario()`/`reactivarUsuario()` (rutas separadas). El formulario de
  edición (`AdminUsuarioFormScreen`) arma su propio mapa de `cambios` con solo lo que el admin
  realmente modificó (nombre/email siempre; password solo si no quedó vacío), igual que el
  patrón ya usado en `ClientesRepository`/`PrestamosRepository`.
- **Navegación reorganizada**: el detalle financiero de un cobrador (clientes, préstamos,
  movimientos de capital, historial de pagos, gastos) cuelga de **`AdminResumenScreen`** —
  tocar un cobrador en la tabla "Por cobrador" abre `AdminCobradorDetalleScreen`.
  `AdminUsuariosListScreen` **ya no navega ahí**: volvió a ser solo gestión de cuenta (crear,
  editar, activar/desactivar) — tocar una fila abre el formulario de edición
  (`onTap: onEditar`), no el detalle financiero. Antes ambas pantallas llevaban al mismo
  detalle; se separó porque "gestión de cuenta" y "ver la cartera de un cobrador" son tareas
  distintas del admin, y mezclarlas en un solo listado no dejaba claro cuál era el propósito de
  cada pantalla.
- `AdminCobradorDetalleScreen` es deliberadamente de solo lectura sobre clientes/préstamos (sin
  botones de editar ni eliminar) — el admin puede *ver* la cartera de un cobrador pero el CRUD
  operativo sigue siendo exclusivo del cobrador dueño, desde su propia app. La única acción de
  escritura que sí tiene es el FAB "Asignar saldo" (ver más abajo), que no toca clientes ni
  préstamos. **5 pestañas** (`TabBar`/`TabBarView`, antes era una sola vista larga con todo
  apilado): Préstamos, Clientes, Movimientos de capital, Historial de pagos y Gastos — cada una
  con su propio contador en el header ("Préstamos (N)", etc.), igual que antes tenían como
  sección. `TabBarView` solo construye la pestaña activa (gotcha de test: hace falta
  `tester.tap(find.text('NombrePestaña'))` + `pumpAndSettle()` antes de poder encontrar
  contenido de una pestaña que no sea la primera).
  - **Movimientos de capital**: lista `detalle.cargasCapital` (campo de `DetalleCobrador`,
    poblado por `GET /admin/usuarios/{id}/detalle` — el backend eager-carga la relación
    `User::cargasCapital()` ahí) con el mismo patrón visual que `HistorialCapitalScreen`
    (icono/color por tipo, chip "Asignado por administrador" para `origen = admin`) — mismos
    datos que la pestaña equivalente del panel web (`ResumenAdminService::cargasCapitalDeCobrador()`).
  - **Historial de pagos** (pestaña nueva, no existía antes en mobile — sí en el panel web
    Livewire): agrupa `PrestamoResumen.pagos` de **todos** los préstamos del cobrador por
    (`prestamoId`, `fechaPago`) — misma lógica de agrupamiento/etiquetado ("Pago cuota N",
    "Abono cuota N", "Extra") que `HistorialPagosScreen` del lado cobrador y
    `ResumenAdminService::historialPagosAgrupado()` del panel web, replicada una tercera vez
    acá porque Dart no comparte código privado entre features ni con PHP — si se vuelve a
    tocar el criterio en un lado, replicar el cambio en los otros dos. Requirió agregar
    `id`/`cuotaId`/`diasMora` a `PagoResumen` (antes solo traía fecha/montos/saldo — esos 3
    campos ya venían en el JSON, solo faltaba parsearlos).
  - **Gastos** (pestaña nueva): `detalle.cierresCaja` (campo nuevo de `DetalleCobrador`,
    `CierreCajaResumen`/`GastoCierreCajaResumen`) — poblado por `GET /admin/usuarios/{id}/detalle`,
    que ahora también eager-carga `User::cierresCaja()` con sus `gastos` (antes esa ruta no
    devolvía cierres de caja en absoluto). Una tarjeta expandible por cierre (fecha, capital
    inicio/cierre, total de gastos) que al abrirse muestra la justificación (si hay) y el
    detalle de cada gasto individual.
- **Listado de préstamos y modal de detalle** (pestaña "Préstamos" de `AdminCobradorDetalleScreen`):
  cada ítem del listado (y el título dentro del modal) muestra **"Nombre del cliente - Referencia"**
  (`_tituloPrestamo`, solo el nombre del cliente si no hay referencia), truncado con
  `overflow: TextOverflow.ellipsis`/`maxLines: 1` si es muy largo — **nunca cortar el string a
  mano**. (Bug ya corregido: antes el modal solo mostraba la referencia sola, sin el nombre del
  cliente.) También muestra `monto_total` (del backend, nunca recalculado), `porcentaje_interes`,
  `plazo_cuotas` y `fecha_inicio`. Tocar un préstamo abre un
  `showModalBottomSheet`/`DraggableScrollableSheet` (`_DetallePrestamoModal`, mismo patrón
  visual que `PrestamoDetalleScreen` del lado cobrador, pero reimplementado localmente porque
  Dart no permite importar los widgets privados de esa pantalla) con capital, interés, extras,
  `monto_total`, total pagado, **"Extra cobrado"** y el listado completo de cuotas — **todo sale
  de los datos que ya trajo `GET /admin/usuarios/{id}/detalle`**, sin ninguna llamada de red
  nueva. `PrestamoResumen.montoInteres` se obtiene restando `montoTotal - montoCapital -
  montoExtras` (no recalculando `capital * porcentaje / 100`) para no arriesgar un desajuste de
  redondeo contra el `monto_total` que sí vino calculado del servidor.
  - **Bug real corregido: "Extra cobrado" no se reflejaba en el detalle.** El excedente de un
    pago `cobro_extra` (`monto_abonado - monto_aplicado`, `PrestamoResumen.extraCobrado`) ya lo
    contabilizaba correctamente el dashboard/resumen ("Ganancia realizada"), pero el detalle de
    un préstamo puntual no lo sumaba en ningún total visible. Se agregó una fila "Extra cobrado
    (no aplica a la deuda)" **separada** de "Total original de la deuda" (que debe seguir
    reflejando solo capital+interés+extras configurados, sin este excedente) — mismo criterio
    aplicado en `PrestamoDetalleScreen` del lado cobrador y en el panel web (Livewire).
  - **Fecha de pago real por cuota**: además de `fecha_esperada`, si la cuota ya está `pagada`
    se muestra la fecha real del pago (`CuotaResumen.fechaPago`, la más reciente si una cuota
    recibió más de un pago), en un color distinto (verde) para diferenciarla de la esperada —
    mismo criterio en `PrestamoDetalleScreen` del cobrador y en el panel web.
- **Badge de conteo de préstamos por cliente** (`_BadgeConteoPrestamos`, **"pagados/totales"**):
  se arma en memoria agrupando el array `prestamos` ya descargado por `cliente_id` — "pagados"
  cuenta solo `estado == 'pagado'`, "totales" cuenta cualquier estado sin filtrar. **Bug real ya
  corregido**: antes mostraba "activos/totales" (`activo`+`en_mora` en el numerador), que no es
  lo que el nombre del badge sugiere — no volver a esa definición. No hay ni hace falta un
  endpoint de conteo aparte.
- **Asignar saldo a un cobrador** (`AdminAsignarCapitalScreen`, botón FAB en
  `AdminCobradorDetalleScreen`): mismo patrón visual que `AgregarCapitalScreen` del lado
  cobrador (`SegmentedButton` carga/retiro, `FormateadorDinero`, descripción opcional), pero
  llama a `AdminRepository.asignarCapital()` → `POST /admin/cargas-capital` con el
  `usuario_id` del cobrador que se está viendo (no el admin autenticado). El backend valida que
  un `retiro` no exceda `CapitalService::calcularSaldoDisponible()` del cobrador destino (422
  con mensaje claro si lo excede) — la pantalla solo muestra el error del servidor, no
  reimplementa la validación de saldo en Dart. El mensaje de éxito
  aclara explícitamente que el saldo no llega al dispositivo del cobrador hasta su próxima
  sincronización (`cargas_capital_admin` en la respuesta de `POST /sync`, ver sección de
  sincronización más arriba) — el `SnackBar` de confirmación lo muestra
  `AdminCobradorDetalleScreen` después de que el formulario hace `pop(true)`, no el propio
  formulario (para que sobreviva a la animación de salida de la pantalla). El mismo tipo de
  validación (retiro del propio cobrador, `AgregarCapitalScreen`) se valida **localmente** ahí
  (ver `DashboardRepository.calcularResumen`, offline-first) en vez de esperar el 422 del
  servidor, porque esa pantalla sí trabaja offline.
- **`AdminResumenScreen`** también muestra `ganancia_interes`/`ganancia_extra` y
  `saldo_disponible` (ya calculados por el backend) junto a los campos que ya tenía, tanto en
  la tarjeta global como en la de cada cobrador (`_FilasTotales`, reutilizada en ambos casos).
- **Exportar reporte financiero** (`AdminExportarReporteScreen` + `AdminReportesRepository`):
  rango de fechas + multi-select de cobradores + filtro de categoria (solo afecta la hoja de
  movimientos de capital) — mismo formulario de siempre, **extendido, no reescrito**, más el
  `DropdownButtonFormField` de categoria. Ya no arma nada en Dart: pide `GET /admin/reporte`
  (`AdminRepository.descargarReporteXlsx()`, vía `ApiClient.getBytes()`) y comparte el `.xlsx`
  binario tal cual con `exportarArchivoYCompartir()` — el mismo archivo de 5 hojas que ya
  descarga el panel web en `/admin/exportar` (ver "Reporte financiero (.xlsx web / CSV mobile)"
  más arriba, sección desactualizada en el nombre: mobile también es `.xlsx` ahora). Decisión
  explícita: el panel admin nunca trabaja offline (ver bullets de arriba), así que no hay
  ninguna razón para generar el archivo en el dispositivo — todo el trabajo pesado queda en el
  servidor, reutilizando `ExportarReporteService::generarXlsx()` sin reimplementarlo.
- `AdminCobradorDetalleScreen` y `AdminAsignarCapitalScreen` aceptan su `AdminRepository` como
  parámetro opcional del constructor (mismo patrón de inyección para pruebas que
  `DashboardScreen`/`AppEntryPoint`) — antes solo `AdminAsignarCapitalScreen` lo necesitaba,
  pero se agregó a `AdminCobradorDetalleScreen` también para poder testear el badge de conteo
  con un `AdminRepository` mockeado (`ApiClient(httpClient: MockClient(...))`) en vez de contra
  red real. Si se agregan más pantallas de admin con lógica no trivial, seguir el mismo patrón.
- **Gotcha real de pruebas de widgets con `SegmentedButton`**: tras `tester.enterText(...)` en
  un campo cuyo controller determina si un botón queda habilitado (`onPressed: null` vs. un
  callback), hace falta un `await tester.pump()` antes de `tester.tap()` sobre ese botón — sin
  eso, el árbol de widgets todavía no refleja el `setState` que habilita el botón y el tap cae
  sobre una versión con `onPressed: null` (no lanza error, simplemente no hace nada, y el mock
  HTTP nunca se invoca). Ver `test/features/admin/admin_asignar_capital_screen_test.dart`.
- El PIN maestro global (`AdminConfiguracionScreen`) sigue la misma regla que el resto de la
  app: nunca se lee/muestra en texto plano, solo `pin_maestro_configurado` (bool). Escribir un
  valor nuevo lo reemplaza; el checkbox "Quitar el PIN maestro actual" manda
  `{'pin_maestro': null}` explícito (distinto de no incluir la clave, que significa "no
  cambiar nada").
- `AdminConfiguracionScreen` también edita `intentos_pin_antes_de_maestro` (1-10, default 3)
  — es la misma configuración que usa `BloqueoScreen` del lado cobrador, pero se escribe aquí
  (`PUT /admin/configuracion`) y se **lee** por un endpoint distinto (`GET /pin-maestro`, ver
  sección de PIN maestro) porque un cobrador no puede llamar `/admin/configuracion`.
- Verificado también con un smoke test real contra el backend vivo (`php artisan serve` +
  `curl`) para confirmar que las formas de JSON asumidas en
  `test/features/admin/admin_repository_test.dart` (con `MockClient` de `package:http`)
  coinciden con la implementación actual, no solo con lo documentado en `API.md`.

## App móvil: pagos (`mobile/lib/features/pagos`)

- `PagoProcessor` (Dart) es réplica del `PagoProcessor.php` del backend (mismos 3 escenarios:
  exacto/faltante/excedente, misma cascada de `abono_deuda`, mismo reparto de `sumar_total`).
  **Diferencia a propósito**: en el backend `politica_mora` es fija por préstamo (elegida al
  crearlo); en la app, el cobrador la elige en el momento de cada pago con faltante. Cuando
  elige una distinta a la ya guardada, `PagosRepository.registrar()` también actualiza
  `prestamos.politica_mora` localmente y la re-encola en `cambios_pendientes`, para que quede
  consistente con lo recién aplicado.
- Excedente (`manejo_excedente`): igual que el backend, `abono_deuda` cascada a las siguientes
  cuotas, `cobro_extra` no reduce deuda pero sí es efectivo real (ver saldo disponible abajo).
- `RegistrarPagoScreen`/`PrestamoFormScreen`/`AgregarCapitalScreen` siguen el mismo patrón:
  try/catch alrededor del guardado con mensaje de error visible — un fallo de guardado nunca
  debe quedar silencioso (bug real que ya pasó una vez con la migración de `referencia`).
- **`HistorialPagosScreen`**: agrupa las filas de `pagos` que comparten una misma `fecha_pago`
  (todas vinieron de una sola llamada a `PagosRepository.registrar()`, aunque una cascada de
  `abono_deuda` haya generado varias filas) en una sola línea con un resumen corto (ej. "Cuota 2
  + Extra $ 50.000", o "Cuota 1, 2" si la cascada cubrió varias cuotas completas), expandible
  (`ExpansionTile`) al desglose por fila. Cada fila se etiqueta según cómo la generó
  `PagoProcessor`: **"Pago cuota N"** (el pago exacto/faltante de la cuota principal — la de
  menor `numero_cuota` dentro del grupo), **"Abono cuota N"** (fila de cascada `abono_deuda`
  sobre una cuota siguiente) o **"Extra"** (`monto_abonado != monto_aplicado`, o sea un
  excedente `cobro_extra`). Esta misma lógica de agrupamiento se replicó en PHP para el panel
  web (`ResumenAdminService::historialPagosAgrupado()`, agregando `prestamo_id` a la clave de
  agrupación porque esa vista abarca todos los préstamos de un cobrador, no uno solo como acá) —
  si se vuelve a tocar el criterio de agrupamiento/etiquetado en un lado, replicar el cambio en
  el otro.

## App móvil: dashboard, capital y reportes — "Fase 10" (`mobile/lib/features/{dashboard,capital}`)

Todo se calcula **desde Drift local**, nunca pidiéndole nada al backend (mismo criterio
offline-first que clientes/préstamos/pagos). `cargas_capital` es tabla nueva (backend con
migración + `POST /cargas-capital`, sin `GET`; local en Drift) para que el cobrador registre
movimientos de capital: aportes (`tipo = 'carga'`) y retiros (`tipo = 'retiro'`), monto siempre
positivo, el signo lo da `tipo` (mismo patrón que `monto_abonado` en pagos). El modelo/DAO
soporta soft-delete (`eliminadoEn`, `CargasCapitalRepository.eliminar()`,
`CargasCapitalDao.obtenerTodas` ya filtra `eliminadoEn.isNull()`) pero **ninguna pantalla lo
expone hoy**: `HistorialCapitalScreen` es de solo lectura, el cobrador no puede eliminar sus
propios movimientos desde ahí (decisión explícita — antes sí tenía un botón de eliminar para
las filas de `origen = cobrador`, se quitó para todas las filas sin excepción). El método sigue
en el código por si alguna pantalla futura lo necesita, no se borró. `AgregarCapitalScreen`
tiene un `SegmentedButton` para elegir entrada/retiro (**un `retiro` no puede exceder
`saldoDisponible` del propio cobrador** — validado localmente contra
`DashboardRepository.calcularResumen`, mismo criterio que el backend usa vía `CapitalService`
para `AdminAsignarCapitalScreen`, ver sección de panel admin más arriba); `HistorialCapitalScreen`
(icono junto al botón "Agregar capital") lista todos los movimientos no eliminados.

- **Saldo disponible** (`DashboardRepository.calcularResumen`) = `Σ cargas_capital.monto` (tipo
  `carga`) − `Σ cargas_capital.monto` (tipo `retiro`) + `Σ pagos.monto_abonado` (todo lo
  cobrado, **no** `monto_aplicado` — así el excedente de un `cobro_extra` sí cuenta como
  efectivo en caja) − `Σ prestamos.monto_capital` de **cualquier préstamo no anulado**
  (`activo`, `en_mora` o `pagado`). **Ojo con este último término**: hasta la corrección de un
  bug real reportado, solo se restaba el capital de préstamos `activo`/`en_mora`, así que un
  préstamo que terminaba de pagarse dejaba de descontarse — el capital había salido de caja al
  prestarlo igual, y lo que volvió (capital + interés) ya está contado en `monto_abonado`, así
  que dejar de restarlo inflaba el saldo con el capital original otra vez. Solo un préstamo
  `anulado` no cuenta (nunca se entregó o se revirtió).
- **Ganancia realizada**: por cada préstamo (de cualquier estado, uno ya `pagado`/`anulado`
  sigue contando históricamente) se reparte `Σ pagos.monto_aplicado` proporcional al peso de
  interés/extras sobre `montoTotal`. El excedente `cobro_extra` (`monto_abonado -
  monto_aplicado`, el único caso donde difieren) se suma íntegro al balde de **"extras"**
  (mismo balde que los montos extra del préstamo) — decisión explícita del negocio, no un
  tercer balde. La gráfica (`fl_chart`, colores validados con la skill de dataviz) es de esos
  2 colores nada más.
- **Vista configurable del dashboard** (por cobrador, guardada en secure storage con clave
  `dashboard_vista_<usuarioId>`, ver `SecureStorageService.guardar/leerVistaDashboard`, ícono
  de ajustes en el `AppBar` del dashboard): `'todo'` (default, sin preferencia guardada),
  `'capital'` (oculta la tarjeta de "Ganancia realizada" por completo), `'capital_interes'` o
  `'capital_extra'` (la tarjeta queda con un solo balde/color). No afecta el cálculo de
  `DashboardRepository`, solo qué pinta `DashboardScreen`.
- **Entradas hoy / entradas en 7 días**: dinero **realmente cobrado** (`Σ pagos.monto_abonado`
  agrupado por `fecha_pago`), no una proyección de cuotas por vencer. "Hoy" es `fecha_pago` ==
  hoy; "7 días" es una ventana móvil retrospectiva (hoy inclusive, hasta 6 días atrás), sin
  importar si el pago correspondía o no a la cuota que vencía ese día. (Antes de una corrección
  reciente esto mostraba una proyección de cuotas *por vencer* — cifras completamente distintas
  a lo que el nombre de la tarjeta sugiere; si se necesita esa proyección hacia adelante en el
  futuro, debe ser una tarjeta separada, no reemplazar a esta.)
- **Historial de préstamos** (`HistorialPrestamosScreen`, botón debajo de "Nuevo préstamo"):
  misma vista que "Cobros pendientes" (`PrestamosRepository.listarPagados`, mismo criterio de
  búsqueda), pero solo préstamos `estado = pagado`; tocar uno abre el mismo
  `PrestamoDetalleScreen` de siempre (ya es de solo lectura para pagos en ese estado, porque
  `puedeRegistrarPago` ya excluía `pagado`/`anulado`).
- **Exportar Excel** (`ReportesRepository`, paquete `excel` + `share_plus`): filtra el historial
  de pagos por rango de fechas y cliente opcional; el resumen de cartera y el listado de
  préstamos siempre salen completos, sin filtrar. **Decisión revisada**: antes generaba un CSV
  (con un BOM manual de UTF-8, para que Excel detectara la codificación sin él); ahora genera un `.xlsx` real con el paquete
  `excel`, enteramente en el dispositivo, sin pedirle nada al backend — a diferencia del panel
  admin (que sí descarga su `.xlsx` ya armado del servidor, ver sección de admin), este reporte
  es del propio cobrador y debe seguir funcionando sin conexión (offline-first). Una hoja por
  sección (`Resumen`, `Prestamos`, `Historial de pagos`, `Total por cliente`, `Cierre de caja`,
  `Resumen cierre de caja`) en vez del bloque-por-bloque de un CSV plano. El paquete `csv` y
  `csv_exportador.dart` (con su BOM manual) se eliminaron del todo — el nuevo
  `mobile/lib/core/utils/archivo_exportador.dart` (`exportarArchivoYCompartir()`, bytes crudos a
  un archivo temporal + `share_plus`) es ahora el único exportador de archivos, reutilizado
  también por `AdminReportesRepository` (que solo comparte los bytes de un `.xlsx` ya descargado
  del servidor, sin generar nada). `.xlsx` no tiene el problema de BOM que sí tenía el CSV plano.

## App móvil: sincronización (`mobile/lib/features/sincronizacion`)

`SincronizacionRepository.sincronizar()` es el consumidor del backend de sincronización (ver
sección "Sincronización con la app móvil (backend)" más arriba y `API.md`): sube la cola local
`cambios_pendientes` del cobrador con sesión activa contra `POST /api/sync` y, en la misma
respuesta, descarga configuración y cargas de capital asignadas por un admin. Botón
"Sincronizar" + indicador de última sincronización en `DashboardScreen` (pantalla principal del
cobrador), inyectable para pruebas igual que el resto de dependencias de esa pantalla.

- **`uuid_local` se genera al crear el registro, no al sincronizar** (`package:uuid`, `Uuid().v4()`):
  cada `crear()` de `ClientesRepository`/`PrestamosRepository`/`CargasCapitalRepository` y cada
  fila insertada por `PagosRepository.registrar()` lo asigna en el momento de guardar
  localmente. Columna nueva (nullable) en `clientes`/`prestamos`/`pagos`/`cargas_capital` —
  ver sección de versionado de Drift más abajo.
- **Gotcha real corregido de paso**: `PagosRepository.registrar()` solo encolaba **un** cambio
  pendiente (`pagosInsertados.first.id`) sin importar cuántas filas de pago insertara — una
  cascada de excedente `abono_deuda` genera varias filas (`pagos.cuota_id` es una FK singular,
  ver reglas de negocio de pagos), así que solo la primera se habría sincronizado nunca. Ahora
  encola un cambio por cada fila insertada, dentro del mismo `for`.
- **Construcción del batch**: por cada `CambiosPendiente` pendiente del usuario activo, agrupado
  por tabla y luego por `registroId` (varios cambios encolados para el mismo registro colapsan
  en un solo item, reconstruido desde el estado **actual** de la fila en Drift — nunca desde el
  JSON viejo guardado en `cambios_pendientes.payload`, que no alcanza a describir el contrato
  del servidor, ej. trae `cliente_id` local en vez de `cliente_uuid_local`). Las referencias
  cruzadas (`prestamos[].cliente_uuid_local`, `pagos[].prestamo_uuid_local`) se resuelven
  leyendo el `uuidLocal` del registro relacionado, nunca con el id local.
- **`pagos[].cuotas_afectadas` se arma con el estado *actual* de TODAS las cuotas del préstamo**,
  no solo la que ese pago tocó — es idempotente reenviar el mismo estado final en cada pago del
  mismo préstamo dentro del batch, y evita reconstruir un historial de "qué cuota cambió por
  cuál pago" que Drift no guarda en ningún lado una vez que `PagoProcessor.dart` ya aplicó los
  cambios (`plan.actualizacionesCuotas` se descarta después de aplicarse). Mismo razonamiento
  para `estado_prestamo`: se manda el `estado` actual del préstamo, no uno reconstruido
  históricamente.
- **Qué se limpia de `cambios_pendientes` y qué no**: por cada registro devuelto en la
  respuesta, `creado`/`actualizado`/`ya_existia` marcan la fila local `sincronizado = true` +
  `servidorId` y eliminan **todos** los `CambiosPendiente` de ese `registroId` (pueden ser
  varios, si se editó más de una vez antes de sincronizar). `conflicto`/`error` no tocan nada:
  la fila se queda pendiente y se reintenta sola en el próximo `/sync` — nunca se pierde ni se
  duplica. Un fallo de red/timeout tampoco toca nada (la mutación local solo ocurre después de
  que la respuesta HTTP llegó y se decodificó bien).
- **cargas_capital con `eliminadoEn` no nulo, o de `origen != 'cobrador'`, se excluyen del
  batch de subida sin tocar su `CambiosPendiente`**: el backend todavía no soporta borrar una
  carga por sync (ver sección de backend más arriba, "cargas_capital... no reconcilia nada"),
  así que una carga creada y eliminada localmente antes de sincronizar se queda pendiente para
  siempre — no se pierde el registro local, simplemente no hay forma de representarlo en el
  servidor todavía. Una carga de `origen = 'admin'` nunca debería tener un cambio pendiente
  propio (se guarda ya con `sincronizado = true`), el filtro es solo defensivo.
- **Descarga de cargas de capital de admin**: `cargas_capital_admin` de la respuesta se guarda
  vía `CargasCapitalRepository.guardarDescargadaDeAdmin()` — sin `uuidLocal` (nunca se sube,
  ya nace con `servidorId`), `origen = 'admin'`, `sincronizado = true` desde el primer momento;
  idempotente por `servidorId` (`CargasCapitalDao.existePorServidorId`) para no duplicar si
  llegara dos veces. `HistorialCapitalScreen` les muestra un chip "Asignado por administrador"
  y les oculta el botón de eliminar (no tiene sentido deshacer localmente algo que es autoridad
  del servidor y que, de todos modos, hoy no se podría sincronizar de vuelta).
- **Descarga de configuración**: `tasas_interes_default` (`SecureStorageService.guardar/leerTasasInteresDefault`,
  hoy sin ningún consumidor en la UI — ver nota de los botones rápidos de interés en la sección
  de préstamos, sigue siendo una decisión explícita, esto solo la deja disponible para cuando
  haga falta) e `intentos_pin_antes_de_maestro` (reutiliza el `SecureStorageService.guardarIntentosMaximosPin`
  que ya existía, la misma clave que usa `GET /pin-maestro`, para no tener dos fuentes de
  verdad para ese número). **A propósito NO vuelve a llamar `AuthRepository.sincronizarPinMaestro()`**
  — eso sigue pasando solo justo después del login; duplicar esa llamada aquí violaría la regla
  ya documentada de que el hash del PIN maestro es exclusivo de `GET /pin-maestro`.
- **`última sincronización exitosa`** (`SecureStorageService.guardar/leerUltimaSincronizacion`,
  por `usuarioId` igual que la vista del dashboard, mismo motivo: dispositivo compartido) se
  graba recién al final de un `sincronizar()` que llegó a decodificar la respuesta del
  servidor — no antes. Un resultado con `conflictos`/`errores` sigue contando como
  "sincronización exitosa" a este efecto (el request en sí funcionó); el mensaje que ve el
  cobrador sí distingue cuántos registros quedaron pendientes por eso.

## App móvil: base de datos local (Drift) — versionado y aislamiento entre cobradores

Dos reglas que ya causaron bugs reales y no deben repetirse:

1. **Cualquier cambio de esquema (columna o tabla nueva) exige subir `schemaVersion` y
   agregar un paso a `MigrationStrategy.onUpgrade` en `mobile/lib/data/app_database.dart`**,
   con su propio test en `test/data/app_database_migration_test.dart` (arma el esquema viejo a
   mano con `package:sqlite3` crudo, verificado contra `sqlite_master` real, no de memoria).
   Sin esto, un dispositivo con la app ya instalada rompe en silencio (`no such column`/`no
   such table`) la primera vez que se toca esa tabla — ya pasó con `prestamos.referencia`.
   Versión actual: `7` (v1→v2 `referencia`, v2→v3 tabla `cargas_capital`, v3→v4
   `cambios_pendientes.usuario_id`, v4→v5 `cargas_capital.tipo`/`eliminadoEn`, v5→v6
   `uuid_local` en `clientes`/`prestamos`/`pagos`/`cargas_capital` +
   `cargas_capital.origen`/`creadoPorUsuarioId`, todo para `POST /api/sync`, v6→v7 tablas
   `cierres_caja`/`cierre_caja_gastos` — ver sección "Cierre de caja diario" más abajo).
   **Cuidado con
   `m.createTable(tabla)` en un paso `if (from < N)`**: siempre crea la tabla con la definición
   *actual* del código, no con la forma histórica de esa versión — si más adelante se agregan
   columnas a esa misma tabla en un paso posterior (`m.addColumn`), un dispositivo que migra
   desde antes de que la tabla existiera ya la recibe completa vía `createTable` y el
   `addColumn` posterior debe excluir ese caso (`if (from >= N && from < M)`, no solo
   `if (from < M)`) o falla con "duplicate column" — pasó con `cargas_capital.tipo`/`eliminadoEn`
   en el paso v4→v5, y de nuevo con `cargas_capital.uuidLocal`/`origen`/`creadoPorUsuarioId` en
   v5→v6 (`clientes`/`prestamos`/`pagos`, en cambio, existen desde v1 sin excepción — su paso
   v5→v6 es un `addColumn` incondicional).
2. **Todo método de lectura de un DAO que devuelva datos propios de un cobrador debe filtrar
   por `usuarioId`** — el dispositivo es compartido potencialmente por varios cobradores
   (login/logout), todos sobre el mismo archivo SQLite. Antes de esta regla, `obtenerTodos`/
   `buscarPor*`/`obtenerPorId` de casi todos los DAOs no filtraban nada (solo las validaciones
   de duplicados en clientes lo hacían) — cualquier cobrador veía los clientes/préstamos/pagos/
   capital de todos los demás. `PrestamosRepository.obtenerDetalle()` es el punto de
   verificación central (lanza si el préstamo no existe **o es de otro cobrador**, sin
   distinguir cuál de los dos casos, para no filtrar la existencia de datos ajenos) — cualquier
   pantalla que reciba un `prestamoId` de afuera pasa por ahí antes de tocar cuotas/pagos/extras
   (que no tienen `usuario_id` propio, solo `prestamo_id`). `cambios_pendientes` también tiene
   `usuario_id` (nullable, por filas viejas sin dueño) por la misma razón: la cola de
   sincronización tampoco debe cruzarse entre cobradores. Cubierto end-to-end en
   `test/aislamiento_entre_usuarios_test.dart` (dos cobradores, misma base de datos en
   memoria, un solo `AppDatabase`).

## Cierre de caja diario (backend + mobile)

Entidad nueva y **separada** de `cargas_capital` (no comparte tabla ni lógica con
`CapitalService`/`saldo_disponible` — no se tocó nada de esa funcionalidad existente): un
cobrador registra, normalmente una vez por día, cuánto capital tenía al empezar y al cerrar el
día, más los gastos operativos del día.

### Backend

- **`cierres_caja`**: `usuario_id` (FK), `fecha` (date, operativa, editable, default hoy),
  `capital_inicio`/`capital_cierre` (decimal 12,2 — en el móvil se prellenan con el saldo
  disponible del cobrador al momento de abrir el formulario, mismo cálculo de
  `DashboardRepository.calcularResumen`/`CapitalService::calcularSaldoDisponible`, pero son
  editables), `justificacion_diferencia` (text nullable, solo relevante si el cobrador edita
  `capital_inicio`/`capital_cierre` lejos del valor prellenado), `gastos_total` (decimal 12,2,
  default 0, **derivado server-side** sumando los gastos recibidos, nunca confiado del
  cliente), `uuid_local` (nullable, único junto con `usuario_id`, mismo patrón de dedup que el
  resto de sync). `created_at` es el timestamp real de creación del registro, distinto de
  `fecha` (la fecha operativa elegida por el cobrador). Índice `(usuario_id, fecha)`.
- **`cierre_caja_gastos`**: `cierre_caja_id` (FK, cascade delete), `monto` (decimal 12,2),
  `detalle` (string, requerido, texto libre — ej. "almuerzo", "gasolina").
- **`App\Models\CierreCaja`** tiene `protected $table = 'cierres_caja';` explícito —
  **necesario**, Eloquent pluraliza "CierreCaja" como `cierre_cajas` por defecto (mismo bug ya
  conocido y corregido antes en `CargaCapital`/`cargas_capital`; cualquier modelo nuevo con
  nombre compuesto en español debe revisar esto).
- **`GET/POST /api/cierres-caja`** (`App\Http\Controllers\Api\CierreCajaController`,
  `auth:sanctum` + `role:cobrador`, filtrado por `usuario_id` del cobrador autenticado; `show()`
  usa `abort_if` de ownership): `store()` recalcula `gastos_total` en el servidor (suma de los
  `gastos` recibidos), todo dentro de `DB::transaction`, y audita vía `AuditoriaLogger` con
  `accion = 'registrar_cierre_caja'`.
- **Sync** (`POST /api/sync`): `StoreSyncRequest` valida `cierres_caja[]` (incluida la forma
  anidada de `gastos`); `SyncService::sincronizarCierreCaja()` sigue **exactamente** el mismo
  patrón que `sincronizarCargaCapital()` — solo crea o confirma por `uuid_local`, **no
  reconcilia nada** en un cierre ya existente (igual que `cargas_capital`: no hay flujo de
  edición de un cierre ya sincronizado desde el móvil).
- **Export** (`App\Services\ExportarReporteService::datosReporte()`): dos bloques nuevos,
  consumidos automáticamente tanto por el `.xlsx` web (`generarXlsx()`) como por
  `GET /api/admin/reporte` (JSON, CSV mobile) sin tocar ningún controller:
  - `cierre_caja`: una fila por día/cierre (`filasCierreCaja()`) — Cobrador, Fecha, Capital
    inicio, Capital cierre, Gastos total, Detalle de gastos (`detalleGastos()`, texto plano
    tipo "almuerzo: 15.000; gasolina: 20.000"), Justificación de diferencia (**nullable, sin
    coercionar a `''`** — un `''` escrito a una celda xlsx vuelve como `null` al leerla, así
    que se dejó como pass-through; el test de export ya lo asume así).
  - `cierre_caja_resumen`: solo aparece si el rango filtrado abarca más de un día — total de
    gastos del rango, `capital_inicio` del primer día del rango, `capital_cierre` del último
    día (`filasCierreCajaResumen()`).

### Mobile

- Drift: tablas `CierresCaja`/`CierreCajaGastos` (mismas columnas que el backend),
  `CierresCajaDao`/`CierreCajaGastosDao`.
- **`CierresCajaRepository`** (`features/capital/data/cierres_caja_repository.dart`): sigue el
  patrón ya usado por `PrestamosRepository.crear()` (padre + hijos, **un solo**
  `cambios_pendientes` encolado para el cierre completo aunque tenga varios gastos) — no
  inventar un patrón nuevo si se agrega otra entidad con hijos en el futuro, replicar este.
- **`CierreCajaScreen`**: botón junto a "Agregar capital" en el dashboard (ícono
  `Icons.point_of_sale`). Campos: fecha (default hoy, editable), capital de inicio/cierre
  prellenados con el saldo disponible actual (editables), campo de justificación que se vuelve
  **requerido** solo si el cobrador edita capital_inicio o capital_cierre lejos del valor
  prellenado, lista de gastos (monto + detalle, varios permitidos). Todo se guarda primero en
  Drift y queda encolado para el próximo `/sync` — la pantalla no hace ninguna llamada de red
  directa.
- **Sync** (`SincronizacionRepository`): `cierres_caja` agregado al batch de subida (con sus
  `gastos` anidados en el payload) y a `procesarResultados`, mismo criterio que
  `cargas_capital` — sin reconciliación, solo creación/confirmación por `uuid_local`.
- **Export CSV**: `ReportesRepository._agregarSeccionCierreCaja()` (reporte del propio
  cobrador) y `AdminReportesRepository.construirCsv()` (reporte admin) agregan las 2 secciones
  nuevas (`cierre_caja`/`cierre_caja_resumen`) tal cual vienen del backend — mismo criterio de
  "una sola fuente de verdad" que el resto de este reporte financiero.
- **Gotcha real ya corregido**: `ReportesRepository` ahora requiere `cierresCajaRepository`
  como dependencia. Cualquier test o pantalla que la construya manualmente (sin usar el
  constructor por defecto de producción) debe inyectarla explícitamente, igual que las demás
  dependencias de ese repositorio — si no, cae al `CierresCajaRepository()`/
  `SecureStorageService()` reales y revienta por canal de plataforma no inicializado en tests.
  Ya corregido en `test/aislamiento_entre_usuarios_test.dart`; si aparece un test nuevo con el
  mismo tipo de crash, revisar primero si le falta este parámetro.

### Fecha de referencia de `DashboardRepository.calcularResumen()` (ya no depende del reloj real)

`calcularResumen()` acepta un parámetro opcional `{DateTime? ahora}` (default `DateTime.now()`
en producción, sin cambio de comportamiento) usado como "hoy" para `entradasHoy` y la ventana
de `entradasUltimos7Dias`. Corrige una fragilidad real: antes usaba `DateTime.now()` fijo
internamente mientras `test/features/dashboard/dashboard_repository_test.dart` hardcodeaba
`final hoy = DateTime(2026, 7, 15)` para las fechas de pago del fixture — a medida que avanzaba
el calendario real, esas fechas fijas quedaban fuera de la ventana de 7 días y el test empezaba
a fallar solo, sin que nadie tocara el código. El test ahora pasa `ahora: hoy` explícitamente en
las dos pruebas que dependen de la ventana temporal, así que ya no depende del reloj real. Si se
agrega otro consumidor de `calcularResumen()` que necesite fijar "hoy" en un test, usar el mismo
parámetro en vez de reintroducir una dependencia del reloj real.

## Despliegue: Laravel Cloud (`/backend`)

Preparación de infraestructura para desplegar — sin tocar lógica de negocio.

- **`.env.example`** actualizado para reflejar todas las variables que el proyecto usa hoy
  (antes estaba desactualizado: tenía `DB_CONNECTION=sqlite` pese a que el proyecto usa MySQL
  en dev/prod — nombre de base `cobro_app` — y no documentaba `SANCTUM_STATEFUL_DOMAINS`/
  `SESSION_SECURE_COOKIE` en absoluto). Organizado por secciones con comentarios de qué es cada
  variable y, donde aplica, el valor esperado en producción (nunca localhost):
  - `SESSION_DOMAIN`: en producción, el dominio real del panel admin (con punto al inicio para
    cubrir subdominios, ej. `.tudominio.com`).
  - `SANCTUM_STATEFUL_DOMAINS`: prácticamente inerte para este proyecto hoy — la app móvil
    siempre usa Bearer token, nunca cookies, y el panel web usa el guard `web` de sesión pura
    sin pasar por Sanctum (ver sección de auth del panel web más arriba). Documentado igual por
    si algún día se agrega una SPA.
  - `SESSION_SECURE_COOKIE`: debe ser `true` en producción (Laravel Cloud sirve todo por
    HTTPS); en local queda en `false`.
  - `LOG_CHANNEL`: **`stderr`** es el valor activo por defecto ahora (antes era `stack`) —
    recomendado para Laravel Cloud porque el filesystem no persiste entre despliegues, así que
    un log en `storage/logs` se perdería; Laravel Cloud captura stderr directo en su agregador.
    `stack`/`LOG_STACK=single` queda documentado como alternativa comentada para desarrollo
    local (más cómodo para `tail -f` mientras se programa).
- **`bootstrap/app.php` confía en los proxies de Laravel Cloud**
  (`$middleware->trustProxies(at: '*')`, en el bloque `withMiddleware`): sin esto, detrás del
  balanceador que termina TLS y reenvía por HTTP interno con cabeceras `X-Forwarded-*`,
  `Request::isSecure()` vería HTTP y rompería todo lo que depende de detectar HTTPS
  (`SESSION_SECURE_COOKIE`, URLs absolutas con `https://`, redirects). `'*'` confía en
  cualquier proxy inmediato — la práctica estándar de Laravel para PaaS gestionados donde no se
  conoce la IP fija del balanceador de antemano. Verificado simulando una petición con
  `X-Forwarded-Proto: https` a través del middleware real: `isSecure()` pasa de `false` a
  `true` correctamente.
- **`ext-zip` agregado explícito al `require` de `composer.json`** (antes solo lo requería
  *transitivamente* `phpoffice/phpspreadsheet`, dependencia de `maatwebsite/excel` — ver
  sección de reporte financiero más arriba): así el build de Laravel Cloud lo detecta directo,
  sin depender de que su tooling recorra el árbol de dependencias completo. Confirmado con
  `composer check-platform-reqs`.
- **Migraciones verificadas contra MySQL real** (no solo SQLite, que es más permisivo con
  foreign keys): `migrate:fresh` corre limpio en orden dos veces seguidas (creación + drop-and-
  recreate) contra una base MySQL 8.4 descartable, sin errores de FK.
- **Sin dependencia de storage local persistente**: los exports (el `.xlsx` de 5 hojas, tanto
  para la web como para `GET /api/admin/reporte` del panel admin móvil, ver sección de reporte
  financiero) se generan en memoria vía `Excel::raw()` y se devuelven directo en la respuesta
  HTTP — nunca tocan disco. Sesión, caché
  y colas usan driver `database`, no archivos. No hay subida de archivos del lado servidor (la
  foto de cliente es un path local del dispositivo móvil, ver sección de clientes móvil). El
  filesystem efímero de Laravel Cloud (no persiste entre despliegues) no rompe nada de esto hoy.
