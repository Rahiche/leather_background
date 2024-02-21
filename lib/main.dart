import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leather background demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  Offset lightPosition = const Offset(0.5, 0.5);
  AnimationController? _animationController;
  Animation<Offset>? _animation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    accelerometerEventStream().listen(_handleAccelerometerEvent);
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    final Offset newLightPosition = Offset(
      (event.x + 10) / 20,
      (event.y + 10) / 20,
    );

    _configureLightPositionAnimation(newLightPosition);

    _animationController!.reset();
    _animationController!.forward();
  }

  void _configureLightPositionAnimation(Offset newLightPosition) {
    _animation =
        Tween<Offset>(begin: lightPosition, end: newLightPosition).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
    );

    _animation!.addListener(() {
      setState(() => lightPosition = _animation!.value);
    });
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  void _updateLightPosition(Offset localPosition, Size size) {
    _animationController?.stop();
    setState(() {
      lightPosition = Offset(
        localPosition.dx / size.width,
        localPosition.dy / size.height,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onPanEnd: (_) => _animationController?.reset(),
        onPanUpdate: (details) => _updateLightPosition(
          details.localPosition,
          MediaQuery.sizeOf(context),
        ),
        child: SizedBox.expand(
          child: ShaderBuilder(
            (context, shader, child) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: ShaderPainter(
                  shader: shader,
                  lightPosition: lightPosition,
                ),
              );
            },
            assetKey: 'shaders/leather.frag',
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ),
    );
  }
}

class ShaderPainter extends CustomPainter {
  ShaderPainter({
    required this.shader,
    required this.lightPosition,
  });

  ui.FragmentShader shader;
  Offset lightPosition;

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, lightPosition.dx);
    shader.setFloat(3, lightPosition.dy);

    final paint = Paint()..shader = shader;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ShaderPainter oldDelegate) {
    return oldDelegate.lightPosition != lightPosition;
  }
}
