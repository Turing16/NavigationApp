import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {

  List<LatLng> route = [

    LatLng(30.889034833728658, 75.87234993106534),
    LatLng(30.88903799246809, 75.87230584104702),
    LatLng(30.889043258159077, 75.8722311168967),
    LatLng(30.889048525254495, 75.87217230117031),
    LatLng(30.889054847625616, 75.87208528046173),
    LatLng(30.889060117815973, 75.87200559245662),
    LatLng(30.889063280604887, 75.87194428654479),
  ];
  LatLng? selectedDestination;
  MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: map()
    );
  }

  Widget map(){
    return FlutterMap(
        options: const MapOptions(
            initialCenter: LatLng(30.888944724091047, 75.87145081086157),
            initialZoom: 16,
            minZoom: 8,
            maxZoom: 20,
            interactionOptions: InteractionOptions(flags: InteractiveFlag.all)
        ),
        children: [
          openStreetMapLayer,
          PolylineLayer(polylines: [
            Polyline(
                points: route,
                strokeWidth: 4.0,
                color: Colors.blue
            )
          ])
        ]);
  }

  TileLayer get openStreetMapLayer => TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'dev.fleaflet.flutter.flutter_map.example',
  );

}