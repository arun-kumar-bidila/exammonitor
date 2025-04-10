import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MaterialApp(home: CameraApp()));
}

class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late CameraController controller;
  late FaceDetector faceDetector;
  String status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    controller = CameraController(cameras[1], ResolutionPreset.medium);
    faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
        enableTracking: true,
      ),
    );

    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _startAnalyzing();
    });
  }

  Future<void> _startAnalyzing() async {
    Timer.periodic(Duration(seconds: 3), (timer) async {
      XFile? file;
      try {
        file = await controller.takePicture();
        final inputImage = InputImage.fromFilePath(file.path);
        final faces = await faceDetector.processImage(inputImage);

        if (faces.isNotEmpty) {
          final yaw = faces[0].headEulerAngleY ?? 0;
          setState(() {
            status = yaw.abs() > 20
                ? '🚨 Cheating Detected (Yaw: ${yaw.toStringAsFixed(1)})'
                : '✅ Okay (Yaw: ${yaw.toStringAsFixed(1)})';
          });
        } else {
          setState(() {
            status = '😐 No Face Detected';
          });
        }
      } catch (e) {
        print('Error during detection: $e');
        setState(() {
          status = '⚠️ Detection Error';
        });
      } finally {
        if (file != null) {
          final imgFile = File(file.path);
          if (await imgFile.exists()) {
            try {
              await imgFile.delete();
            } catch (e) {
              print('Failed to delete image: $e');
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: Text("Exam Monitor")),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
          SizedBox(height: 10),
          Text(status, style: TextStyle(fontSize: 24)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    faceDetector.close();
    super.dispose();
  }
}
