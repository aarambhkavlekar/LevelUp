import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import 'package:levelup/home_recruiter.dart';

// --- Theme & Color Definitions (No Change) ---
const Color _parchmentColor = Color(0xFFF3E0B5);
const Color _cardColor = Color(0xFFFCF7E0);
const Color _textColor = Color(0xFF2C2C2C);
const Color _accentColor = Color(0xFF4C588A);
const Color _secondaryAccentColor = Color(0xFF8B4513);
const Color _viewButtonColor = Color(0xFF4C588A);

// --- Helper functions (No Change) ---
double _parseDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

LatLng _parseLocationString(String? locationString) {
  if (locationString == null || locationString.isEmpty) {
    return const LatLng(0.0, 0.0);
  }
  final parts = locationString.split(',');
  if (parts.length != 2) {
    return const LatLng(0.0, 0.0);
  }
  final lat = double.tryParse(parts[0].trim()) ?? 0.0;
  final lng = double.tryParse(parts[1].trim()) ?? 0.0;
  return LatLng(lat, lng);
}


// --- Data Model Structures (Minor Renaming/Adaptation) ---

// This model represents the entity LOGGED IN (the Recruiter)
class Recruiter {
  final String email;
  final String name;
  final LatLng location;
  final String organizationName;

  Recruiter({
    required this.email,
    required this.name,
    required this.location,
    required this.organizationName,
  });

  // Factory constructor for Recruiter from Firestore (based on 'recruiters' collection)
  factory Recruiter.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    
    // Recruiter location is the single 'location' string
    final LatLng parsedLocation = _parseLocationString(data?['location'] as String?);

    return Recruiter(
      email: data?['email'] as String? ?? 'N/A',
      name: data?['name'] as String? ?? 'N/A', // Using the 'name' field
      organizationName: data?['organization_name'] as String? ?? 'N/A',
      location: parsedLocation,
    );
  }
}

// This model represents the search results (the Employee)
class Employee {
  final String id;
  final String name;
  final LatLng location;
  final String degree;
  final String department;
  
  Employee({
    required this.id,
    required this.name,
    required this.location,
    required this.degree,
    required this.department,
  });

  // Factory constructor for Employee from Firestore (based on 'employees' collection)
  factory Employee.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    // Employee location uses separate 'latitude' and 'longitude' fields
    final double lat = _parseDouble(data?['latitude']);
    final double lng = _parseDouble(data?['longitude']);

    return Employee(
      id: doc.id,
      name: '${data?['firstName'] ?? ''} ${data?['lastName'] ?? ''}'.trim(),
      location: LatLng(lat, lng),
      degree: data?['degree'] as String? ?? 'N/A',
      department: data?['department'] as String? ?? 'N/A',
    );
  }
}

// --- Firestore Data Service (Querying Logic Reversed) ---

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Distance _distance = const Distance();
  static const double _MAX_DISTANCE_KM = 30.0;

  // 1. Fetch Recruiter location based on unique email (from the recruiters collection).
  Future<Recruiter> fetchRecruiterByEmail(String email) async {
    // Query the 'recruiters' collection
    final querySnapshot = await _firestore
        .collection('recruiters')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception("Recruiter data not found for email: $email");
    }

    return Recruiter.fromFirestore(querySnapshot.docs.first);
  }

  // 2. Fetch and filter Employees within 30km of the Recruiter.
  Future<List<Employee>> fetchNearbyEmployees(LatLng recruiterLocation) async {
    // 1. Fetch ALL employee documents
    final querySnapshot = await _firestore.collection('employees').get();

    // 2. Convert Firestore documents to Employee objects
    final allEmployees = querySnapshot.docs.map((doc) => Employee.fromFirestore(doc)).toList();

    // 3. Client-side Filtering based on the 30km radius
    final nearbyEmployees = allEmployees.where((employee) {
      // Calculate distance in meters between Recruiter and Employee
      final double distanceMeters = _distance(recruiterLocation, employee.location);
      // Check if distance is <= 30km
      return distanceMeters / 1000.0 <= _MAX_DISTANCE_KM;
    }).toList();

    return nearbyEmployees;
  }
}

// --- NEW RecruiterSearchPage Widget ---

class RecruiterSearchPage extends StatefulWidget {
  // Accepts the recruiter's user data map (must contain 'email')
  final Map<String, dynamic> recruiterData;

  const RecruiterSearchPage(this.recruiterData,{super.key});

  @override
  State<RecruiterSearchPage> createState() => _RecruiterSearchPageState();
}

class _RecruiterSearchPageState extends State<RecruiterSearchPage> {
  Recruiter? _currentRecruiter;
  List<Employee> _nearbyEmployees = [];
  bool _isLoading = true;
  String? _errorMessage;

