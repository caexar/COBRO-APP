# API de CobroApp

Base URL local: `http://127.0.0.1:8000/api` (puerto según `php artisan serve`).

Todas las respuestas son JSON. Todas las rutas, excepto `POST /login`, requieren el header:

```
Authorization: Bearer {token}
Accept: application/json
```

Salvo `/login` y `/logout`, las rutas de clientes/préstamos/pagos están restringidas a
usuarios con `rol = cobrador` (middleware `role:cobrador`) y las rutas bajo `/admin/*` están
restringidas a `rol = admin` (middleware `role:admin`); el rol equivocado recibe `403`.
Todo el acceso a clientes/préstamos/pagos se filtra siempre por el `usuario_id` del cobrador
autenticado — un cobrador nunca ve ni modifica datos de otro.

---

## Autenticación

### POST /login

No requiere token.

**Body**
```json
{
  "email": "cobrador@cobroapp.test",
  "password": "password"
}
```

**Respuesta 200**
```json
{
  "token": "2|9ZYH0uEmNtCwdmD9dcjwWqcNbK63ZUJocklhDn01b14a1d80",
  "user": {
    "id": 2,
    "nombre": "Cobrador Test",
    "email": "cobrador@cobroapp.test",
    "rol": "cobrador"
  }
}
```

**Errores**
- `422` credenciales incorrectas o cuenta con `activo = false`.

### POST /logout

Requiere token. Revoca el token actual (no afecta otras sesiones/dispositivos).

**Respuesta 200**
```json
{ "message": "Sesión cerrada correctamente." }
```

### GET /user

Requiere token. Devuelve el usuario autenticado (útil para verificar sesión).

---

## Clientes

Todas requieren `rol = cobrador`. Filtradas por `usuario_id` del cobrador autenticado.

### GET /clientes?q=

`q` es opcional. Si se envía: primero busca coincidencias por `nombre` (LIKE); si no hay
ninguna, intenta buscar por `cedula` (LIKE). Sin `q`, devuelve todos los clientes del
cobrador ordenados por nombre.

**Respuesta 200**
```json
{
  "data": [
    {
      "id": 1,
      "usuario_id": 2,
      "nombre": "Juan Perez",
      "cedula": "123456",
      "telefono": "3001234567",
      "direccion": "Calle 1 # 2-3",
      "referencia": null,
      "foto_url": null,
      "created_at": "2026-07-10T21:25:34.000000Z",
      "updated_at": "2026-07-10T21:25:34.000000Z",
      "deleted_at": null
    }
  ]
}
```

### POST /clientes

**Body**
```json
{
  "nombre": "Juan Perez",
  "cedula": "123456",
  "telefono": "3001234567",
  "direccion": "Calle 1 # 2-3",
  "referencia": null,
  "foto_url": null
}
```
`nombre`, `cedula`, `telefono`, `direccion` requeridos. `referencia` y `foto_url` opcionales.

**Respuesta 201**: el cliente creado (mismo shape que en el índice).

**Error 422** — nombre o cédula duplicados para este cobrador (incluye clientes eliminados
lógicamente, porque la unicidad es a nivel de base de datos):
```json
{
  "message": "Ya tienes registrado un cliente con este nombre.",
  "errors": { "nombre": ["Ya tienes registrado un cliente con este nombre."] }
}
```
(o el mismo error con clave `cedula` si lo duplicado es la cédula).

### PUT /clientes/{cliente}

Mismas reglas que `POST`, pero todos los campos son opcionales (`sometimes`). Solo se puede
editar un cliente propio (403 si es de otro cobrador).

**Respuesta 200**: el cliente actualizado.

### DELETE /clientes/{cliente}

Soft delete (no se borra físicamente). Solo el cobrador dueño.

**Respuesta 200**
```json
{ "message": "Cliente eliminado correctamente." }
```

---

## Préstamos

### POST /prestamos/simular

