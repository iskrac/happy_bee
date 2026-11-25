import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import 'welcome_screen.dart';

class HomeDentistaScreen extends StatefulWidget {
  const HomeDentistaScreen({super.key});

  @override
  State<HomeDentistaScreen> createState() => _HomeDentistaScreenState();
}

class _HomeDentistaScreenState extends State<HomeDentistaScreen> {
  // Formulario editable de Perfil Profesional del Dentista
  void _mostrarPerfilDentista(
    BuildContext context,
    Map<String, dynamic> userData,
    String uid,
  ) {
    final nombreCtrl = TextEditingController(text: userData['nombre'] ?? '');
    final apellidoCtrl = TextEditingController(
      text: userData['apellido'] ?? '',
    );
    final rutCtrl = TextEditingController(text: userData['rut'] ?? '');
    final especialidadCtrl = TextEditingController(
      text: userData['especialidad'] ?? 'Odontopediatría',
    );
    final registroCtrl = TextEditingController(
      text: userData['registroSuperintendencia'] ?? '',
    );
    final clinicaCtrl = TextEditingController(text: userData['clinica'] ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mi Perfil Profesional'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Correo: ${userData['email'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
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
                const SizedBox(height: 12),
                TextField(
                  controller: especialidadCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Especialidad',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: registroCtrl,
                  decoration: const InputDecoration(
                    labelText: 'N° Registro Superintendencia de Salud',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: clinicaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Clínica o Centro de Atención',
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
                      'especialidad': especialidadCtrl.text.trim(),
                      'registroSuperintendencia': registroCtrl.text.trim(),
                      'clinica': clinicaCtrl.text.trim(),
                    });

                if (!mounted) return;
                navigator.pop();
                setState(() {});
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('¡Perfil profesional actualizado con éxito!'),
                  ),
                );
              },
              child: const Text('Guardar cambios'),
            ),
          ],
        );
      },
    );
  }

  // Ficha y listado de Pacientes (Niños registrados) + Observaciones clínicas
  void _mostrarPacientes(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pacientes Infantiles Registrados',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Toca un paciente para ver su ficha y registrar observaciones.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error al cargar: ${snapshot.error}'),
                          );
                        }

                        final todos = snapshot.data?.docs ?? [];
                        final docs = todos.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final r =
                              (data['role'] ??
                                      data['rol'] ??
                                      data['tipo'] ??
                                      '')
                                  .toString()
                                  .toLowerCase();
                          return r.contains('nino') ||
                              r.contains('niño') ||
                              r.contains('alumno') ||
                              r.contains('hijo');
                        }).toList();

                        if (docs.isEmpty) {
                          return const Center(
                            child: Text(
                              'Aún no hay pacientes infantiles registrados.',
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final nombreCompleto =
                                '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'
                                    .trim();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.face),
                                ),
                                title: Text(
                                  nombreCompleto.isEmpty
                                      ? (data['email'] ?? 'Paciente')
                                      : nombreCompleto,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Edad: ${data['edad'] ?? 'N/A'} años • Correo: ${data['email'] ?? ''}',
                                ),
                                trailing: const Icon(Icons.medical_services),
                                onTap: () => _mostrarFichaPaciente(
                                  context,
                                  doc.id,
                                  data,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Ficha individual del paciente con registro de evaluación odontológica
  void _mostrarFichaPaciente(
    BuildContext context,
    String pacienteUid,
    Map<String, dynamic> data,
  ) {
    final notaCtrl = TextEditingController(
      text: data['observacionDentista'] ?? '',
    );
    final puntos = data['puntos'] ?? 0;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Ficha: ${data['nombre'] ?? 'Paciente'} ${data['apellido'] ?? ''}',
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Correo: ${data['email'] ?? ''}'),
                Text('Edad: ${data['edad'] ?? 'No especificada'} años'),
                Text('Género: ${data['genero'] ?? 'No especificado'}'),
                Text(
                  'RUT Apoderado: ${data['apoderadoRut'] ?? 'No vinculado'}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Puntos de cepillado acumulados: $puntos ⭐',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notaCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Diagnóstico / Recomendación dental',
                    hintText: 'Ej: Reforzar cepillado en molares posteriores',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(context);

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(pacienteUid)
                    .update({
                      'observacionDentista': notaCtrl.text.trim(),
                      'ultimaRevision': FieldValue.serverTimestamp(),
                    });

                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Observación clínica guardada en la ficha.'),
                  ),
                );
              },
              child: const Text('Guardar ficha'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Dentista')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final userData =
                snapshot.data?.data() as Map<String, dynamic>? ?? {};
            final nombre = userData['nombre'] ?? '';

            return Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      nombre.isEmpty
                          ? 'Bienvenido, Doctor(a)'
                          : 'Bienvenido, Dr(a). $nombre',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if ((userData['especialidad'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          userData['especialidad'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 220,
                      child: ElevatedButton.icon(
                        onPressed: () => _mostrarPerfilDentista(
                          context,
                          userData,
                          currentUid ?? '',
                        ),
                        icon: const Icon(Icons.person),
                        label: const Text('Mi perfil'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 220,
                      child: ElevatedButton.icon(
                        onPressed: () => _mostrarPacientes(context),
                        icon: const Icon(Icons.people),
                        label: const Text('Pacientes'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 220,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          await AuthService().signOut();
                          if (!mounted) return;
                          navigator.pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const WelcomeScreen(),
                            ),
                            (r) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade100,
                        ),
                        icon: const Icon(Icons.logout),
                        label: const Text('Cerrar sesión'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
