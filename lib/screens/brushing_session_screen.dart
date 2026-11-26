import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class BrushingSessionScreen extends StatefulWidget {
  final String childId;
  final String childName;

  const BrushingSessionScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<BrushingSessionScreen> createState() => _BrushingSessionScreenState();
}

class _BrushingSessionScreenState extends State<BrushingSessionScreen> {
  static const int _totalSeconds = 120;
  int _remainingSeconds = _totalSeconds;
  Timer? _timer;
  bool _isRunning = false;
  bool _isSaving = false;

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  String _cameraStatusMessage =
      'Presiona "Iniciar sesion" para activar la camara espejo';

  String _estadoEvidencia = 'Pendiente';
  String? _fotoBase64;
  bool _capturaAutomaticaRealizada = false;

  final List _zonas = [
    {
      'titulo': 'Zona 1/4: Muelas superiores derechas e izquierdas',
      'instruccion': 'Movimiento de barrido suave desde la encia hacia abajo.',
    },
    {
      'titulo': 'Zona 2/4: Dientes frontales superiores e inferiores',
      'instruccion': 'Cepilla en circulos suaves por delante y por detras.',
    },
    {
      'titulo': 'Zona 3/4: Muelas inferiores izquierdas',
      'instruccion': 'Limpia la superficie con la que masticas y los costados.',
    },
    {
      'titulo': 'Zona 4/4: Muelas inferiores derechas y lengua',
      'instruccion': 'Termina barriendo suavemente las muelas y la lengua.',
    },
  ];

  int get _zonaActualIndex {
    final elapsed = _totalSeconds - _remainingSeconds;
    final index = elapsed ~/ 30;
    return index.clamp(0, _zonas.length - 1);
  }

  Future<void> _inicializarCamaraEnVivo() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      setState(() {
        _estadoEvidencia = 'Permiso de camara rechazado';
        _cameraStatusMessage =
            'Permiso denegado. La sesion continuara sin camara.';
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _estadoEvidencia = 'Sin camara disponible';
          _cameraStatusMessage = 'No se detecto camara en el dispositivo.';
        });
        return;
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
        _estadoEvidencia = 'Camara activa en vivo';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _estadoEvidencia = 'Error al iniciar camara';
        _cameraStatusMessage = 'No se pudo abrir la vista previa de camara.';
      });
    }
  }

  Future<void> _capturarFotoEvidencia({bool silenciosa = false}) async {
    if (!_isCameraInitialized || _cameraController == null) return;
    if (_cameraController!.value.isTakingPicture) return;

    try {
      final XFile file = await _cameraController!.takePicture();
      final bytes = await file.readAsBytes();
      final base64Img = base64Encode(bytes);

      if (!mounted) return;
      setState(() {
        _fotoBase64 = base64Img;
        _estadoEvidencia = 'Capturada correctamente';
      });

      if (!silenciosa && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de evidencia capturada correctamente'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_fotoBase64 == null) {
          _estadoEvidencia = 'Sin evidencia';
        }
      });
    }
  }

  Future<void> _iniciarSesion() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _cameraStatusMessage = 'Activando camara frontal...';
    });

    await _inicializarCamaraEnVivo();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;

      if (_remainingSeconds <= 1) {
        timer.cancel();
        if (_fotoBase64 == null && _isCameraInitialized) {
          await _capturarFotoEvidencia(silenciosa: true);
        }
        await _finalizarYGuardar(completada: true);
        return;
      }

      setState(() {
        _remainingSeconds--;
      });

      final elapsed = _totalSeconds - _remainingSeconds;
      if (elapsed == 20 &&
          !_capturaAutomaticaRealizada &&
          _isCameraInitialized) {
        _capturaAutomaticaRealizada = true;
        await _capturarFotoEvidencia(silenciosa: false);
      }
    });
  }

  Future<void> _finalizarYGuardar({bool completada = false}) async {
    if (_isSaving) return;
    _timer?.cancel();

    setState(() {
      _isSaving = true;
      _isRunning = false;
    });

    if (_fotoBase64 == null && _isCameraInitialized) {
      await _capturarFotoEvidencia(silenciosa: true);
    }

    final duracionReal = _totalSeconds - _remainingSeconds;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      await FirebaseFirestore.instance.collection('brushing_sessions').add({
        'apoderadoUid': uid,
        'childId': widget.childId,
        'childName': widget.childName,
        'fecha': FieldValue.serverTimestamp(),
        'duracion': duracionReal > 0 ? duracionReal : 1,
        'estado': completada || duracionReal >= 115
            ? 'Completada'
            : 'Finalizada anticipadamente',
        'estadoEvidencia': _fotoBase64 != null
            ? 'Capturada correctamente'
            : _estadoEvidencia,
        if (_fotoBase64 != null) 'evidenciaBase64': _fotoBase64,
      });

      await _cameraController?.dispose();
      _cameraController = null;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesion de cepillado guardada en Firestore.'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al guardar sesion: $e')));
    }
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zonaActual = _zonas[_zonaActualIndex];

    return Scaffold(
      appBar: AppBar(title: Text('Cepillado de ${widget.childName}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade400, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isCameraInitialized && _cameraController != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width:
                                    _cameraController!
                                        .value
                                        .previewSize
                                        ?.height ??
                                    300,
                                height:
                                    _cameraController!
                                        .value
                                        .previewSize
                                        ?.width ??
                                    400,
                                child: CameraPreview(_cameraController!),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.fiber_manual_record,
                                      color: Colors.red,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Camara espejo activa',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_isRunning)
                              Positioned(
                                bottom: 10,
                                right: 10,
                                child: FloatingActionButton.small(
                                  heroTag: 'btnCapturaManual',
                                  backgroundColor: Colors.amber,
                                  tooltip: 'Tomar foto ahora',
                                  onPressed: () =>
                                      _capturarFotoEvidencia(silenciosa: false),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.face_retouching_natural,
                              size: 64,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Text(
                                _cameraStatusMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _formatTime(_remainingSeconds),
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.amber.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    children: [
                      Text(
                        zonaActual['titulo']!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        zonaActual['instruccion']!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Estado evidencia: $_estadoEvidencia',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _fotoBase64 != null
                      ? Colors.green.shade700
                      : Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: _isSaving
                    ? const Center(child: CircularProgressIndicator())
                    : !_isRunning
                    ? ElevatedButton.icon(
                        onPressed: _iniciarSesion,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Iniciar sesion guiada (2 min)'),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _finalizarYGuardar(completada: false),
                        icon: const Icon(Icons.stop),
                        label: const Text('Finalizar y guardar sesion'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
