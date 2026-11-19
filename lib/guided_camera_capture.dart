import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class GuidedCaptureResult {
  const GuidedCaptureResult({required this.bytes, required this.isFront});
  final List<int> bytes;
  final bool isFront;
}

class GuidedCameraCapturePage extends StatefulWidget {
  const GuidedCameraCapturePage({super.key, this.initialIsFront = true});

  final bool initialIsFront;

  @override
  State<GuidedCameraCapturePage> createState() => _GuidedCameraCapturePageState();
}

class _GuidedCameraCapturePageState extends State<GuidedCameraCapturePage> {
  CameraController? _controller;
  Future<void>? _initFuture;
  String? _error;
  bool _savingAsFront = true;
  bool _taking = false;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  bool _showAlignmentWarning = false;

  @override
  void initState() {
    super.initState();
    _savingAsFront = widget.initialIsFront;
    _initFuture = _initCamera();
    _startAlignmentMonitor();
  }

  void _startAlignmentMonitor() {
    _accelSub = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      final misaligned = _isMisaligned(event.x, event.y, event.z);
      if (misaligned != _showAlignmentWarning) {
        setState(() => _showAlignmentWarning = misaligned);
      }
    });
  }

  bool _isMisaligned(double x, double y, double z) {
    final norm = math.sqrt(x * x + y * y + z * z);
    if (norm < 0.01) return false;
    final nx = x / norm;
    final ny = y / norm;
    final nz = z / norm;
    // Upright portrait: device mostly vertical with screen facing user => |ny| large, |nz| moderate, |nx| small.
    final verticalEnough = ny.abs() > 0.72;
    final notTooFlat = nz.abs() < 0.75;
    final notTooTiltedSideways = nx.abs() < 0.45;
    return !(verticalEnough && notTooFlat && notTooTiltedSideways);
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No se encontró una cámara disponible.');
        return;
      }
      CameraDescription selected = cameras.first;
      for (final c in cameras) {
        if (c.lensDirection == CameraLensDirection.back) {
          selected = c;
          break;
        }
      }
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo iniciar la cámara.');
    }
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _taking) return;
    setState(() => _taking = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop(
        GuidedCaptureResult(bytes: bytes, isFront: _savingAsFront),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _taking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo tomar la foto.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF171717);
    const lime = Color(0xFFD7FF55);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Captura guiada'),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : FutureBuilder<void>(
              future: _initFuture,
              builder: (context, snapshot) {
                final controller = _controller;
                if (snapshot.connectionState != ConnectionState.done ||
                    controller == null ||
                    !controller.value.isInitialized) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(controller),
                          const _MeasurementGuideOverlay(),
                          Positioned(
                            left: 16,
                            right: 16,
                            top: 16,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Mantén el celular estable y en posición vertical. Alinea cuello y hombros con las franjas para estimar talla y estatura.',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          if (_showAlignmentWarning)
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 16,
                              child: _AlignmentWarningCard(),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Text('Frontal'),
                                    selected: _savingAsFront,
                                    onSelected: (_) => setState(() => _savingAsFront = true),
                                    selectedColor: lime,
                                    labelStyle: TextStyle(
                                      color: _savingAsFront ? ink : Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    backgroundColor: const Color(0xFF2A2A2A),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Text('Lateral'),
                                    selected: !_savingAsFront,
                                    onSelected: (_) => setState(() => _savingAsFront = false),
                                    selectedColor: lime,
                                    labelStyle: TextStyle(
                                      color: !_savingAsFront ? ink : Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    backgroundColor: const Color(0xFF2A2A2A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: FilledButton.icon(
                                onPressed: _taking ? null : _takePicture,
                                icon: const Icon(Icons.camera_alt),
                                label: Text(
                                  _taking
                                      ? 'CAPTURANDO...'
                                      : 'TOMAR FOTO ${_savingAsFront ? 'FRONTAL' : 'LATERAL'}',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: lime,
                                  foregroundColor: ink,
                                  disabledBackgroundColor: Colors.white24,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _AlignmentWarningCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xE61A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7FF55), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.screen_rotation_alt, color: Color(0xFFD7FF55), size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Alinea bien el celular',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sostén el teléfono en vertical y estable (no en diagonal ni horizontal).',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _PhoneExample(aligned: true),
                    const SizedBox(width: 14),
                    const Icon(Icons.close, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 6),
                    _PhoneExample(aligned: false),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneExample extends StatelessWidget {
  const _PhoneExample({required this.aligned});
  final bool aligned;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: aligned ? 0 : 0.7,
          child: Container(
            width: 22,
            height: 38,
            decoration: BoxDecoration(
              color: aligned ? const Color(0xFFD7FF55) : Colors.white24,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: aligned ? const Color(0xFFD7FF55) : Colors.white54,
                width: 2,
              ),
            ),
            child: Icon(
              aligned ? Icons.check : Icons.priority_high,
              size: 14,
              color: aligned ? Colors.black : Colors.white70,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          aligned ? 'Correcto' : 'Evitar',
          style: TextStyle(
            color: aligned ? const Color(0xFFD7FF55) : Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MeasurementGuideOverlay extends StatelessWidget {
  const _MeasurementGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _MeasurementGuidePainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MeasurementGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final framePaint = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final guidePaint = Paint()
      ..color = const Color(0xFFD7FF55).withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final bandPaint = Paint()
      ..color = const Color(0xFFD7FF55).withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final left = size.width * 0.12;
    final right = size.width * 0.88;
    final top = size.height * 0.08;
    final bottom = size.height * 0.95;
    final bodyRect = Rect.fromLTRB(left, top, right, bottom);
    final rrect = RRect.fromRectAndRadius(bodyRect, const Radius.circular(16));
    canvas.drawRRect(rrect, framePaint);

    // Neck guide band
    final neckY = top + bodyRect.height * 0.16;
    final neckBand = Rect.fromLTRB(left + 20, neckY - 10, right - 20, neckY + 10);
    canvas.drawRect(neckBand, bandPaint);
    canvas.drawLine(Offset(left + 20, neckY), Offset(right - 20, neckY), guidePaint);

    // Shoulder guide line
    final shoulderY = top + bodyRect.height * 0.23;
    canvas.drawLine(Offset(left + 8, shoulderY), Offset(right - 8, shoulderY), guidePaint);
    // Shoulder width markers
    canvas.drawLine(Offset(left + 8, shoulderY - 12), Offset(left + 8, shoulderY + 12), guidePaint);
    canvas.drawLine(Offset(right - 8, shoulderY - 12), Offset(right - 8, shoulderY + 12), guidePaint);

    // Center axis for posture/height reference
    final axisPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width / 2, top),
      Offset(size.width / 2, bottom),
      axisPaint,
    );

    // Height markers
    for (final p in [0.4, 0.6, 0.8]) {
      final y = top + bodyRect.height * p;
      canvas.drawLine(Offset(left, y), Offset(left + 18, y), axisPaint);
      canvas.drawLine(Offset(right - 18, y), Offset(right, y), axisPaint);
    }

    _drawLabel(canvas, size, Offset(left + 24, neckY - 28), 'CUELLO');
    _drawLabel(canvas, size, Offset(left + 24, shoulderY + 14), 'HOMBROS');
    _drawLabel(canvas, size, Offset(size.width / 2 - 28, bottom - 26), 'ESTATURA');
  }

  void _drawLabel(Canvas canvas, Size size, Offset offset, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFFD7FF55),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
