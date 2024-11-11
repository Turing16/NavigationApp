import 'package:aftermidtermcompass/map.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math' as math;

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Sensor subscriptions
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<Position>? _positionSubscription;

  List<double> _accelerometerValues = [0.0, 0.0, 0.0];
  List<double> _magnetometerValues = [0.0, 0.0, 0.0];

  double _deviceAzimuth = 0.0;
  double _targetBearing = 0.0;
  double _pointerRotation = 0.0;

  // Target location (example: San Francisco)
  final double targetLatitude = 30.892657744694873;
  final double targetLongitude = 75.87247505760351;

  double _sheetHeight = 100.0; // Initial height of map sheet
  static const double _minSheetHeight = 80; // Height of handle area
  late double _maxSheetHeight;

  CameraController? cameraController;

  @override
  void initState() {
    super.initState();

    _checkLocationPermission();

    // Gyroscope subscription
    _gyroscopeSubscription = gyroscopeEventStream(samplingPeriod: SensorInterval.normalInterval).listen((GyroscopeEvent event) {
      _updateRotationFromGyroscope(event);
    });

    // Accelerometer subscription
    _accelerometerSubscription = accelerometerEventStream(samplingPeriod: SensorInterval.normalInterval).listen((AccelerometerEvent event) {
      _accelerometerValues = [event.x, event.y, event.z];
    });

    // Magnetometer subscription
    _magnetometerSubscription = magnetometerEventStream(samplingPeriod: SensorInterval.normalInterval).listen((MagnetometerEvent event) {
      _magnetometerValues = [event.x, event.y, event.z];
      _updatePointerRotation(); // Use both accelerometer + magnetometer
    });

    _setupCameraController();
  }

  double _calculateAzimuthFromSensors(double ax, double ay, double az, double mx, double my, double mz) {
    // Normalize accelerometer vector
    double normA = math.sqrt(ax * ax + ay * ay + az * az);
    ax /= normA;
    ay /= normA;
    az /= normA;

    // Normalize magnetometer vector
    double normM = math.sqrt(mx * mx + my * my + mz * mz);
    mx /= normM;
    my /= normM;
    mz /= normM;

    // Calculate rotation matrix elements (simplified for 2D)
    double hx = my * az - mz * ay;
    double hy = mz * ax - mx * az;

    // Compute azimuth in degrees
    double azimuth = math.atan2(hy, hx) * (180 / math.pi);

    // Normalize azimuth to [0, 360] degrees
    if (azimuth < 0) azimuth += 360;

    return azimuth;
  }


  // Update rotation from gyroscope (smoother but prone to drift)
  void _updateRotationFromGyroscope(GyroscopeEvent event) {
    setState(() {
      _deviceAzimuth += event.z * (180 / math.pi); // Convert radians to degrees
      if (_deviceAzimuth < 0) _deviceAzimuth += 360;
      if (_deviceAzimuth >= 360) _deviceAzimuth -= 360;
    });
  }


  void _updatePointerRotation() {
    double ax = _accelerometerValues[0];
    double ay = _accelerometerValues[1];
    double az = _accelerometerValues[2];

    double mx = _magnetometerValues[0];
    double my = _magnetometerValues[1];
    double mz = _magnetometerValues[2];

    // Calculate device azimuth from sensors
    double azimuth = _calculateAzimuthFromSensors(ax, ay, az, mx, my, mz);



    setState(() {
      // Adjust pointer rotation by combining gyroscope and sensor-calculated azimuth
      _deviceAzimuth = azimuth; // Correct gyroscope drift with sensor azimuth
      _pointerRotation = _targetBearing - _deviceAzimuth;

      // Normalize the rotation
      if (_pointerRotation < 0) _pointerRotation += 360;
    });
  }

  Future<void> _setupCameraController() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      cameraController = CameraController(cameras.first, ResolutionPreset.high);
      await cameraController!.initialize();
      setState(() {});
    }
  }

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  @override
  void dispose() {
    _gyroscopeSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _positionSubscription?.cancel();
    cameraController?.dispose();
    super.dispose();
  }

  Widget buildCameraView() {
    if (cameraController == null || cameraController?.value.isInitialized == false) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Expanded(
        child: Container(
          child: Stack(
            children: [
              CameraPreview(cameraController!),
              Center(
                child: Transform.rotate(
                angle: _pointerRotation * (math.pi / 180),
                child: const Icon(
                      Icons.navigation,
                      size: 100,
                      color: Colors.blue,
                      ),
                    )
              )
            ]
          )
        )
    );
  }


  Widget buildDragHandle() {
    return Container(
      width: double.infinity,
      height: _minSheetHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(height: 10),
          Container(
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Navigation Map',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMapSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            _sheetHeight = (_sheetHeight - details.delta.dy)
                .clamp(_minSheetHeight, _maxSheetHeight);
          });
        },
        child: Container(
          height: _sheetHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              buildDragHandle(),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  child: MapScreen(

                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Initialize maxSheetHeight in build to ensure we have MediaQuery
    _maxSheetHeight = MediaQuery.of(context).size.height * 0.85; // 85% of screen height

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold( // Makes the body extend behind the AppBar
        appBar: AppBar(
          backgroundColor: Colors.blueAccent,
          elevation: 0,
          title: const Text(
            'Navigation Assistant',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold) ,
          ),
        ),
        body: Stack(
          children: [
            buildCameraView(),
            buildMapSheet(),
          ],
        ),
      ),
    );
  }

}
