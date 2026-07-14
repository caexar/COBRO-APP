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
`pin_maestro_individual_hash` (del cobrador autenticado) y `pin_maestro_global_hash` (de
`configuracion_global`), ambos nullable. La app intenta primero el individual y, si no
coincide o no existe, cae al global (implementado en
`mobile/lib/features/auth/data/bloqueo_repository.dart`).

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

Tabla clave/valor genérica; el admin gestiona 3 claves conocidas vía
`GET`/`PUT /api/admin/configuracion`:
- `tasas_interes_default`: array JSON de tasas sugeridas (ej. `[10,20,30,40]`) — **no se
  valida** `porcentaje_interes` de un préstamo contra esta lista, es solo un valor de UI.
- `politica_mora_default`: si `POST /api/prestamos` no envía `politica_mora`, se usa este
  valor (lookup vía `ConfiguracionGlobal::obtener('politica_mora_default', 'mantener')` en
  `PrestamoController::store`) en lugar de un default hardcodeado.
- `pin_maestro_hash`: ver sección de PIN maestro arriba.

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
  `ClientesDao.actualizar`). Aplica el mismo cuidado a los próximos DAOs (préstamos, cuotas,
  pagos).
- Test de referencia: `test/features/clientes/clientes_repository_test.dart` corre contra
  Drift en memoria (`AppDatabase.paraPruebas(NativeDatabase.memory())`) con un
  `SecureStorageService` de prueba (subclase que fija `leerUsuarioId()`), sin tocar
  `flutter_secure_storage` real. Buen patrón a copiar para testear futuros repositorios.