Calcula el monto total y el reparto de cuotas **sin guardar nada**. No requiere `cliente_id`.

**Body**
```json
{
  "monto_capital": 100000,
  "porcentaje_interes": 20,
  "extras": [{ "concepto": "papeleria", "valor": 5000 }],
  "frecuencia_pago": "diario",
  "dias_personalizado": null,
  "plazo_cuotas": 10,
  "fecha_inicio": "2026-07-10"
}
```
- `frecuencia_pago`: `diario` | `semanal` | `mensual` | `personalizado`.
- `dias_personalizado`: requerido solo si `frecuencia_pago = personalizado`.
- `extras`: opcional, array de `{concepto, valor}`.

**Respuesta 200**
```json
{
  "data": {
    "monto_capital": 100000,
    "monto_interes": 20000,
    "monto_extras": 5000,
    "monto_total": 125000,
    "cuotas": [
      { "numero_cuota": 1, "fecha_esperada": "2026-07-11", "monto_esperado": 12500, "estado": "pendiente" },
      { "numero_cuota": 2, "fecha_esperada": "2026-07-12", "monto_esperado": 12500, "estado": "pendiente" }
    ]
  }
}
```
Ver "Reglas de negocio" en `CLAUDE.md` para el detalle del cálculo.

### POST /prestamos

Igual que `simular`, pero persiste el préstamo, sus extras y sus cuotas. Requiere `cliente_id`
(debe pertenecer al cobrador autenticado) y admite `politica_mora` opcional (por defecto
`mantener`).

**Body**
```json
{
  "cliente_id": 1,
  "monto_capital": 100000,
  "porcentaje_interes": 20,
  "extras": [{ "concepto": "papeleria", "valor": 5000 }],
  "frecuencia_pago": "diario",
  "dias_personalizado": null,
  "plazo_cuotas": 10,
  "fecha_inicio": "2026-07-10",
  "politica_mora": "siguiente_pago"
}
```
- `politica_mora`: `mantener` | `siguiente_pago` | `sumar_total` (nullable, default `mantener`).

**Respuesta 201**: el préstamo creado con `extras` y `cuotas` cargadas.

Deja un registro en `auditoria` (`accion = crear_prestamo`).

### GET /prestamos/{prestamo}

Detalle del préstamo con `cliente`, `extras`, `cuotas` y `pagos` cargados. Solo el cobrador
dueño (403 en otro caso).

### PUT /prestamos/{prestamo}/anular

Cambia `estado` a `anulado`. Nunca se borra el registro. Rechaza pagos futuros sobre ese
préstamo.

**Respuesta 200**: el préstamo con su nuevo estado.

**Error 422** si ya estaba anulado: `{"message": "Este préstamo ya se encuentra anulado."}`

Deja un registro en `auditoria` (`accion = anular_prestamo`).

### GET /prestamos/{prestamo}/pagos

Historial de pagos del préstamo, ordenado por `fecha_pago`.

---

## Pagos

### POST /pagos

Registra un pago contra la cuota pendiente más antigua del préstamo. Calcula `dias_mora`
comparando `fecha_pago` con la `fecha_esperada` de esa cuota, y aplica la `politica_mora`
del préstamo si el abono no la cubre por completo. Ver `CLAUDE.md` para el detalle completo
de las reglas de mora y excedente.

**Body**
```json
{
  "prestamo_id": 1,
  "monto_abonado": 12500,
  "fecha_pago": "2026-07-11",
  "manejo_excedente": null
}
```
- `prestamo_id`: debe pertenecer al cobrador autenticado.
- `manejo_excedente`: `abono_deuda` | `cobro_extra`. **Obligatorio únicamente cuando
  `monto_abonado` supera lo que falta de la cuota correspondiente**; si falta y no se envía,
  la API responde 422 pidiéndolo explícitamente (para que la app se lo pregunte al cobrador).