  final DatabaseService _dbService = DatabaseService();
  final MapController _mapController = MapController();
  final LatLng _defaultLocation = const LatLng(12.9716, 77.5946); // Bangalore center fallback

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String? recruiterEmail = widget.recruiterData['email'];

      if (recruiterEmail == null) {
        throw Exception("Recruiter email not found in passed data.");
      }

      // 1. Fetch Recruiter Location from Firestore
      final recruiter = await _dbService.fetchRecruiterByEmail(recruiterEmail);

      // 2. Fetch Nearby Employees from Firestore and filter
      final employees = await _dbService.fetchNearbyEmployees(recruiter.location);

      setState(() {
        _currentRecruiter = recruiter;
        _nearbyEmployees = employees;
        _isLoading = false;
      });

      // Move map view to the recruiter's location
      _mapController.move(recruiter.location, 13.0);

    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load data. Error: ${e.toString()}";
        _isLoading = false;
      });
      print("Firestore Data Error: $e");
    }
  }

  // --- Widget Builders (Updated to display Employee data) ---

  Widget _buildEmployeeCard(Employee employee) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: _textColor.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Name and Details
          Row(
            children: [
              const CircleAvatar(
                radius: 25,
                backgroundColor: _secondaryAccentColor,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.name,
                    style: GoogleFonts.merriweather(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  Text(
                    '${employee.degree} in ${employee.department}',
                    style: GoogleFonts.openSans(
                      fontSize: 12,
                      color: _textColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right side: View Button
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Viewing ${employee.name} profile...')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _viewButtonColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'VIEW',
              style: GoogleFonts.openSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Builds the main map container
  Widget _buildMapContainer() {
    final LatLng currentCenter = _currentRecruiter?.location ?? _defaultLocation;

    List<Marker> markers = [];
    if (_currentRecruiter != null) {
      // 1. Recruiter Marker (Red Pin)
      markers.add(Marker(
        point: _currentRecruiter!.location,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
      ));
    }

    // 2. Employee Markers (Blue Dots)
    markers.addAll(_nearbyEmployees.map((employee) => Marker(
      point: employee.location,
      width: 30,
      height: 30,
      child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 30),
    )));


    return Container(
      height: 350,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: _textColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: currentCenter,
                initialZoom: 13.0,
                minZoom: 2.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://api.maptiler.com/maps/basic-v2/256/{z}/{x}/{y}.png?key=0bN9q4mquEAQ2e0l4MT8',
                  userAgentPackageName: 'com.example.levelup',
                  maxZoom: 19,
                  retinaMode: true,
                ),

                MarkerLayer(markers: markers),
              ],
            ),

            // Map Title Overlay
            Positioned(
              top: 15,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Recruiter Location & Nearby Employees',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.merriweather(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _parchmentColor,
      appBar: AppBar(
        toolbarHeight: 70,
        flexibleSpace: Container( 
          decoration: BoxDecoration(
            gradient: LinearGradient( // Use LinearGradient here
              colors: [
                const Color.fromRGBO(90, 76, 59, 1.0), // Note: use 1.0 for full opacity
                const Color.fromRGBO(120, 101, 78, 1.0),
                const Color.fromARGB(230, 131, 114, 94),
              ],
              // You can also add begin/end properties here
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
              child: const CircleAvatar(
                backgroundImage: AssetImage('assets/images/logo.png'), 
                backgroundColor: Colors.transparent,
                radius: 30,// Placeholder Icon
              ),
          ),
        ],
        // Custom back button example:
        leading: GestureDetector(
          onTap: () {
            // Navigate to the desired page
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RecruiterDashboard(widget.recruiterData)),
            );
          },
            child: Column( 
              children: [
                SizedBox(height: 1),
                Image.asset(
                  'assets/images/back_button.png', // Replace with your image path
                  height: 50, // Adjust height as needed
                ),
                Text('BACK',style: TextStyle(color: Colors.black, fontSize: 10),),
              ],
            )
          
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. The Map Container
            _buildMapContainer(),

            // 2. Loading/Error/Data Handling
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _accentColor))
                  : _errorMessage != null
                      ? Center(
                          child: Text(
                            'Error: $_errorMessage',
                            style: GoogleFonts.openSans(color: Colors.red, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NEAR BY CANDIDATES (Within 30km)',
                              style: GoogleFonts.merriweather(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _textColor.withOpacity(0.8),
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // 3. List of Nearby Employees
                            if (_nearbyEmployees.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 15),
                                child: Text(
                                  "No eligible candidates found within 30km radius of your location.",
                                  style: GoogleFonts.openSans(color: _textColor.withOpacity(0.7)),
                                ),
                              )
                            else
                              Column(
                                children: _nearbyEmployees.map(_buildEmployeeCard).toList(),
                              ),
                          ],
                        ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
