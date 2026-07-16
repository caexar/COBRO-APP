import 'dart:convert';

import 'package:cobro_app/core/network/api_client.dart';
import 'package:cobro_app/core/storage/secure_storage_service.dart';
import 'package:cobro_app/features/admin/data/admin_repository.dart';
import 'package:cobro_app/features/admin/data/admin_reportes_repository.dart';
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

Map<String, dynamic> _detalleCobrador({required int usuarioId, required String nombreCliente, required List<Map<String, dynamic>> pagos}) {
  return {
    'id': usuarioId,
    'nombre': 'Cobrador $usuarioId',
    'email': 'cobrador$usuarioId@cobroapp.test',
    'rol': 'cobrador',
    'activo': true,
    'clientes': [
      {'id': 1, 'nombre': nombreCliente, 'cedula': '111', 'telefono': '3000000001'},
    ],
    'prestamos': [
      {
        'id': 10,
        'cliente_id': 1,
        'referencia': 'Préstamo moto',
        'monto_capital': 100000,
        'porcentaje_interes': 20,
        'monto_total': 120000,
        'estado': 'activo',
        'plazo_cuotas': 10,
        'fecha_inicio': '2026-01-01',
        'extras': [],
        'cuotas': [],
        'pagos': pagos,
      },
    ],
  };
}

void main() {
  test('construirCsv incluye solo los cobradores seleccionados y filtra el historial por fecha', () async {
    final mock = MockClient((request) async {
      if (request.url.path == '/api/admin/usuarios') {
        return _json({
          'data': [
            {
              'id': 2,
              'nombre': 'Ana Torres',
              'email': 'ana@cobroapp.test',
              'rol': 'cobrador',
              'activo': true,
            },
            {
              'id': 3,
              'nombre': 'Luis Rojas',
              'email': 'luis@cobroapp.test',
              'rol': 'cobrador',
              'activo': true,
            },
          ],
        });
      }

      if (request.url.path == '/api/admin/usuarios/2/detalle') {
        return _json({
          'data': _detalleCobrador(
            usuarioId: 2,
            nombreCliente: 'Juan Perez',
            pagos: [
              {'cuota_id': 1, 'fecha_pago': '2026-01-05', 'monto_abonado': 12000, 'monto_aplicado': 12000, 'saldo_restante_despues': 108000},
              {'cuota_id': 2, 'fecha_pago': '2026-03-01', 'monto_abonado': 12000, 'monto_aplicado': 12000, 'saldo_restante_despues': 96000},
            ],
          ),
        });
      }

      if (request.url.path == '/api/admin/usuarios/3/detalle') {
        return _json({
          'data': _detalleCobrador(usuarioId: 3, nombreCliente: 'Maria Gomez', pagos: []),
        });
      }

      throw StateError('Ruta no esperada: ${request.url.path}');
    });

    final adminRepository = AdminRepository(apiClient: ApiClient(httpClient: mock), secureStorage: _SecureStorageFalso());
    final reportesRepository = AdminReportesRepository(adminRepository: adminRepository);

    final csv = await reportesRepository.construirCsv(
      usuarioIds: [2],
      desde: DateTime(2026, 1, 1),
      hasta: DateTime(2026, 1, 31),
    );

    // Solo el cobrador seleccionado (2) aparece, no el 3.
    expect(csv, contains('Ana Torres'));
    expect(csv, isNot(contains('Luis Rojas')));
    expect(csv, isNot(contains('Maria Gomez')));

    // El préstamo siempre sale completo...
    expect(csv, contains('Juan Perez'));
    expect(csv, contains('Préstamo moto'));

    // ...pero el historial de pagos respeta el rango: solo el pago de enero.
    expect(csv, contains('05/01/2026'));
    expect(csv, isNot(contains('01/03/2026')));
  });
}
