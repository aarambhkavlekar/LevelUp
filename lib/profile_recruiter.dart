import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levelup/home_recruiter.dart';
import 'package:url_launcher/url_launcher.dart';

// Define the RecruiterProfilePage widget
class RecruiterProfilePage extends StatefulWidget {
  // userData now requires a 'cin_no' field for updates
  final Map<String, dynamic> userData;

  const RecruiterProfilePage(this.userData , {super.key });

  @override
  State<RecruiterProfilePage> createState() => _RecruiterProfilePageState();
}

class _RecruiterProfilePageState extends State<RecruiterProfilePage> {
  // Use TextEditingControllers to manage the text fields
  late TextEditingController _nameController;
  late TextEditingController _organizationNameController;
  late TextEditingController _emailController;
  late TextEditingController _locationController;
  late TextEditingController _contactNoController;
  late TextEditingController _noOfWorkersController;
  late TextEditingController _descriptionController;

  String? _selectedindustry;
  String? _latitude;
  String? _longitude;


  final List<String> _industry= ['Computer Science', 'IT', 'Civil', 'Electrical', 'Mechanical', 'Chemical', 'Electronics', 'Management', 'Other'];
  // New variable to hold the unchangeable CIN No.
  String? _cinNo; 

  // Key for form validation
  final _formKey = GlobalKey<FormState>();
  

  @override
  void initState() {
    super.initState();
    
    // Initialize CIN No. from userData. It must exist for the update logic to work.
    // Assuming 'cin_no' is the unique identifier for the recruiter.
    _cinNo = _getFieldValue('cin_no', defaultValue: 'NOT_FOUND_CIN_NO'); 

    // Initialize controllers with existing data or '----'
    _nameController = TextEditingController(text: _getFieldValue('name'));
    _organizationNameController = TextEditingController(text: _getFieldValue('organization_name'));
    _emailController = TextEditingController(text: _getFieldValue('email'));
    _locationController = TextEditingController(text: _getFieldValue('location'));
    _contactNoController = TextEditingController(text: _getFieldValue('contact'));
    _selectedindustry = _getFieldValue('degree',defaultValue: null);
    // Ensure 'no_of_workers' is treated as a string, but consider int conversion for database storage
    _noOfWorkersController = TextEditingController(text: _getFieldValue('no_of_workers')); 
    _descriptionController = TextEditingController(text: _getFieldValue('description'));

  }

  // Helper function to safely get data from the map, returning a default value if missing/null
  String? _getFieldValue(String key, {String? defaultValue = '----'}) {
    final value = (widget.userData.containsKey(key) && widget.userData[key] != null)
        ? widget.userData[key].toString()
        : defaultValue;

    if (value == '----') return null;
    return value;
  }

  // Dispose controllers when the widget is removed
  @override
  void dispose() {
    _nameController.dispose();
    _organizationNameController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _contactNoController.dispose();
    _noOfWorkersController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // --- Firestore Update Logic using CIN No. as the key ---
  Future<void> updateRecruiterDetailsByCinNo({
    required String? cinNo,
    required Map<String, dynamic> updatedData,
  }) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    // Assuming your collection for recruiters is named 'recruiters'
    CollectionReference recruiters = firestore.collection('recruiters');

    try {
      // 1. Query the 'recruiters' collection to find the document matching the cin_no
      // This assumes 'cin_no' is an indexed field in your Firestore documents.
      QuerySnapshot snapshot = await recruiters
          .where('cin_no', isEqualTo: cinNo)
          .limit(1) // Limit to 1, as cin_no should be unique
          .get();

      // 2. Check if a document was found
      if (snapshot.docs.isNotEmpty) {
        // Get the DocumentSnapshot of the found document
        DocumentSnapshot document = snapshot.docs.first;
        String documentId = document.id; // Get the Document ID

        // 3. Get the DocumentReference and use the .update() method
        await recruiters.doc(documentId).update(updatedData);

        print('Recruiter document with ID $documentId (CIN: $cinNo) successfully updated!');
      } else {
        // Handle the case where no document matches the CIN No.
        throw Exception('No recruiter document found for CIN No.: $cinNo');
      }
    } catch (e) {
      print('Error updating recruiter by CIN No. $cinNo: $e');
      rethrow;
    }
  }

