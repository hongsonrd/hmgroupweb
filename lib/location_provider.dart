import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';

class LocationData {
  final double? latitude;
  final double? longitude;
  LocationData({this.latitude, this.longitude});
  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      latitude: map['latitude'],
      longitude: map['longitude'],
    );
  }
}

class LocationProvider with ChangeNotifier {
  static const String _lastPositionKey = 'last_position';
  static const String _lastAddressKey = 'last_address';
  
  Position? _position;
  String _address = 'Sai vi tri'; // Fixed address
  bool _isLoadingLocation = false;
  bool _isLoadingAddress = false;
  bool _isInBackground = false;
  DateTime? _lastFetchTime;
  
  Position? get position => _position;
  String get address => _address;
  bool get isLoadingLocation => _isLoadingLocation;
  bool get isLoadingAddress => _isLoadingAddress;
  bool get isInBackground => _isInBackground;
  DateTime? get lastFetchTime => _lastFetchTime;
  
  set isInBackground(bool value) {
    _isInBackground = value;
    notifyListeners();
  }
  
  LocationProvider() {
    _initializeLocationData();
  }
  
  Future<void> _initializeLocationData() async {
    // Always set fixed position and address
    _setFixedPosition();
    await _saveLastPosition();
    await _saveLastAddress();
    notifyListeners();
  }
  
  void _setFixedPosition() {
    _position = Position(
      latitude: 0.0,
      longitude: 0.0,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
    _lastFetchTime = DateTime.now();
  }
  
  Future<void> _saveLastPosition() async {
    if (_position != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String positionJson = json.encode({
        'latitude': _position!.latitude,
        'longitude': _position!.longitude,
        'timestamp': _position!.timestamp.toIso8601String(),
        'accuracy': _position!.accuracy,
        'altitude': _position!.altitude,
        'altitudeAccuracy': _position!.altitudeAccuracy,
        'heading': _position!.heading,
        'headingAccuracy': _position!.headingAccuracy,
        'speed': _position!.speed,
        'speedAccuracy': _position!.speedAccuracy,
      });
      await prefs.setString(_lastPositionKey, positionJson);
    }
  }
  
  Future<void> _saveLastAddress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAddressKey, _address);
  }
  
  LocationData? get locationData {
    if (_position == null) return null;
    return LocationData.fromMap({
      'latitude': _position!.latitude,
      'longitude': _position!.longitude,
    });
  }
  
  Future<void> fetchLocationIfNeeded() async {
    await fetchLocation(); // Always fetch the fixed location
  }
  
  Future<void> fetchLocation() async {
    _isLoadingLocation = true;
    notifyListeners();
    
    // Set fixed position and address
    _setFixedPosition();
    await _saveLastPosition();
    await _saveLastAddress();
    
    _isLoadingLocation = false;
    notifyListeners();
  }
 
  Future<String> getAddressFromLatLng(double lat, double lng) async {
    // Always return the fixed address regardless of input coordinates
    return _address;
  }
}