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
- `admin` tiene sus propios endpoints (fase pendiente); no reutiliza estas rutas para
  editar datos operativos. `ClientePolicy` y `PrestamoPolicy` (`app/Policies/`) ya
  contemplan que `admin` puede leer (`view`/`viewAny`) pero no crear/editar/eliminar.

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

`crear_prestamo`, `registrar_pago` y `anular_prestamo` dejan registro en `auditoria` vía
`App\Services\AuditoriaLogger`. Cualquier acción nueva que el negocio considere "relevante"
debe usar ese mismo servicio en lugar de escribir en el modelo `Auditoria` directamente.