  // Function to handle the save button press
  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      // Check if CIN No. is valid before attempting an update
      if (_cinNo == 'NOT_FOUND_CIN_NO' || _cinNo == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: CIN No. is missing. Cannot update profile.')),
          );
        }
        return;
      }

      // Collect the updated data
      final updatedData = {
        'name': _nameController.text,
        'organization_name': _organizationNameController.text,
        'email': _emailController.text,
        'location': _locationController.text,
        'contact_no': _contactNoController.text,
        // Convert no_of_workers to an integer if the database expects a number
        'no_of_workers': int.tryParse(_noOfWorkersController.text) ?? _noOfWorkersController.text, 
        'description': _descriptionController.text,
        'industry': _selectedindustry ?? '----',
        // The cin_no is NOT updated, but used as the key.
      };

      try {
        // 2. Call the update function using the CIN No.
        await updateRecruiterDetailsByCinNo(
          cinNo: _cinNo,
          updatedData: updatedData,
        );

        // 3. If the update was successful, update local widget data and show message
        widget.userData.addAll(updatedData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recruiter profile updated successfully!')),
          );
        }
      } catch (e) {
        // 4. Show error message if update fails
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update profile: ${e.toString()}')),
          );
        }
      }
    }
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
      backgroundColor: const Color.fromRGBO(243, 224, 181, 1),
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
        // Custom back button example:
        leading: GestureDetector(
          onTap: () {
            // Navigate to the desired page
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RecruiterDashboard(widget.userData)),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header
              Text(
                'Profile',
                textAlign: TextAlign.center,
                style: GoogleFonts.merriweather(color: const Color.fromRGBO(90, 76, 59, 1.0),fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Profile Picture Section
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
                      // Placeholder for the GlobalTech logo image
                      const Icon(Icons.public, size: 60, color: Colors.blue),
                      Text(_nameController.text, style: TextStyle(fontStyle: FontStyle.italic)),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () { /* TODO: Implement logic to edit profile pic */ },
                        child: const Text('EDIT PROFILE PIC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,color:const Color.fromRGBO(76, 88, 138, 1), )),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Display unchangeable CIN No.
              _buildReadOnlyField('CIN No.', _cinNo),
              
              // Form Fields
              _buildProfileField('Name', _nameController),
              _buildProfileField('Organization Name', _organizationNameController),
              _buildindustryFields(),
              _buildProfileField('Email', _emailController, keyboardType: TextInputType.emailAddress),
              _buildLocationField(),
              _buildProfileField('Contact No.', _contactNoController, keyboardType: TextInputType.phone),
              _buildProfileField('No. Of Workers', _noOfWorkersController, keyboardType: TextInputType.number),
              _buildProfileField('Description', _descriptionController, maxLines: 3),

              const SizedBox(height: 20),

              // Application Form Documents Section
              const Text('Application Form', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildDocumentIcon(),
                  const SizedBox(width: 10),
                  _buildDocumentIcon(),
                ],
              ),

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

   Widget _buildindustryFields() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Industry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          _buildDropdownField(
            label: 'industry',
            value: _selectedindustry,
            items: _industry,
            onChanged: (newValue) {
              setState(() {
                _selectedindustry= newValue;
              });
            },
          ),
          const SizedBox(height: 10),
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

  // Reusable widget for form text fields
  Widget _buildProfileField(
    String label, 
    TextEditingController controller, 
    {TextInputType keyboardType = TextInputType.text, 
      int maxLines = 1}
  ) {
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
            maxLines: maxLines,
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
                return 'Please enter the $label or maintain "----"';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // New widget for displaying read-only data like CIN No.
  Widget _buildReadOnlyField(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.grey.shade300, // Light grey background to indicate read-only
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              value ?? 'n/a',
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
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