**Respuesta 201** — normalmente un solo pago, pero puede ser un array de varios si un
excedente con `manejo_excedente = abono_deuda` alcanza a cubrir cuotas futuras (cada pago solo
puede referenciar una cuota):
```json
{
  "data": [
    {
      "id": 1,
      "prestamo_id": 1,
      "cuota_id": 1,
      "monto_abonado": "10000.00",
      "monto_aplicado": "10000.00",
      "fecha_pago": "2026-07-11T00:00:00.000000Z",
      "dias_mora": 0,
      "saldo_restante_despues": "115000.00",
      "cuota": { "id": 1, "numero_cuota": 1, "estado": "pagada", "monto_esperado": "12500.00" }
    }
  ]
}
```

**Errores 422**
- `"El abono supera el monto pendiente de la cuota. Especifica \"manejo_excedente\" (...)"` — falta indicar qué hacer con el excedente.
- `"No se pueden registrar pagos sobre un préstamo anulado."`
- `"Este préstamo no tiene cuotas pendientes por pagar."`

Deja un registro en `auditoria` (`accion = registrar_pago`), incluyendo `manejo_excedente` y
el detalle de cada pago generado.

---

## Administración (`rol = admin`)

Todas bajo el prefijo `/admin`, protegidas por `role:admin`. Cualquier usuario con
`rol = cobrador` recibe `403` en todas ellas.

### GET /admin/usuarios

Lista todos los cobradores (activos e inactivos), ordenados por nombre.

**Respuesta 200**
```json
{
  "data": [
    { "id": 2, "nombre": "Cobrador Uno", "email": "cobrador1@cobroapp.test", "rol": "cobrador", "activo": true, "created_at": "...", "updated_at": "...", "deleted_at": null }
  ]
}
```

### POST /admin/usuarios

Crea un usuario (cobrador o admin).

**Body**
```json
{
  "nombre": "Cobrador Uno",
  "email": "cobrador1@cobroapp.test",
  "password": "password123",
  "rol": "cobrador",
  "pin": "1234",
  "pin_maestro": null
}
```
- `nombre`, `email` (único), `password` (min 8), `rol` (`admin`|`cobrador`) requeridos.
- `pin`: opcional, PIN personal del usuario para la app (se hashea a `pin_hash`). Si se omite,
  queda `0000` por defecto — el cobrador debería cambiarlo desde la app.
- `pin_maestro`: opcional. PIN maestro **individual** de este usuario (se hashea a
  `pin_maestro_hash`); si no se define, la app debe recurrir al PIN maestro **global** de
  `GET /admin/configuracion` (ver más abajo).

**Respuesta 201**: el usuario creado (sin `password`/`pin_hash`/`pin_maestro_hash`, ocultos
por el modelo). Deja registro en `auditoria` (`accion = crear_usuario`).

### PUT /admin/usuarios/{usuario}

Edita un usuario existente. Todos los campos son opcionales (`sometimes`): `nombre`, `email`,
`password`, `rol`, `pin`, `pin_maestro` (enviar `pin_maestro: null` limpia el PIN maestro
individual, quedando el global como respaldo). **No permite tocar `activo`** — eso es
exclusivo de `PUT /admin/usuarios/{id}/desactivar`, así que no hay forma de reactivar un
usuario todavía por API (queda pendiente si se necesita).

**Respuesta 200**: el usuario actualizado. Deja registro en `auditoria`
(`accion = actualizar_usuario`).

### PUT /admin/usuarios/{usuario}/desactivar

Marca `activo = false`. **Nunca elimina** el usuario (ni soft delete). Un admin no puede
desactivarse a sí mismo (422).

**Respuesta 200**: el usuario con `activo: false`.
**Error 422**: `"No puedes desactivar tu propio usuario."` o `"Este usuario ya está desactivado."`

Deja registro en `auditoria` (`accion = desactivar_usuario`). Un usuario inactivo no puede
hacer `POST /login` (422 `"Esta cuenta se encuentra inactiva."`).

