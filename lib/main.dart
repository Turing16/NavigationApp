import 'package:aftermidtermcompass/map.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
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

  // Sensor values
  List<double> _accelerometerValues = [0.0, 0.0, 0.0];
  List<double> _magnetometerValues = [0.0, 0.0, 0.0];

  double _deviceAzimuth = 0.0;
  double _targetBearing = 0.0;
  double _pointerRotation = 0.0;

  // Target location (example: San Francisco)
  final double targetLatitude = 30.892657744694873;
  final double targetLongitude = 75.87247505760351;

  //Camera setup
  List<CameraDescription> cameras = [];
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

  Future<void> _setupCameraController() async{
    List<CameraDescription> _cameras = await availableCameras();
    if(_cameras.isNotEmpty){
      setState(() {
        cameras = _cameras;
        cameraController = CameraController(
            _cameras.first,
            ResolutionPreset.high);
      });
      cameraController?.initialize().then((_){
        setState(() {
          //
        });
      });
    }
  }

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      _startPositionStream();
    }
  }

  void _startPositionStream() {
    LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      double bearing = Geolocator.bearingBetween(
          position.latitude, position.longitude, targetLatitude, targetLongitude);

      setState(() {
        _targetBearing = bearing;
      });
    });
  }

  // Update rotation from gyroscope (smoother but prone to drift)
  void _updateRotationFromGyroscope(GyroscopeEvent event) {
    setState(() {
      _deviceAzimuth += event.z * (180 / math.pi); // Convert radians to degrees
      if (_deviceAzimuth < 0) _deviceAzimuth += 360;
      if (_deviceAzimuth >= 360) _deviceAzimuth -= 360;
    });
  }

  // Use accelerometer and magnetometer to correct gyroscope drift
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

  // Calculate azimuth from accelerometer and magnetometer (for long-term correction)
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

  @override
  void dispose() {
    _gyroscopeSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Widget buildUI(){
    if(cameraController==Null || cameraController?.value.isInitialized == false){
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return Stack(
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
              // child: IgnorePointer(
              //   ignoring: true,
              //   child: Cube(
              //     onSceneCreated: (Scene scene){
              //       scene.world.add(Object(
              //         scale: Vector3.all(2.0),
              //         rotation: Vector3(0, 0, 0),
              //         fileName: 'assets/arrow2/Arrow5.obj'
              //       ));
              //     },
              //   ),
              // ),
            ),
          )

        ]
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Pointer to Target')),
        body: buildUI()
      ),
    );
  }
}
