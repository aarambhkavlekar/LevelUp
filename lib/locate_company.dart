import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_emp.dart';
import 'dart:async';

// --- Theme & Color Definitions (No Change) ---
const Color _parchmentColor = Color(0xFFF3E0B5);
const Color _cardColor = Color(0xFFFCF7E0);
const Color _textColor = Color(0xFF2C2C2C);
const Color _accentColor = Color(0xFF4C588A);
const Color _viewButtonColor = Color(0xFF4C588A);

// --- Helper function to safely parse latitude/longitude ---
double _parseDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

// --- NEW Helper to parse the Recruiter's single 'location' string ---
LatLng _parseRecruiterLocation(String? locationString) {
  if (locationString == null || locationString.isEmpty) {
    return const LatLng(0.0, 0.0); // Default/Error location
  }
  
  // The format is "latitude,longitude" (e.g., "15.370194444444445,74.06438888888888")
  final parts = locationString.split(',');
  
  if (parts.length != 2) {
    print('Error parsing location string: $locationString');
    return const LatLng(0.0, 0.0);
  }

  // Attempt to parse the two parts
  final lat = double.tryParse(parts[0].trim()) ?? 0.0;
  final lng = double.tryParse(parts[1].trim()) ?? 0.0;
  
  return LatLng(lat, lng);
}


// --- Data Model Structures (RecruiterCompany FIX) ---

class RecruiterCompany {
  final String id;
  final String name;
  final String logoAssetPath; 
  final LatLng location;
  final String sector;

  RecruiterCompany({
    required this.id,
    required this.name,
    required this.logoAssetPath,
    required this.location,
    required this.sector,
  });

  // ⚠️ FIX IS HERE: Parsing the single 'location' field.
  factory RecruiterCompany.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    
    // Get the single location string from the document
    final String? locationString = data?['location'] as String?;
    
    // Parse the single string into a LatLng object
    final LatLng parsedLocation = _parseRecruiterLocation(locationString);

    return RecruiterCompany(
      id: doc.id,
      // Use 'name' field from the document as shown in the screenshot
      name: data?['name'] as String? ?? 'Unnamed Company', 
      logoAssetPath: data?['logoUrl'] as String? ?? 'assets/placeholder.png', 
      location: parsedLocation,
      // Assuming 'sector' is a field in the document (if not, you'll need to update this)
      sector: data?['sector'] as String? ?? 'Technology', 
    );
  }
}

class Employee {
  final String email;
  final String name;
  final LatLng location;

  Employee({
    required this.email,
    required this.name,
    required this.location,
  });

  // Employee data still assumes separate 'latitude' and 'longitude' fields 
  // as per the first screenshot of the 'employees' collection. (NO CHANGE HERE)
  factory Employee.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    final double lat = _parseDouble(data?['latitude']);
    final double lng = _parseDouble(data?['longitude']);

    return Employee(
      email: data?['email'] as String? ?? 'N/A',
      name: '${data?['firstName'] ?? ''} ${data?['lastName'] ?? ''}'.trim(),
      location: LatLng(lat, lng),
    );
  }
}


// --- Firestore Data Service (NO CHANGE REQUIRED HERE, as the fix was in the Model) ---

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Distance _distance = const Distance();
  static const double _MAX_DISTANCE_KM = 30.0;
  
  Future<Employee> fetchEmployeeByEmail(String email) async {
    final querySnapshot = await _firestore
        .collection('employees')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception("Employee data not found for email: $email");
    }
    return Employee.fromFirestore(querySnapshot.docs.first);
  }

  Future<List<RecruiterCompany>> fetchNearbyRecruiters(LatLng employeeLocation) async {
    // 1. Fetch ALL recruiter documents
    final querySnapshot = await _firestore.collection('recruiters').get();

    // 2. Convert Firestore documents to RecruiterCompany objects (uses the corrected factory)
    final allCompanies = querySnapshot.docs.map((doc) => RecruiterCompany.fromFirestore(doc)).toList();

    // 3. Client-side Filtering based on the 30km radius (This logic remains correct)
    final nearbyCompanies = allCompanies.where((company) {
      final double distanceMeters = _distance(employeeLocation, company.location);
      return distanceMeters / 1000.0 <= _MAX_DISTANCE_KM;
    }).toList();

    return nearbyCompanies;
  }
}

// --- LocationBasedSearchPage Widget (No Change) ---

class LocationBasedSearchPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const LocationBasedSearchPage(this.userData, {super.key} );

  @override
  State<LocationBasedSearchPage> createState() => _LocationBasedSearchPageState();
}

