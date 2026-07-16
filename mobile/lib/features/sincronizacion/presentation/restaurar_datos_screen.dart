import 'package:flutter/material.dart';

import '../data/restauracion_repository.dart';

/// Ofrece traer los datos del cobrador desde el servidor (`GET
/// /api/restaurar`) cuando este dispositivo todavía no tiene nada guardado
/// localmente — primera vez en un dispositivo nuevo, o app reinstalada.
///
/// [onFinalizado] se llama tanto si la restauración termina con éxito como
/// si el cobrador elige continuar sin restaurar (ej. sin conexión en el
/// momento): quien use esta pantalla decide qué significa "terminar" —
/// `AppEntryPoint` avanza al dashboard, una navegación empujada desde el
/// dashboard simplemente hace `pop`.
class RestaurarDatosScreen extends StatefulWidget {
  const RestaurarDatosScreen({super.key, required this.onFinalizado, this.repository});

  final VoidCallback onFinalizado;

  /// Inyectable solo para pruebas; en la app real siempre se usa la
  /// instancia por defecto.
  final RestauracionRepository? repository;

  @override
  State<RestaurarDatosScreen> createState() => _RestaurarDatosScreenState();
}

class _RestaurarDatosScreenState extends State<RestaurarDatosScreen> {
  late final _repository = widget.repository ?? RestauracionRepository();

  bool _restaurando = false;
  String? _error;

  Future<void> _restaurar() async {
    if (_restaurando) return;

    setState(() {
      _restaurando = true;
      _error = null;
    });

    final resultado = await _repository.restaurar();

    if (!mounted) return;
    setState(() => _restaurando = false);

    if (resultado.exitosa) {
      widget.onFinalizado();
    } else {
      setState(() => _error = resultado.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.cloud_download_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                'Restaurar tus datos',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Este dispositivo todavía no tiene guardados tus clientes, préstamos ni pagos. '
                'Si ya los registraste antes desde otro dispositivo, puedes traerlos de nuevo desde el servidor.',
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _restaurando ? null : _restaurar,
                icon: _restaurando
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_download),
                label: Text(
                  _restaurando ? 'Restaurando…' : 'Restaurar mis datos',
                  style: const TextStyle(fontSize: 17),
                ),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _restaurando ? null : widget.onFinalizado,
                child: const Text('Continuar sin restaurar (podrás hacerlo después)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
