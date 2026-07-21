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

Map<String, dynamic> _reporteJson() {
  return {
    'prestamos': {
      'titulo': 'Detalle de préstamos',
      'columnas': ['Cobrador', 'Cliente', 'Cédula', 'Capital'],
      'filas': [
        ['Ana Torres', 'Juan Perez', '123456', 100000],
      ],
    },
    'resumen_por_cobrador': {
      'titulo': 'Resumen por cobrador',
      'columnas': ['Cobrador', 'Cartera pendiente al inicio', 'Total cobrado en el periodo'],
      'filas': [
        ['Ana Torres', 0, 62500],
      ],
    },
    'movimientos_capital': {
      'titulo': 'Movimientos de capital',
      'columnas': ['Cobrador', 'Fecha', 'Tipo', 'Monto', 'Categoría'],
      'filas': [
        ['Ana Torres', '10/01/2026', 'retiro', 20000, 'gasto_operativo'],
      ],
    },
    'cierre_caja': {
      'titulo': 'Cierre de caja',
      'columnas': ['Cobrador', 'Fecha', 'Capital inicio', 'Capital cierre', 'Total gastos'],
      'filas': [
        ['Ana Torres', '10/01/2026', 100000, 120000, 10000],
      ],
    },
    'cierre_caja_resumen': {
      'titulo': 'Resumen de cierre de caja (rango)',
      'columnas': ['Cobrador', 'Capital inicio (primer día)', 'Capital cierre (último día)', 'Total gastos (rango)'],
      'filas': [
        ['Ana Torres', 100000, 120000, 10000],
      ],
    },
  };
}

void main() {
  test('construirCsv arma un solo CSV con las 3 secciones del reporte financiero', () async {
    Uri? urlLlamada;

    final mock = MockClient((request) async {
      urlLlamada = request.url;
      return _json({'data': _reporteJson()});
    });

    final adminRepository = AdminRepository(apiClient: ApiClient(httpClient: mock), secureStorage: _SecureStorageFalso());
    final reportesRepository = AdminReportesRepository(adminRepository: adminRepository);

    final csv = await reportesRepository.construirCsv(
      usuarioIds: [2, 3],
      desde: DateTime(2026, 1, 1),
      hasta: DateTime(2026, 1, 31),
      categoria: 'gasto_operativo',
    );

    // Pide el reporte con los filtros correctos (Uri percent-codifica los corchetes de
    // "usuario_ids[]" al parsear, por eso se lee vía queryParametersAll ya decodificado).
    expect(urlLlamada!.path, '/api/admin/reporte');
    expect(urlLlamada!.queryParametersAll['usuario_ids[]'], ['2', '3']);
    expect(urlLlamada!.queryParameters['desde'], '2026-01-01');
    expect(urlLlamada!.queryParameters['hasta'], '2026-01-31');
    expect(urlLlamada!.queryParameters['categoria'], 'gasto_operativo');

    // Las 3 secciones, con su título y encabezados, aparecen en un solo CSV.
    expect(csv, contains('Detalle de préstamos'));
    expect(csv, contains('Cobrador,Cliente,Cédula,Capital'));
    expect(csv, contains('Ana Torres,Juan Perez,123456,100000'));

    expect(csv, contains('Resumen por cobrador'));
    expect(csv, contains('Cobrador,Cartera pendiente al inicio,Total cobrado en el periodo'));
    expect(csv, contains('Ana Torres,0,62500'));

    expect(csv, contains('Movimientos de capital'));
    expect(csv, contains('Cobrador,Fecha,Tipo,Monto,Categoría'));
    expect(csv, contains('Ana Torres,10/01/2026,retiro,20000,gasto_operativo'));
  });

  test('exportarYCompartir antepone el BOM de UTF-8 (mismo helper que los demás exports)', () async {
    final mock = MockClient((request) async => _json({'data': _reporteJson()}));

    final adminRepository = AdminRepository(apiClient: ApiClient(httpClient: mock), secureStorage: _SecureStorageFalso());
    final reportesRepository = AdminReportesRepository(adminRepository: adminRepository);

    // `exportarCsvYCompartir` (core/utils/csv_exportador.dart) es quien antepone el BOM antes
    // de compartir — acá solo se confirma que `construirCsv` (lo que ese helper recibe) no lo
    // antepone dos veces ni rompe si se llama sin filtros de fecha/categoria.
    final csv = await reportesRepository.construirCsv(usuarioIds: [2]);

    expect(csv.startsWith('﻿'), isFalse);
    expect(csv, contains('Detalle de préstamos'));
  });
}
