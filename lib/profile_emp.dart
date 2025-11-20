import 'package:flutter/material.dart';
import 'home_emp.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

// Define the EmployeeProfilePage widget
class EmployeeProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EmployeeProfilePage(this.userData, {super.key});

  @override
  State<EmployeeProfilePage> createState() => _EmployeeProfilePageState();
}

class _EmployeeProfilePageState extends State<EmployeeProfilePage> {
  // Use TextEditingControllers to manage the text fields
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _genderController;
  late TextEditingController _locationController;
  late TextEditingController _contactNoController;
  late TextEditingController _emailController;
  // REMOVED: late TextEditingController _qualificationController;

  // NEW STATE VARIABLES FOR STRUCTURED QUALIFICATION
  String? _selectedDegree;
  String? _selectedDepartment;
  String? _selectedStartYear;
  String? _selectedEndYear;

  // New state variables for coordinate entry/storage
  String? _latitude;
  String? _longitude;

  // Key for form validation
  final _formKey = GlobalKey<FormState>();

  // Dropdown options
  final List<String> _degrees = ['Ph.D.', 'M.E.', 'M.Tech.', 'B.E.', 'B.Tech.', 'M.Sc.', 'B.Sc.', 'Other'];
  final List<String> _departments = ['Computer Science', 'IT', 'Civil', 'Electrical', 'Mechanical', 'Chemical', 'Electronics', 'Management', 'Other'];
  
  // List of years from 1980 up to the next year
  final List<String> _years = List<String>.generate(
    DateTime.now().year - 1980 + 2, 
    (i) => (1980 + i).toString()
  ).reversed.toList();

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing data or '----'
    _firstNameController = TextEditingController(text: _getFieldValue('firstName'));
    _lastNameController = TextEditingController(text: _getFieldValue('lastName'));
    _genderController = TextEditingController(text: _getFieldValue('gender'));
    _locationController = TextEditingController(text: _getFieldValue('location'));
    _contactNoController = TextEditingController(text: _getFieldValue('contact'));
    _emailController = TextEditingController(text: _getFieldValue('email'));
    // REMOVED: _qualificationController = TextEditingController(text: _getFieldValue('qualification'));

    // Initialize NEW qualification fields from userData
    _selectedDegree = _getFieldValue('degree');
    _selectedDepartment = _getFieldValue('department', defaultValue: null);
    _selectedStartYear = _getFieldValue('startYear', defaultValue: null);
    _selectedEndYear = _getFieldValue('endYear', defaultValue: null);


    // Initialize coordinates from userData if available
    _latitude = _getFieldValue('latitude', defaultValue: null);
    _longitude = _getFieldValue('longitude', defaultValue: null);
  }

  // Helper function to safely get data from the map (modified to return null if not found and defaultValue is null)
  String? _getFieldValue(String key, {String? defaultValue = '----'}) {
    final value = (widget.userData.containsKey(key) && widget.userData[key] != null)
        ? widget.userData[key].toString()
        : defaultValue;
    
    // Convert '----' or null strings back to actual null for the dropdowns logic
    if (value == '----') return null;
    return value;
  }

  // Dispose controllers when the widget is removed
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _genderController.dispose();
    _locationController.dispose();
    _contactNoController.dispose();
    _emailController.dispose();
    // REMOVED: _qualificationController.dispose();
    super.dispose();
  }

