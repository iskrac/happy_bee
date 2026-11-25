import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'brushing_session_screen.dart';
import 'welcome_screen.dart';

class HomeApoderadoScreen extends StatefulWidget {
  const HomeApoderadoScreen({super.key});

  @override
  State<HomeApoderadoScreen> createState() => _HomeApoderadoScreenState();
}

class _HomeApoderadoScreenState extends State<HomeApoderadoScreen> {
  // Editar perfil del apoderado
  void _editarPerfilApoderado(
    BuildContext context,
    Map<String, dynamic> userData,
    String uid,
  ) {
    final nombreCtrl = TextEditingController(text: userData['nombre'] ?? '');
    final apellidoCtrl = TextEditingController(
      text: userData['apellido'] ?? '',
    );
    final rutCtrl = TextEditingController(text: userData['rut'] ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mi Perfil (Apoderado)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Correo: ${userData['email'] ?? ''}'),
              const SizedBox(height: 12),
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: apellidoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Apellido',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rutCtrl,
                decoration: const InputDecoration(
                  labelText: 'RUT',
                  hintText: '12345678-9',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final messenger = ScaffoldMessenger.of(context);

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({
                    'nombre': nombreCtrl.text.trim(),
                    'apellido': apellidoCtrl.text.trim(),
                    'rut': rutCtrl.text.trim(),
                  });

              if (!mounted) return;
              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Perfil de apoderado actualizado.'),
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // Crear o editar perfil infantil (RF-03)
  void _gestionarPerfilInfantil({
    required BuildContext context,
    required String apoderadoUid,
    String? childDocId,
    Map<String, dynamic>? existingData,
  }) {
    final isEditing = childDocId != null;
    final nombreCtrl = TextEditingController(
      text: existingData?['nombre'] ?? '',
    );
    final edadCtrl = TextEditingController(
      text: (existingData?['edad'] ?? '').toString(),
    );
    String avatarSeleccionado = existingData?['avatar'] ?? '🐝 Abejita Feliz';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            isEditing ? 'Editar Perfil Infantil' : 'Nuevo Perfil Infantil',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre o apodo del niño/a',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: edadCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Edad (7 a 12 años)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: avatarSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Avatar',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: '🐝 Abejita Feliz',
                      child: Text('🐝 Abejita Feliz'),
                    ),
                    DropdownMenuItem(
                      value: '🍯 Guardián de la Miel',
                      child: Text('🍯 Guardián de la Miel'),
                    ),
                    DropdownMenuItem(
                      value: '🦷 Súper Diente',
                      child: Text('🦷 Súper Diente'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => avatarSeleccionado = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nombre = nombreCtrl.text.trim();
                final edad = int.tryParse(edadCtrl.text.trim()) ?? 8;
                if (nombre.isEmpty) return;

                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(context);

                if (isEditing) {
                  await FirebaseFirestore.instance
                      .collection('children')
                      .doc(childDocId)
                      .update({
                        'nombre': nombre,
                        'edad': edad,
                        'avatar': avatarSeleccionado,
                      });
                } else {
                  await FirebaseFirestore.instance.collection('children').add({
                    'apoderadoUid': apoderadoUid,
                    'nombre': nombre,
                    'edad': edad,
                    'avatar': avatarSeleccionado,
                    'creadoEn': FieldValue.serverTimestamp(),
                  });
                }

                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      isEditing
                          ? 'Perfil infantil actualizado.'
                          : 'Perfil infantil creado con éxito.',
                    ),
                  ),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatearFecha(Timestamp? ts) {
    if (ts == null) return 'Recién guardada';
    final d = ts.toDate().toLocal();
    final dia = d.day.toString().padLeft(2, '0');
    final mes = d.month.toString().padLeft(2, '0');
    final hora = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${d.year} $hora:$min';
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel del Apoderado'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await AuthService().signOut();
              if (!mounted) return;
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (r) => false,
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .snapshots(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
          final nombreApoderado = userData['nombre'] ?? 'Apoderado';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tarjeta del Apoderado (RF-26)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(
                      'Hola, $nombreApoderado',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'RUT: ${userData['rut'] ?? 'Sin RUT'} • ${userData['email'] ?? ''}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Editar mi perfil',
                      onPressed: () =>
                          _editarPerfilApoderado(context, userData, currentUid),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Encabezado Perfiles Infantiles (RF-03)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Perfiles Infantiles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _gestionarPerfilInfantil(
                        context: context,
                        apoderadoUid: currentUid,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar niño'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Lista de niños asociados al apoderado + Botón Cepillado
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('children')
                      .where('apoderadoUid', isEqualTo: currentUid)
                      .snapshots(),
                  builder: (context, childSnap) {
                    if (childSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final childrenDocs = childSnap.data?.docs ?? [];
                    if (childrenDocs.isEmpty) {
                      return Card(
                        color: Colors.amber.shade50,
                        child: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Aún no tienes perfiles infantiles creados. Toca "Agregar niño" para crear uno e iniciar una sesión de cepillado.',
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: childrenDocs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final childName = data['nombre'] ?? 'Niño';
                        final edad = data['edad'] ?? '';
                        final avatar = data['avatar'] ?? '🐝';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '$avatar • $childName ($edad años)',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      tooltip: 'Editar perfil infantil',
                                      onPressed: () => _gestionarPerfilInfantil(
                                        context: context,
                                        apoderadoUid: currentUid,
                                        childDocId: doc.id,
                                        existingData: data,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BrushingSessionScreen(
                                            childId: doc.id,
                                            childName: childName,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.timer),
                                    label: const Text(
                                      'Iniciar cepillado (2 min)',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),

                // Historial de sesiones registradas (RF-05 y RF-26)
                const Text(
                  'Historial de Sesiones Registradas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('brushing_sessions')
                      .where('apoderadoUid', isEqualTo: currentUid)
                      .snapshots(),
                  builder: (context, sessionSnap) {
                    if (sessionSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final sessions = sessionSnap.data?.docs ?? [];
                    if (sessions.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          'No hay sesiones de cepillado registradas todavía.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }

                    return Column(
                      children: sessions.map((sDoc) {
                        final sData = sDoc.data() as Map<String, dynamic>;
                        final childName = sData['childName'] ?? 'Niño';
                        final duracion = sData['duracion'] ?? 0;
                        final estado = sData['estado'] ?? 'Completada';
                        final estadoEvidencia =
                            sData['estadoEvidencia'] ?? 'Sin evidencia';
                        final fechaTexto = _formatearFecha(
                          sData['fecha'] as Timestamp?,
                        );

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              estadoEvidencia.toString().startsWith('Capturada')
                                  ? Icons.camera_alt
                                  : Icons.check_circle_outline,
                              color: Colors.amber.shade800,
                            ),
                            title: Text('$childName • $estado (${duracion}s)'),
                            subtitle: Text(
                              'Fecha: $fechaTexto\nEvidencia: $estadoEvidencia',
                            ),
                            isThreeLine: true,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
