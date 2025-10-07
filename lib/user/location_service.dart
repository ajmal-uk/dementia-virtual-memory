import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PatientLocationService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  Timer? _updateTimer;
  bool _isSharing = false;

  
  Future<bool> _checkLocationService() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('Error checking location service: $e');
      return false;
    }
  }

  
  Future<bool> _requestLocationPermission(BuildContext context) async {
    try {
      
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          await _showPermissionDialog(
            context,
            'Location Permission Permanently Denied',
            'Location permission has been permanently denied. Please enable it in app settings to share your location.',
          );
        }
        return false;
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        
        if (permission == LocationPermission.denied) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission is required to share location')),
            );
          }
          return false;
        }
        
        if (permission == LocationPermission.deniedForever) {
          if (context.mounted) {
            await _showPermissionDialog(
              context,
              'Location Permission Denied',
              'Location permission has been denied. Please enable it in app settings to share your location.',
            );
          }
          return false;
        }
      }

      return permission == LocationPermission.always || 
             permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error requesting location permission: $e')),
        );
      }
      return false;
    }
  }

  
  Future<void> _showPermissionDialog(BuildContext context, String title, String content) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  
  Future<void> startSharingLocation(BuildContext context) async {
    if (_isSharing) {
      debugPrint('Location sharing already active');
      return;
    }

    try {
      
      final serviceEnabled = await _checkLocationService();
      if (!serviceEnabled) {
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Location Services Disabled'),
              content: const Text('Please enable location services to share your location.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Geolocator.openLocationSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
        return;
      }

      
      final hasPermission = await _requestLocationPermission(context);
      if (!hasPermission) {
        return;
      }

      
      _isSharing = true;
      
      
      await _getAndUpdateLocation(context);
      
      
      _updateTimer = Timer.periodic(const Duration(minutes: 30), (_) {
        _getAndUpdateLocation(context);
      });

      debugPrint('Location sharing started successfully with periodic updates');

    } catch (e) {
      debugPrint('Error starting location sharing: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting location sharing: $e')),
        );
      }
      _isSharing = false;
    }
  }

  
  Future<void> _getAndUpdateLocation(BuildContext context) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 30),
      );
      await _updateLocationInFirestore(position);
    } catch (e) {
      debugPrint('Error getting location: $e');
      _handleLocationError(e, context);
    }
  }

  
  Future<void> _updateLocationInFirestore(Position position) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        debugPrint('No user logged in');
        return;
      }

      await _firestore.collection("user").doc(uid).update({
        "currentLat": position.latitude,
        "currentLng": position.longitude,
        "locationTimestamp": FieldValue.serverTimestamp(),
      });
      
      debugPrint('Location updated: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint("Error updating location in Firestore: $e");
    }
  }

  
  void _handleLocationError(dynamic error, BuildContext context) {
    debugPrint('Location error: $error');
    
    if (error is LocationServiceDisabledException) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services have been disabled')),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: ${error.toString()}')),
        );
      }
    }
  }

  
  Future<void> stopSharingLocation() async {
    try {
      _updateTimer?.cancel();
      _updateTimer = null;
      _isSharing = false;
      debugPrint('Location sharing stopped');
    } catch (e) {
      debugPrint('Error stopping location sharing: $e');
    }
  }

  
  bool get isSharing => _isSharing;


  void dispose() {
    _updateTimer?.cancel();
    _updateTimer = null;
    _isSharing = false;
  }
}