// --- DMS to Decimal Degrees Conversion Logic --- (Unchanged)
  double? _convertDMSToDD(String dms, {required String direction}) {
    // Corrected Regex: Use single backslash inside the pattern string for the linter.
    // This pattern handles the form D°M'S"
    final regex = RegExp('(\\d+)\\°(\\d+)\'([\\d.]+)\\"');
    final match = regex.firstMatch(dms);

    if (match == null) return null;

    try {
      final degrees = double.parse(match.group(1)!);
      final minutes = double.parse(match.group(2)!);
      final seconds = double.parse(match.group(3)!);

      double dd = degrees + (minutes / 60) + (seconds / 3600);

      // Handle negative signs for South (S) and West (W)
      if (dms.contains('S') || dms.contains('W')) {
        dd = -dd;
      }
      
      // Basic validation check
      if (direction == 'latitude' && (dd < -90 || dd > 90)) return null;
      if (direction == 'longitude' && (dd < -180 || dd > 180)) return null;

      return dd;
    } catch (e) {
      print('DMS Parsing error: $e');
      return null;
    }
  }

  // --- Function to update employee data in Firestore using email as the key --- (Unchanged)
  Future<void> updateEmployeeDetailsByEmail({
    required String employeeEmail,
    required Map<String, dynamic> updatedData,
  }) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    CollectionReference employees = firestore.collection('employees');

    try {
      // 1. Query the 'employees' collection to find the document matching the email
      QuerySnapshot snapshot = await employees
          .where('email', isEqualTo: employeeEmail)
          .limit(1) // Limit to 1, as email should be unique
          .get();

      // 2. Check if a document was found
      if (snapshot.docs.isNotEmpty) {
        // Get the DocumentSnapshot of the found document
        DocumentSnapshot document = snapshot.docs.first;
        String documentId = document.id; // Get the Document ID from the snapshot

        // 3. Get the DocumentReference and use the .update() method
        await employees.doc(documentId).update(updatedData);

        print('Employee document with ID $documentId (Email: $employeeEmail) successfully updated!');
      } else {
        // Handle the case where no document matches the email
        throw Exception('No employee document found for email: $employeeEmail');
      }
    } catch (e) {
      print('Error updating employee by email $employeeEmail: $e');
      rethrow;
    }
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      // 1. Collect the updated data from the controllers and new state variables
      final updatedData = {
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'gender': _genderController.text,
        'location': _locationController.text,
        'contact': _contactNoController.text,
        'email': _emailController.text,
        // REMOVED: 'qualification': _qualificationController.text,
        // ADDED: Structured Qualification Fields
        'degree': _selectedDegree ?? '----',
        'department': _selectedDepartment ?? '----',
        'startYear': _selectedStartYear ?? '----',
        'endYear': _selectedEndYear ?? '----',

      };

      // 2. Retrieve the employee's current (original) email address
      String? currentEmployeeEmail = widget.userData['email'] as String?;

      if (currentEmployeeEmail == null || currentEmployeeEmail.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Original email not available. Cannot update profile.')),
          );
        }
        return;
      }

      try {
        // 3. Call the update function
        await updateEmployeeDetailsByEmail(
          employeeEmail: currentEmployeeEmail,
          updatedData: updatedData,
        );

        // 4. If the update was successful, also update the local widget's data
        // NOTE: This updates the local data map so navigating away and back will show the new data.
        widget.userData.addAll(updatedData);

        // 5. Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
        }
      } catch (e) {
        // 6. Show error message if update fails
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update profile: ${e.toString()}')),
          );
        }
      }
    }
  }

  // --- MODIFIED: Manual Coordinate Input Dialog to handle DMS --- (Unchanged)
  void _showManualCoordinatesDialog() {
    // ... (Your existing _showManualCoordinatesDialog code)
    final coordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Location (DMS or DD)'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: coordController,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'Example: 15°20\'24.2"N 74°01\'28.9"E',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Coordinates cannot be empty';
                    }
                    return null;
                  },
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: Text(
                    'Ensure the format is exact (D°M\'S"Direction D°M\'S"Direction) or standard DD format (Lat, Long).',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  String input = coordController.text.trim();
                  double? newLat, newLong;
                  bool isDMS = input.contains('°');

                  if (isDMS) {
                    // Try to parse as DMS
                    final parts = input.toUpperCase().split(RegExp(r'\s+'));
                    if (parts.length < 2) {
                      if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Invalid DMS format. Requires Latitude and Longitude.')),
                         );
                      }
                      return;
                    }
                    
                    // Assuming Latitude is first, Longitude is second
                    newLat = _convertDMSToDD(parts[0], direction: 'latitude');
                    newLong = _convertDMSToDD(parts[1], direction: 'longitude');

                  } else {
                    // Try to parse as Decimal Degrees (Lat, Long)
                    final parts = input.split(RegExp(r',| ')).where((s) => s.isNotEmpty).toList();
                    if (parts.length >= 2) {
                      newLat = double.tryParse(parts[0]);
                      newLong = double.tryParse(parts[1]);
                    }
                  }

                  if (newLat != null && newLong != null) {
                    setState(() {
                      _latitude = newLat.toString();
                      _longitude = newLong.toString();
                    });
                    
                    _locationController.text = '$_latitude, $_longitude';
                    Navigator.pop(context);

                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not parse coordinates. Check format and range.')),
                      );
                    }
                  }
                }
              },
              child: const Text('Save Coordinates'),
            ),
          ],
        );
      },
    );
  }

  // --- Google Maps Redirection Logic (Unchanged) ---
  void _openGoogleMapsForSelection() async {
    // ... (Your existing _openGoogleMapsForSelection code)
    // Check if location services are enabled (Good practice)
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled. Please enable them.')),
        );
      }
      return;
    }

    // A URL that opens Google Maps in selection mode is not standard.
    // We launch Google Maps centered on the user's current location to let them choose.
    final Uri url = Uri.parse('https://www.google.com/maps');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
      
      // IMPORTANT: After launching, the user must manually return to the app.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your location in Google Maps and return to the app.')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0E4C3), // Light tan/beige background
      appBar: AppBar(
        title: Text('Profile',style: GoogleFonts.merriweather(color: Colors.white, fontWeight: FontWeight.bold)),
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
          // 1. Padding for spacing on the right
          Padding(
            padding: const EdgeInsets.only(right: 15.0), 
            child: InkWell(
              child: const CircleAvatar(
                // Replace with your actual logo/image asset
                backgroundImage: AssetImage('assets/images/logo.png'), 
                backgroundColor: Colors.transparent,
                radius: 30,// Placeholder Icon
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header and Profile Picture
              Text(
                'Profile',
                textAlign: TextAlign.center,
                style: GoogleFonts.merriweather(color: const Color.fromRGBO(90, 76, 59, 1.0),fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)
                    ]
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.person, size: 80, color: Colors.blue),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () { /* TODO: Implement logic to edit profile pic */ },
                        child: const Text('EDIT PROFILE PIC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color:const Color.fromRGBO(76, 88, 138, 1), )),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Form Fields
              _buildProfileField('First Name', _firstNameController),
              _buildProfileField('Last Name', _lastNameController),
              _buildProfileField('Gender', _genderController),
              
              // MODIFIED LOCATION FIELD
              _buildLocationField(), // Call the new location field widget
              
              _buildProfileField('Contact No.', _contactNoController, keyboardType: TextInputType.phone),
              _buildProfileField('Email', _emailController, keyboardType: TextInputType.emailAddress, enabled: false), // Email is likely immutable/used as key

              // NEW QUALIFICATION SECTION
              _buildQualificationFields(),
              // END NEW QUALIFICATION SECTION

              const SizedBox(height: 20),

              // Certificates Section (Unchanged)
              const Text('Certificates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildDocumentIcon(),
                  const SizedBox(width: 10),
                  _buildDocumentIcon(),
                ],
              ),

              const SizedBox(height: 20),

              // Resume Section (Unchanged)
              const Text('Resume', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildDocumentIcon(),

              const SizedBox(height: 40),

              // Save Button
              ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(76, 88, 138, 1), 
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // --- NEW: Qualification Selection Widget ---
  Widget _buildQualificationFields() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Qualification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),

          // 1. Degree Dropdown
          _buildDropdownField(
            label: 'Degree',
            value: _selectedDegree,
            items: _degrees,
            onChanged: (newValue) {
              setState(() {
                _selectedDegree = newValue;
              });
            },
          ),
          const SizedBox(height: 10),

          // 2. Department Dropdown
          _buildDropdownField(
            label: 'Department',
            value: _selectedDepartment,
            items: _departments,
            onChanged: (newValue) {
              setState(() {
                _selectedDepartment = newValue;
              });
            },
          ),
          const SizedBox(height: 10),

          // 3. Start and End Year Selection
          Row(
            children: [
              // Start Year
              Expanded(
                child: _buildDropdownField(
                  label: 'Start Year',
                  value: _selectedStartYear,
                  items: _years,
                  onChanged: (newValue) {
                    setState(() {
                      _selectedStartYear = newValue;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              // End Year
              Expanded(
                child: _buildDropdownField(
                  label: 'End Year',
                  value: _selectedEndYear,
                  items: _years,
                  onChanged: (newValue) {
                    setState(() {
                      _selectedEndYear = newValue;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Reusable Dropdown Field Widget ---
  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            isExpanded: true,
            hint: Text('Select $label'),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: onChanged,
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please select a $label';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }


  // --- Location Field Widget (Unchanged) ---
  Widget _buildLocationField() {
    // Helper text to show current coordinates
    String coordsDisplay = (_latitude != null && _longitude != null)
        ? 'Coords: ($_latitude, $_longitude)'
        : 'Coordinates: Not Set';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Location (Coordination)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          // 1. Text Field for human-readable location name
          TextFormField(
            controller: _locationController,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide.none,
              ),
            ),
              validator: (value) {
               if (value == null || value.trim().isEmpty) {
                 return 'Please enter your location or maintain "----"';
               }
               return null;
             },
          ),
          const SizedBox(height: 10),

          // 2. Coordinates Display
          Text(coordsDisplay, style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
          
          const SizedBox(height: 10),

          // 3. Location Selection Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Button 1: Manual Coordinates Input
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.pin_drop),
                  label: const Text('Manual Coords'),
                  onPressed: _showManualCoordinatesDialog,
                ),
              ),
              const SizedBox(width: 10),
              // Button 2: Redirect to Google Maps
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text('Select on Map'),
                  onPressed: _openGoogleMapsForSelection,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  // Reusable widget for form text fields (excluding location and qualification)
  Widget _buildProfileField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            enabled: enabled,
            style: TextStyle(color: enabled ? Colors.black : Colors.grey),
            decoration: InputDecoration(
              filled: true,
              fillColor: enabled ? Colors.white : Colors.grey.shade200,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide.none,
              ),
            ),
            // Simple validation: field should not be completely empty (unless it was '----')
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your $label or maintain "----"';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // Reusable widget for document icons
  Widget _buildDocumentIcon() {
    return Container(
      width: 80,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: const Center(
        child: Icon(Icons.description, size: 40, color: Colors.grey),
      ),
    );
  }
}