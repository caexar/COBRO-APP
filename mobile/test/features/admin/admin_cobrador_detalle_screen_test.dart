import 'dart:convert';

import 'package:cobro_app/core/network/api_client.dart';
import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/features/admin/data/admin_repository.dart';
import 'package:cobro_app/features/admin/presentation/admin_cobrador_detalle_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _SecureStorageFalso extends SecureStorageService {
  @override
  Future<String?> leerToken() async => 'token-de-prueba';
}

http.Response _json(Object cuerpo) {
  return http.Response(jsonEncode(cuerpo), 200, headers: {'content-type': 'application/json'});
}

/// Préstamo mínimo válido para `PrestamoResumen.fromJson`, con overrides
/// puntuales por caso de prueba.
Map<String, dynamic> _prestamo({
  required int id,
  required int clienteId,
  required String estado,
  String? referencia,
  double montoCapital = 100000,
  double montoTotal = 120000,
  List<Map<String, dynamic>> cuotas = const [],
  List<Map<String, dynamic>> pagos = const [],
}) {
  return {
    'id': id,
    'cliente_id': clienteId,
    'referencia': referencia,
    'monto_capital': montoCapital,
    'porcentaje_interes': 20,
    'monto_total': montoTotal,
    'estado': estado,
    'plazo_cuotas': 10,
    'fecha_inicio': '2026-07-10',
    'extras': [],
    'cuotas': cuotas,
    'pagos': pagos,
  };
}

void main() {
  testWidgets('badge de conteo por cliente cuenta pagados sobre el total (no activos/en_mora)', (tester) async {
    final mock = MockClient((request) async {
      return _json({
        'data': {
          'id': 9,
          'nombre': 'Luis',
          'email': 'luis@cobroapp.test',
          'rol': 'cobrador',
          'activo': true,
          'clientes': [
            {'id': 1, 'nombre': 'Juan Perez', 'cedula': '111', 'telefono': '3000000001'},
            {'id': 2, 'nombre': 'Maria Gomez', 'cedula': '222', 'telefono': '3000000002'},
          ],
          'prestamos': [
            // Cliente 1: 3 préstamos, 2 pagados y 1 activo -> badge "2/3" (no "1/3",
            // que sería el conteo de activos/en_mora que se mostraba antes del fix).
            _prestamo(id: 10, clienteId: 1, estado: 'activo', referencia: 'Préstamo moto'),
            _prestamo(id: 11, clienteId: 1, estado: 'pagado'),
            _prestamo(id: 13, clienteId: 1, estado: 'pagado'),
            // Cliente 2: 1 préstamo en_mora, ninguno pagado -> badge "0/1".
            _prestamo(id: 12, clienteId: 2, estado: 'en_mora'),
          ],
        },
      });
    });

    final repository = AdminRepository(apiClient: ApiClient(httpClient: mock), secureStorage: _SecureStorageFalso());

    await tester.pumpWidget(
      MaterialApp(home: AdminCobradorDetalleScreen(usuarioId: 9, repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
  });

  testWidgets('el préstamo con referencia muestra "Cliente - Referencia"', (tester) async {
    final mock = MockClient((request) async {
      return _json({
        'data': {
          'id': 9,
          'nombre': 'Luis',
          'email': 'luis@cobroapp.test',
          'rol': 'cobrador',
          'activo': true,
          'clientes': [
            {'id': 1, 'nombre': 'Juan Perez', 'cedula': '111', 'telefono': '3000000001'},
          ],
          'prestamos': [
            _prestamo(id: 10, clienteId: 1, estado: 'activo', referencia: 'Préstamo moto'),
          ],
        },
      });
    });

    final repository = AdminRepository(apiClient: ApiClient(httpClient: mock), secureStorage: _SecureStorageFalso());

    await tester.pumpWidget(
      MaterialApp(home: AdminCobradorDetalleScreen(usuarioId: 9, repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Juan Perez - Préstamo moto'), findsOneWidget);
  });

  testWidgets('el préstamo sin referencia muestra el nombre del cliente, y sí muestra monto_total', (tester) async {
    final mock = MockClient((request) async {
      return _json({
        'data': {
          'id': 9,
          'nombre': 'Luis',
          'email': 'luis@cobroapp.test',
          'rol': 'cobrador',
          'activo': true,
          'clientes': [
            {'id': 1, 'nombre': 'Juan Perez', 'cedula': '111', 'telefono': '3000000001'},
          ],
          'prestamos': [
            _prestamo(id: 10, clienteId: 1, estado: 'activo', referencia: null, montoTotal: 125000),
          ],
        },
      });
    });

    final repository = AdminRepository(apiClient: ApiClient(httpClient: mock), secureStorage: _SecureStorageFalso());

    await tester.pumpWidget(
      MaterialApp(home: AdminCobradorDetalleScreen(usuarioId: 9, repository: repository)),
    );
    await tester.pumpAndSettle();

    // Sin referencia, el título del préstamo cae al nombre del cliente.
    expect(find.text('Juan Perez'), findsWidgets);
    expect(find.textContaining('125.000'), findsOneWidget);
  });

  testWidgets('el modal de detalle muestra la fecha de pago real de una cuota pagada y el extra cobrado', (
    tester,
  ) async {
    final mock = MockClient((request) async {
      return _json({
        'data': {
          'id': 9,
          'nombre': 'Luis',
          'email': 'luis@cobroapp.test',
          'rol': 'cobrador',
          'activo': true,
          'clientes': [
            {'id': 1, 'nombre': 'Juan Perez', 'cedula': '111', 'telefono': '3000000001'},
          ],
          'prestamos': [
            _prestamo(
              id: 10,
              clienteId: 1,
              estado: 'activo',
              referencia: 'Préstamo moto',
              cuotas: [
                {'id': 100, 'numero_cuota': 1, 'fecha_esperada': '2026-07-10', 'monto_esperado': 12000, 'estado': 'pagada'},
              ],
              // Excedente cobro_extra: monto_abonado (15000) > monto_aplicado (12000).
              pagos: [
                {
                  'cuota_id': 100,
                  'fecha_pago': '2026-07-12',
                  'monto_abonado': 15000,
                  'monto_aplicado': 12000,
                  'saldo_restante_despues': 0,
                },
              ],
            ),
          ],
        },
      });
    });

    final repository = AdminRepository(apiClient: ApiClient(httpClient: mock), secureStorage: _SecureStorageFalso());

    await tester.pumpWidget(
      MaterialApp(home: AdminCobradorDetalleScreen(usuarioId: 9, repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Juan Perez - Préstamo moto'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pagada: 12/07/2026'), findsOneWidget);
    expect(find.textContaining('Extra cobrado'), findsOneWidget);
    expect(find.textContaining('3.000'), findsOneWidget); // 15000 - 12000
  });
}
