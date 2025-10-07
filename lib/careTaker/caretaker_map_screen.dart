import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CaretakerMapScreen extends StatefulWidget {
  final String patientId;

  const CaretakerMapScreen({super.key, required this.patientId});

  @override
  State<CaretakerMapScreen> createState() => _CaretakerMapScreenState();
}

class _CaretakerMapScreenState extends State<CaretakerMapScreen> {
  GoogleMapController? _mapController;
  LatLng? _patientLocation;
  Set<Marker> _markers = {};

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(20.5937, 78.9629),
    zoom: 4,
  );

  @override
  void initState() {
    super.initState();
  }

  void _recenter() {
    if (_patientLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_patientLocation!, 16),
      );
    }
  }

  Marker _buildPatientMarker(LatLng position) {
    return Marker(
      markerId: const MarkerId("patient"),
      position: position,
      infoWindow: const InfoWindow(title: "Patient Location"),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Patient Map"),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _recenter,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('user').doc(widget.patientId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final double lat = data?['currentLat'] as double? ?? 0.0;
          final double lng = data?['currentLng'] as double? ?? 0.0;
          final newLocation = LatLng(lat, lng);

   
          if (_patientLocation == null || _patientLocation != newLocation) {
            _patientLocation = newLocation;
            _markers = {_buildPatientMarker(_patientLocation!)};
          
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _recenter();
            });
          }

          return GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _recenter();
            },
            initialCameraPosition: _initialCamera,
            markers: _markers,
            zoomControlsEnabled: true,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _recenter,
        child: const Icon(Icons.location_searching),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}