// ... (Rest of the _LocationBasedSearchPageState and UI builders are unchanged)
// They remain the same as the previous version, as the fix was only in the data model.
class _LocationBasedSearchPageState extends State<LocationBasedSearchPage> {
  Employee? _currentEmployee;
  List<RecruiterCompany> _nearbyCompanies = [];
  bool _isLoading = true;
  String? _errorMessage;

  final DatabaseService _dbService = DatabaseService();
  final MapController _mapController = MapController();
  final LatLng _defaultLocation = const LatLng(12.9716, 77.5946); 

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
      final String? userEmail = widget.userData['email'];

      if (userEmail == null) {
        throw Exception("User email not found in passed data.");
      }

      final employee = await _dbService.fetchEmployeeByEmail(userEmail);
      final companies = await _dbService.fetchNearbyRecruiters(employee.location);

      setState(() {
        _currentEmployee = employee;
        _nearbyCompanies = companies;
        _isLoading = false;
      });

      _mapController.move(employee.location, 13.0);

    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load data. Error: ${e.toString()}";
        _isLoading = false;
      });
      print("Firestore Data Error: $e");
    }
  }

  // --- Widget Builders (Skipped for brevity as they are unchanged) ---
  Widget _buildCompanyCard(RecruiterCompany company) {
     return Container( /* ... full implementation ... */
       margin: const EdgeInsets.only(bottom: 12),
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: _textColor.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))]),
       child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
         Row(children: [
           Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _accentColor.withOpacity(0.3))), child: Center(child: Text(company.name[0], style: GoogleFonts.merriweather(color: _accentColor, fontWeight: FontWeight.bold)))),
           const SizedBox(width: 15),
           Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
             Text(company.name, style: GoogleFonts.merriweather(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
             Text(company.sector, style: GoogleFonts.openSans(fontSize: 12, color: _textColor.withOpacity(0.6))),
           ]),
         ]),
        //  ElevatedButton(onPressed: () {ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Viewing ${company.name} details...')));},
        //    style: ElevatedButton.styleFrom(backgroundColor: _viewButtonColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
        //    child: Text('VIEW', style: GoogleFonts.openSans(color: Colors.white, fontWeight: FontWeight.bold)),
        //  ),
       ]),
     );
  }
  
  Widget _buildMapContainer() {
    final LatLng currentCenter = _currentEmployee?.location ?? _defaultLocation;
    List<Marker> markers = [];
    if (_currentEmployee != null) { markers.add(Marker(point: _currentEmployee!.location, width: 40, height: 40, child: const Icon(Icons.person_pin, color: Colors.blue, size: 40))); }
    markers.addAll(_nearbyCompanies.map((company) => Marker(point: company.location, width: 30, height: 30, child: const Icon(Icons.business_center, color: Colors.red, size: 30))));

    return Container(
      height: 350, margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(20), border: Border.all(color: _accentColor, width: 2), boxShadow: [BoxShadow(color: _textColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
      child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Stack(children: [
        FlutterMap(mapController: _mapController, options: MapOptions(initialCenter: currentCenter, initialZoom: 13.0, minZoom: 2.0, maxZoom: 18.0), children: [
          TileLayer(
            urlTemplate: 'https://api.maptiler.com/maps/basic-v2/256/{z}/{x}/{y}.png?key=0bN9q4mquEAQ2e0l4MT8',
            userAgentPackageName: 'com.example.levelup',
            maxZoom: 19,
            retinaMode: true,
          ),
          MarkerLayer(markers: markers),
        ]),
        Positioned(top: 15, left: 20, right: 20, child: Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
          child: Text('Employee Location & Nearby Companies', textAlign: TextAlign.center, style: GoogleFonts.merriweather(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        )),
      ])),
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
         leading: GestureDetector(
          onTap: () {
            // Navigate to the desired page
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => EmployeeDashboard(widget.userData)),
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
        
      ),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildMapContainer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: _isLoading ? const Center(child: CircularProgressIndicator(color: _accentColor))
                : _errorMessage != null ? Center(child: Text('Error: $_errorMessage', style: GoogleFonts.openSans(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('NEAR BY COMPANIES (Within 30km)', style: GoogleFonts.merriweather(fontSize: 16, fontWeight: FontWeight.w800, color: _textColor.withOpacity(0.8), letterSpacing: 1.5)),
                    const SizedBox(height: 10),
                    if (_nearbyCompanies.isEmpty) Padding(padding: const EdgeInsets.only(top: 15), child: Text("No companies found within 30km radius of your location.", style: GoogleFonts.openSans(color: _textColor.withOpacity(0.7))))
                    else Column(children: _nearbyCompanies.map(_buildCompanyCard).toList()),
                  ]),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }
}