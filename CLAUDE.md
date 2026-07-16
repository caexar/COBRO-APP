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

- `capital_prestado` excluye préstamos con `estado = anulado`.
- `total_cobrado` es la suma de `pagos.monto_aplicado` (no `monto_abonado` — así excedentes
  registrados como `cobro_extra` no inflan el total cobrado más allá de lo que realmente
  redujo deuda).
- `cartera_en_mora` es el saldo **pendiente real** de las cuotas en `estado = en_mora`
  (`monto_esperado` menos lo ya aplicado a esa cuota), no el monto bruto de la cuota.
- `ganancia_interes`/`ganancia_extra` (por cobrador y global,
  `AdminResumenController::calcularGananciaPorCobrador()`): réplica en PHP de la misma lógica
  de reparto proporcional que ya existía en `DashboardRepository` del lado móvil — por cada
  préstamo del cobrador (**cualquier estado**, uno ya `pagado`/`anulado` sigue contando
  históricamente) se reparte `Σpagos.monto_aplicado` proporcional al peso de interés/extras
  sobre `monto_total`; el excedente de un pago `cobro_extra` se suma íntegro a `ganancia_extra`.
  Si se vuelve a tocar la fórmula de ganancia en el móvil, hay que replicar el cambio acá
  también (mismo cuidado que ya existe entre `PrestamoCalculator` y su equivalente en Dart).
- Se calcula por cobrador y como total global; incluye cobradores sin actividad (con ceros).
- No existe (ni se agregó) un endpoint `GET /admin/prestamos/{id}` para el detalle de un solo
  préstamo con sus cuotas — confirmado explícitamente que no existe. El detalle completo
  (extras + cuotas + pagos por préstamo) sigue viajando solo dentro de
  `GET /api/admin/usuarios/{id}/detalle` (todos los préstamos del cobrador de una vez); el
  panel admin del móvil arma su modal de detalle de préstamo con esos datos ya descargados, sin
  pedir nada nuevo (ver sección de móvil más abajo). Tampoco existe un endpoint que devuelva
  conteo de préstamos por cliente — se resuelve agrupando en memoria del lado móvil.

### Configuración global (`configuracion_global`)

Tabla clave/valor genérica; el admin gestiona 4 claves conocidas vía
`GET`/`PUT /api/admin/configuracion`:
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
- `AdminCobradorDetalleScreen` es deliberadamente de solo lectura sobre clientes/préstamos (sin
  botones de editar ni eliminar) — el admin puede *ver* la cartera de un cobrador pero el CRUD
  operativo sigue siendo exclusivo del cobrador dueño, desde su propia app. La única acción de
  escritura que sí tiene es el FAB "Asignar saldo" (ver más abajo), que no toca clientes ni
  préstamos.
- **Listado de préstamos y modal de detalle** (`AdminCobradorDetalleScreen`): cada ítem del
  listado muestra `referencia` (o el nombre del cliente como *fallback* si viene vacía —
  `_tituloPrestamo`, para no dejar el título en blanco), `monto_total` (del backend, nunca
  recalculado), `porcentaje_interes`, `plazo_cuotas` y `fecha_inicio`. Tocar un préstamo abre
  un `showModalBottomSheet`/`DraggableScrollableSheet` (`_DetallePrestamoModal`, mismo patrón
  visual que `PrestamoDetalleScreen` del lado cobrador, pero reimplementado localmente porque
  Dart no permite importar los widgets privados de esa pantalla) con capital, interés, extras,
  `monto_total`, total pagado y el listado completo de cuotas — **todo sale de los datos que ya
  trajo `GET /admin/usuarios/{id}/detalle`**, sin ninguna llamada de red nueva.
  `PrestamoResumen.montoInteres` se obtiene restando `montoTotal - montoCapital - montoExtras`
  (no recalculando `capital * porcentaje / 100`) para no arriesgar un desajuste de redondeo
  contra el `monto_total` que sí vino calculado del servidor.
- **Badge de conteo de préstamos por cliente** (`_BadgeConteoPrestamos`, "activos/totales"):
  se arma en memoria agrupando el array `prestamos` ya descargado por `cliente_id` — "activos"
  cuenta `activo`+`en_mora`, "totales" cuenta cualquier estado. No hay ni hace falta un
  endpoint de conteo aparte.
- **Asignar saldo a un cobrador** (`AdminAsignarCapitalScreen`, botón FAB en
  `AdminCobradorDetalleScreen`): mismo patrón visual que `AgregarCapitalScreen` del lado
  cobrador (`SegmentedButton` carga/retiro, `FormateadorDinero`, descripción opcional), pero
  llama a `AdminRepository.asignarCapital()` → `POST /admin/cargas-capital` con el
  `usuario_id` del cobrador que se está viendo (no el admin autenticado). El mensaje de éxito
  aclara explícitamente que el saldo no llega al dispositivo del cobrador hasta su próxima
  sincronización (`cargas_capital_admin` en la respuesta de `POST /sync`, ver sección de
  sincronización más arriba) — el `SnackBar` de confirmación lo muestra
  `AdminCobradorDetalleScreen` después de que el formulario hace `pop(true)`, no el propio
  formulario (para que sobreviva a la animación de salida de la pantalla).
- **`AdminResumenScreen`** también muestra `ganancia_interes`/`ganancia_extra` (ya calculados
  por el backend) junto a los 3 campos que ya tenía, tanto en la tarjeta global como en la de
  cada cobrador (`_FilasTotales`, reutilizada en ambos casos).
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

## App móvil: dashboard, capital y reportes — "Fase 10" (`mobile/lib/features/{dashboard,capital}`)

Todo se calcula **desde Drift local**, nunca pidiéndole nada al backend (mismo criterio
offline-first que clientes/préstamos/pagos). `cargas_capital` es tabla nueva (backend con
migración + `POST /cargas-capital`, sin `GET`; local en Drift) para que el cobrador registre
movimientos de capital: aportes (`tipo = 'carga'`) y retiros (`tipo = 'retiro'`), monto siempre
positivo, el signo lo da `tipo` (mismo patrón que `monto_abonado` en pagos). Soporta soft-delete
(`eliminadoEn`) para deshacer un movimiento registrado por error — `CargasCapitalDao.obtenerTodas`
ya filtra `eliminadoEn.isNull()`. `AgregarCapitalScreen` tiene un `SegmentedButton` para elegir
entrada/retiro; `HistorialCapitalScreen` (icono junto al botón "Agregar capital") lista todos los
movimientos no eliminados con opción de eliminar cada uno.

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
- **Exportar CSV** (`ReportesRepository`, paquete `csv` + `share_plus`): filtra el historial de
  pagos por rango de fechas y cliente opcional; el resumen de cartera y el listado de
  préstamos siempre salen completos, sin filtrar.

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
   Versión actual: `6` (v1→v2 `referencia`, v2→v3 tabla `cargas_capital`, v3→v4
   `cambios_pendientes.usuario_id`, v4→v5 `cargas_capital.tipo`/`eliminadoEn`, v5→v6
   `uuid_local` en `clientes`/`prestamos`/`pagos`/`cargas_capital` +
   `cargas_capital.origen`/`creadoPorUsuarioId`, todo para `POST /api/sync`). **Cuidado con
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
