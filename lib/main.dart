import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Shader Demo',
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
  Offset lightPosition = const Offset(0.5, 0.5); // Default light position
  AnimationController? _animationController;
  Animation<Offset>? _animation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 500), // Adjust the duration as needed
    );

    accelerometerEventStream().listen((AccelerometerEvent event) {
      final newLightPosition = Offset(
        (event.x + 10) / 20,
        (event.y + 10) / 20,
      );

      _animation =
          Tween<Offset>(begin: lightPosition, end: newLightPosition).animate(
        CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
      )..addListener(() => setState(() {
                lightPosition = _animation!.value;
              }));

      _animationController!.reset();
      _animationController!.forward();
    });
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  void _updateLightPosition(Offset localPosition, Size size) {
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
        onPanUpdate: (details) => _updateLightPosition(
            details.localPosition, MediaQuery.of(context).size),
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
  ShaderPainter({required this.shader, required this.lightPosition});
  ui.FragmentShader shader;
  Offset lightPosition;

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, lightPosition.dx); // Update light x position
    shader.setFloat(3, lightPosition.dy); // Update light y position

    final paint = Paint()..shader = shader;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Repaint whenever the light position changes
  }
}
