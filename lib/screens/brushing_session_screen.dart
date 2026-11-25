import 'dart:async';
import 'dart:convert';
import 'dart:math';

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
  static const int _totalSeconds = 120; // 2 minutos (RF-06)
  int _secondsLeft = _totalSeconds;
  Timer? _timer;
  bool _isRunning = false;
  bool _isSaving = false; // Evita duplicar la sesión al finalizar

  // Control de cámara real (RF-08)
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _captureTriggered = false;
  late int _randomCaptureSecond;
  String? _evidenceBase64;
  String _evidenceStatus = 'Pendiente';

  @override
  void initState() {
    super.initState();
    // Momento aleatorio durante la sesión activa (entre segundo 15 y 95)
    _randomCaptureSecond = 15 + Random().nextInt(80);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  // Guía por zonas de 30 segundos (RF-07)
  Map<String, String> _getCurrentZone() {
    final elapsed = _totalSeconds - _secondsLeft;
    if (elapsed < 30) {
      return {
        'zona': 'Zona 1/4: Muelas superiores derechas e izquierdas',
        'tecnica': 'Movimiento de barrido suave desde la encía hacia abajo.',
      };
    } else if (elapsed < 60) {
      return {
        'zona': 'Zona 2/4: Dientes frontales superiores',
        'tecnica':
            'Barrido vertical de arriba hacia abajo por fuera y por dentro.',
      };
    } else if (elapsed < 90) {
      return {
        'zona': 'Zona 3/4: Muelas inferiores derechas e izquierdas',
        'tecnica': 'Movimiento de barrido desde la encía hacia arriba y superficies de masticación.',
      };
    } else {
      return {
        'zona': 'Zona 4/4: Dientes frontales inferiores y lengua',
        'tecnica': 'Barrido suave de abajo hacia arriba y limpieza final de la lengua.',
      };
    }
  }

  Future<void> _startSession() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _secondsLeft = _totalSeconds;
      _captureTriggered = false;
      _evidenceBase64 = null;
      _evidenceStatus = 'Sin evidencia';
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      final elapsed = _totalSeconds - _secondsLeft;

      // Disparo aleatorio durante la sesión activa
      if (elapsed == _randomCaptureSecond && !_captureTriggered) {
        _captureTriggered = true;
        await _handleRandomCameraCapture();
      }

      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
        setState(() => _secondsLeft = 0);
        await _finishSession(completedFullTime: true);
      }
    });
  }

  Future<void> _handleRandomCameraCapture() async {
    // 1. Informar al usuario y pedir autorización explícita (Regla de aceptación)
    final bool? userAccepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Verificación de cepillado 📸'),
        content: const Text(
          '¡Momento aleatorio de control! ¿Autorizas activar la cámara real para tomar una fotografía de evidencia durante tu sesión?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No autorizar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Autorizar cámara'),
          ),
        ],
      ),
    );

    if (userAccepted != true) {
      setState(() {
        _evidenceStatus = 'Sin evidencia (usuario no autorizó)';
      });
      return;
    }

    // 2. Pedir permiso real al sistema operativo Android
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _evidenceStatus = 'Sin evidencia (permiso de cámara denegado)';
      });
      return;
    }

    // 3. Inicializar cámara real y capturar fotografía
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _evidenceStatus = 'Sin evidencia (cámara no disponible)';
        });
        return;
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset
            .low, // Resolución baja para guardar fluido en Firestore
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);

      // Espera 2 segundos para estabilizar enfoque/luz y captura
      await Future.delayed(const Duration(seconds: 2));
      final XFile photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();

      await _cameraController?.dispose();
      _cameraController = null;

      if (!mounted) return;
      setState(() {
        _cameraReady = false;
        _evidenceBase64 = base64Encode(bytes);
        _evidenceStatus = 'Capturada correctamente';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Fotografía de evidencia capturada! 🐝')),
      );
    } catch (e) {
      await _cameraController?.dispose();
      _cameraController = null;
      if (!mounted) return;
      setState(() {
        _cameraReady = false;
        _evidenceStatus = 'Sin evidencia (error al acceder a cámara)';
      });
    }
  }

  Future<void> _finishSession({required bool completedFullTime}) async {
    if (_isSaving) return; // Evita duplicación por doble toque
    setState(() => _isSaving = true);
    _timer?.cancel();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final elapsedSeconds = _totalSeconds - _secondsLeft;

      await FirebaseFirestore.instance.collection('brushing_sessions').add({
        'childId': widget.childId,
        'childName': widget.childName,
        'apoderadoUid': user?.uid ?? '',
        'fecha': FieldValue.serverTimestamp(),
        'duracion': elapsedSeconds,
        'estado': completedFullTime
            ? 'Completada'
            : 'Finalizada anticipadamente',
        'evidenciaBase64': _evidenceBase64 ?? '',
        'estadoEvidencia': _evidenceStatus,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sesión guardada en Firebase ($_evidenceStatus).'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al guardar sesión: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final zoneInfo = _getCurrentZone();
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: Text('Cepillado de ${widget.childName}')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_cameraReady && _cameraController != null)
              SizedBox(
                height: 180,
                width: 180,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CameraPreview(_cameraController!),
                ),
              )
            else
              const Icon(
                Icons.cleaning_services,
                size: 72,
                color: Colors.amber,
              ),
            const SizedBox(height: 16),
            Text(
              '$minutes:$seconds',
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      zoneInfo['zona']!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(zoneInfo['tecnica']!, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Estado evidencia: $_evidenceStatus',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            if (!_isRunning)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startSession,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar sesión guiada (2 min)'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => _finishSession(completedFullTime: false),
                  icon: const Icon(Icons.stop),
                  label: Text(
                    _isSaving ? 'Guardando...' : 'Finalizar y guardar sesión',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
