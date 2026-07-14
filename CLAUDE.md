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
`Prestamo::montoTotal() - suma_total_de(pagos.monto_aplicado)` **hasta ese momento**
(`Prestamo::montoTotal()` es un método calculado, no una columna). El estado del préstamo se
recalcula después de cada pago: `pagado` si ya no quedan cuotas sin pagar, `en_mora` si
alguna cuota quedó en `en_mora`, si no `activo`. `anulado` es un estado aparte que solo se
setea vía `PUT /api/prestamos/{id}/anular` y bloquea nuevos pagos.

### Auditoría

`crear_prestamo`, `registrar_pago`, `anular_prestamo`, y del lado admin `crear_usuario`,
`actualizar_usuario`, `desactivar_usuario`, `actualizar_configuracion` dejan registro en
`auditoria` vía `App\Services\AuditoriaLogger`. Cualquier acción nueva que el negocio
considere "relevante" debe usar ese mismo servicio en lugar de escribir en el modelo
`Auditoria` directamente. Nunca se registra un PIN en texto plano en `auditoria` (ver
`actualizar_configuracion`, que solo guarda si el PIN maestro cambió, no su valor).

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
- Se calcula por cobrador y como total global; incluye cobradores sin actividad (con ceros).

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
- `AdminCobradorDetalleScreen` es deliberadamente de solo lectura (sin botones de editar ni
  eliminar sobre clientes/préstamos) — el admin puede *ver* la cartera de un cobrador pero el
  CRUD operativo sigue siendo exclusivo del cobrador dueño, desde su propia app.
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
