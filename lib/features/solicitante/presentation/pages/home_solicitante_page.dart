import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/emergency_status_chip.dart';
import '../../../../core/widgets/section_title.dart';
import '../../../solicitante/application/emergencia_controller.dart';

class HomeSolicitantePage extends StatefulWidget {
  const HomeSolicitantePage({super.key});

  @override
  State<HomeSolicitantePage> createState() => _HomeSolicitantePageState();
}

class _HomeSolicitantePageState extends State<HomeSolicitantePage> {
  final _controller = EmergenciaController();

  Future<void> _pullRefresh() async {
    await _controller.refreshHistorial();
    if (mounted) setState(() {});
  }

  Future<void> _confirmNuevaEmergencia() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Confirmar solicitud',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'Se enviará tu ubicación y una breve descripción al centro de emergencias para asignar la ambulancia disponible más cercana.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: ResQColors.primary400,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Solicitar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );

    if (ok == true) {
      final res = await _controller.crearEmergenciaRapida(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.ok ? Colors.green[700] : Colors.red[700],
        ),
      );
      if (res.ok) setState(() {});
      // TODO: Navigator.pushNamed(context, '/emergencia/estado', arguments: res.id);
    }
  }

  Future<void> _llamar123() async {
    final uri = Uri(scheme: 'tel', path: '123');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final historial = _controller.historial;
    return Scaffold(
      backgroundColor: ResQColors.primary50,
      appBar: AppBar(
        backgroundColor: ResQColors.primary50,
        elevation: 0,
        centerTitle: false,
        title: const Text('ResQ', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Perfil',
            onPressed: () {},
            icon: const Icon(Icons.account_circle_outlined),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _pullRefresh,
        color: ResQColors.primary400,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _PrimaryCTA(onTap: _confirmNuevaEmergencia),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _QuickActionButton(label: 'Llamar 123', icon: Icons.call_rounded, onTap: _llamar123)),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionButton(
                    label: 'Mi ubicación',
                    icon: Icons.my_location_rounded,
                    onTap: () async {
                      final ok = await _controller.probarGPS(context);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(ok ? 'Ubicación obtenida' : 'No fue posible obtener GPS')),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionTitle(text: 'Mis últimas emergencias'),
            const SizedBox(height: 8),
            if (historial.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black12.withOpacity(.06), blurRadius: 8)],
                ),
                child: const Text(
                  'Aún no tienes emergencias registradas. Cuando realices una solicitud, aparecerá aquí para que puedas darles seguimiento.',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              ...historial.take(5).map((e) => _EmergencyListItem(data: e)),
          ],
        ),
      ),
    );
  }
}

/// CTA grande
class _PrimaryCTA extends StatelessWidget {
  final VoidCallback onTap;
  const _PrimaryCTA({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [ResQColors.primary300, ResQColors.primary400],
          ),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 6))],
        ),
        child: Row(
          children: const [
            Icon(Icons.sos_rounded, color: Colors.white, size: 34),
            SizedBox(width: 12),
            Expanded(
              child: Text('Solicitar ambulancia ahora',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

/// Botones secundarios
class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickActionButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white, borderRadius: BorderRadius.circular(16), elevation: 0,
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: ResQColors.primary600),
              const SizedBox(width: 8),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Item de lista
class _EmergencyListItem extends StatelessWidget {
  final EmergenciaView data;
  const _EmergencyListItem({required this.data});

  EstadoEmergencia _parse(String raw) {
    switch (raw) {
      case 'evaluada': return EstadoEmergencia.evaluada;
      case 'asignada': return EstadoEmergencia.asignada;
      case 'enCamino': return EstadoEmergencia.enCamino;
      case 'enSitio':  return EstadoEmergencia.enSitio;
      case 'atendida': return EstadoEmergencia.atendida;
      case 'cancelada':return EstadoEmergencia.cancelada;
      default:         return EstadoEmergencia.registrada;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12.withOpacity(.06), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: ResQColors.primary100, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.local_hospital_rounded, color: ResQColors.primary600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data.titulo, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(data.fechaTexto, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 8),
          EmergencyStatusChip(status: _parse(data.estadoRaw)),
        ],
      ),
    );
  }
}
