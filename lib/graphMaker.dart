import 'dart:convert';
import 'dart:math';

import 'package:dijkstra/dijkstra.dart';

class GraphManager {
  Map<String, List<double>> nodes = {};
  Map<String, Map<String, double>> edges = {};

  // This method parses the GeoJSON and sets up the nodes and edges
  void parseGeoJson(String geoJsonData) {
    // Decode the GeoJSON string into a Dart map
    var decodedData = jsonDecode(geoJsonData);

    // Now `decodedData` is a Map, and we can safely access `features`
    var features = decodedData['features'] as List<dynamic>;

    int nodeId = 0;  // This will keep track of the node IDs

    // Creating nodes and edges from GeoJSON data
    for (var feature in features) {
      var coordinates = feature['geometry']['coordinates'] as List<dynamic>;

      // For each pair of coordinates in the LineString, create an edge
      for (int i = 0; i < coordinates.length - 1; i++) {
        // Add the current node and the next node
        int nodeA = nodeId++;
        int nodeB = nodeId++;

        // Add nodes to the `nodes` map, where key is the node ID and value is the coordinate pair
        nodes[nodeA] = [coordinates[i][0], coordinates[i][1]];
        nodes[nodeB] = [coordinates[i + 1][0], coordinates[i + 1][1]];

        // Add edge with the distance between nodes as weight
        double distance = calculateDistance(coordinates[i], coordinates[i + 1]);

        // Adding the edge from nodeA to nodeB with the calculated distance
        edges.putIfAbsent(nodeA, () => {});
        edges[nodeA]![nodeB] = distance;
      }
    }
  }


  // Calculate the Haversine distance between two points
  double calculateDistance(List<double> pointA, List<double> pointB) {
    const double R = 6371; // Radius of Earth in km
    double lat1 = pointA[1];
    double lon1 = pointA[0];
    double lat2 = pointB[1];
    double lon2 = pointB[0];

    double dLat = _toRad(lat2 - lat1);
    double dLon = _toRad(lon2 - lon1);
    double a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // Distance in km
  }

  double _toRad(double degree) {
    return degree * (pi / 180);
  }

  // Find the nearest node based on the user's current location
  String findNearestNode(double latitude, double longitude) {
    String closestNode = '';
    double minDistance = double.infinity;
    nodes.forEach((node, coords) {
      double dist = calculateDistance([longitude, latitude], coords);
      if (dist < minDistance) {
        minDistance = dist;
        closestNode = node;
      }
    });
    return closestNode;
  }

  // Find the shortest path using Dijkstra's algorithm
  List<String> findShortestPath(
      double startLatitude, double startLongitude, double endLatitude, double endLongitude) {
    String startNode = findNearestNode(startLatitude, startLongitude);
    String endNode = findNearestNode(endLatitude, endLongitude);

    // Create the Dijkstra object
    Dijkstra dijkstra = Dijkstra();
    dijkstra.addAll(edges); // Adding all edges to the Dijkstra object

    // Run Dijkstra's algorithm
    dijkstra.run(startNode);

    // Get the shortest path
    List<String> result = Dijkstra.getShortestPathTo(endNode);
    return result;
  }

  // Get coordinates for the polyline
  List<List<double>> getPathCoordinates(List<String> path) {
    return path.map((id) => nodes[id]!).toList();
  }
}