### GET /admin/usuarios/{usuario}/detalle

Vista de solo lectura: el cobrador con sus `clientes` (ordenados por nombre) y sus
`prestamos` (cada uno con `cliente`, `extras`, `cuotas` y `pagos` cargados, más recientes
primero). Devuelve `404` si `{usuario}` no tiene `rol = cobrador`.

### GET /admin/resumen

Totales consolidados, global y por cobrador. Excluye préstamos `anulado` del capital
prestado; `cartera_en_mora` es el saldo pendiente real (no el bruto) de las cuotas en
`en_mora`.

**Respuesta 200**
```json
{
  "data": {
    "global": { "capital_prestado": 50000, "total_cobrado": 5000, "cartera_en_mora": 6000 },
    "por_cobrador": [
      {
        "usuario_id": 2,
        "nombre": "Cobrador Uno",
        "activo": true,
        "capital_prestado": 50000,
        "total_cobrado": 5000,
        "cartera_en_mora": 6000
      }
    ]
  }
}
```

### GET /admin/configuracion

Lee la configuración global. El PIN maestro nunca se devuelve; solo si hay uno configurado.

**Respuesta 200**
```json
{
  "data": {
    "tasas_interes_default": [10, 20, 30, 40],
    "politica_mora_default": "mantener",
    "pin_maestro_configurado": false
  }
}
```

### PUT /admin/configuracion

Actualiza uno o más valores (todos opcionales, `sometimes`).

**Body**
```json
{
  "tasas_interes_default": [15, 25, 35],
  "politica_mora_default": "siguiente_pago",
  "pin_maestro": "555555"
}
```
- `tasas_interes_default`: array de números, solo valores sugeridos para la UI (no se valida
  `porcentaje_interes` de un préstamo contra esta lista).
- `politica_mora_default`: se usa como `politica_mora` de cualquier préstamo nuevo que no la
  especifique explícitamente (`POST /prestamos`).
- `pin_maestro`: PIN maestro **global**, usado como respaldo cuando un cobrador no tiene su
  propio `pin_maestro` individual. Enviar `pin_maestro: null` lo elimina.

**Respuesta 200**: mismo shape que el `GET`. El pago maestro nunca se registra en texto plano
en `auditoria` (`accion = actualizar_configuracion`), solo si cambió o no.

---

## Resumen de rutas

| Método | Ruta | Auth | Notas |
|---|---|---|---|
| POST | `/login` | No | — |
| POST | `/logout` | Sí | — |
| GET | `/user` | Sí | — |
| GET | `/clientes` | cobrador | `?q=` |
| POST | `/clientes` | cobrador | — |
| PUT | `/clientes/{cliente}` | cobrador | dueño |
| DELETE | `/clientes/{cliente}` | cobrador | dueño, soft delete |
| POST | `/prestamos/simular` | cobrador | no persiste |
| POST | `/prestamos` | cobrador | genera cuotas, auditoría |
| GET | `/prestamos/{prestamo}` | cobrador | dueño |
| PUT | `/prestamos/{prestamo}/anular` | cobrador | dueño, auditoría |
| GET | `/prestamos/{prestamo}/pagos` | cobrador | dueño |
| POST | `/pagos` | cobrador | dueño, auditoría |
| GET | `/admin/usuarios` | admin | lista cobradores |
| POST | `/admin/usuarios` | admin | auditoría |
| PUT | `/admin/usuarios/{usuario}` | admin | auditoría, no toca `activo` |
| PUT | `/admin/usuarios/{usuario}/desactivar` | admin | auditoría, nunca elimina |
| GET | `/admin/usuarios/{usuario}/detalle` | admin | solo lectura |
| GET | `/admin/resumen` | admin | consolidado global + por cobrador |
| GET | `/admin/configuracion` | admin | — |
| PUT | `/admin/configuracion` | admin | auditoría |
