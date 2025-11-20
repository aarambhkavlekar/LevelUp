import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_recruiter.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart'; 
import 'dart:async';

// --- Theme & Color Definitions (Reused) ---
const Color _textColor = Color(0xFF2C2C2C);
const Color _accentColor = Color(0xFF4C588A);
const Color _secondaryAccentColor = Color(0xFF8B4513);

// Helper for date formatting (DD/MM/YYYY)
Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
  DateTime? pickedDate = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime.now(),
    lastDate: DateTime(2101),
    builder: (context, child) {
      return Theme(
        data: ThemeData.light().copyWith(
          primaryColor: _secondaryAccentColor,
          colorScheme: const ColorScheme.light(primary: _secondaryAccentColor),
          buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
        ),
        child: child!,
      );
    },
  );
  if (pickedDate != null) {
    String formattedDate = DateFormat('dd/MM/yyyy').format(pickedDate);
    controller.text = formattedDate;
  }
}

// Helper for time formatting (e.g., 03:00 PM)
Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
  final TimeOfDay? picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
    builder: (context, child) {
      return Theme(
        data: ThemeData.light().copyWith(
          primaryColor: _secondaryAccentColor,
          colorScheme: const ColorScheme.light(primary: _secondaryAccentColor),
          buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
        ),
        child: child!,
      );
    },
  );
  if (picked != null) {
    // Format to 12-hour clock with AM/PM (e.g., 10:30 AM)
    // ignore: use_build_context_synchronously
    controller.text = picked.format(context); 
  }
}

class JobApplicationForm extends StatefulWidget {
  // Receives user data from the home page, which must contain 'cin_no'.
  final Map<String, dynamic> userData;

  const JobApplicationForm(this.userData, {super.key});

  @override
  State<JobApplicationForm> createState() => _JobApplicationFormState();
}

class _JobApplicationFormState extends State<JobApplicationForm> {
  final _formKey = GlobalKey<FormState>();

  // --- Text Controllers ---
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  
  // Job Timing
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  
  // Job Schedule Date
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  
  // Qualification (Other)
  final TextEditingController _otherQualificationController = TextEditingController();
  final TextEditingController _otherFieldController = TextEditingController();

  // --- Dropdown States ---
  String? _selectedQualification;
  String? _selectedField;

  final List<String> _qualificationOptions = ['B.E. / B.Tech', 'M.E. / M.Tech', 'PhD', 'Other'];
  final List<String> _fieldOptions = ['Computer Science', 'Electrical', 'Civil', 'Mechanical', 'Other'];

  bool _isPosting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _descriptionController.dispose();
    _salaryController.dispose();
    _experienceController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _otherQualificationController.dispose();
    _otherFieldController.dispose();
    super.dispose();
  }

  // --- Submission Logic ---

  Future<void> _postJob() async {
    // 1. Validate required fields
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill all required fields.', color: Colors.orange);
      return;
    }

    if (_selectedQualification == null || _selectedField == null) {
      _showSnackBar('Please select Qualification and Field.', color: Colors.orange);
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      final String recruiterCin = widget.userData['cin_no'] as String? ?? 'UNKNOWN_CIN';
      if (recruiterCin == 'UNKNOWN_CIN') {
         throw Exception("Recruiter CIN not found in user data.");
      }
      
      // Determine final qualification/field value (handle "Other")
      final finalQualification = _selectedQualification == 'Other' ? _otherQualificationController.text : _selectedQualification;
      final finalField = _selectedField == 'Other' ? _otherFieldController.text : _selectedField;

      final Map<String, dynamic> jobData = {
        'cin_no': recruiterCin,
        'title': _titleController.text,
        'company_name': _companyController.text,
        'job_description': _descriptionController.text,
        'job_timing_start': _startTimeController.text,
        'job_timing_end': _endTimeController.text,
        'qualification_degree': finalQualification,
        'qualification_field': finalField,
        'min_experience': _experienceController.text,
        'salary_offered': _salaryController.text,
        'start_date': _startDateController.text,
        'end_date': _endDateController.text,
        'posted_at': FieldValue.serverTimestamp(),
      };

      // Use 'job_postings' collection
      await FirebaseFirestore.instance.collection('job_postings').add(jobData);

      _showSnackBar('Job posted successfully!', color: Colors.green);
      _resetForm();

    } catch (e) {
      _showSnackBar('Failed to post job: ${e.toString()}');
      _showSnackBar('Job Posting Error: $e');
    } finally {
      setState(() {
        _isPosting = false;
      });
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _companyController.clear();
    _descriptionController.clear();
    _salaryController.clear();
    _experienceController.clear();
    _startTimeController.clear();
    _endTimeController.clear();
    _startDateController.clear();
    _endDateController.clear();
    _otherQualificationController.clear();
    _otherFieldController.clear();
    setState(() {
      _selectedQualification = null;
      _selectedField = null;
    });
  }

  void _showSnackBar(String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // --- UI Builders ---

  // Builds a standard text field
  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1, bool required = false, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.openSans(color: _textColor),
          fillColor: Colors.white,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: maxLines > 1 ? 15 : 10),
        ),
        style: GoogleFonts.openSans(color: _textColor),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return '$label is required';
          }
          return null;
        },
      ),
    );
  }

  // Builds a text field with a Time Picker suffix
  Widget _buildTimeField(TextEditingController controller, String label, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: () => _selectTime(context, controller),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.openSans(color: _textColor),
          suffixIcon: const Icon(Icons.access_time, color: _secondaryAccentColor),
          fillColor: Colors.white,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        ),
        style: GoogleFonts.openSans(color: _textColor),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return '$label is required';
          }
          return null;
        },
      ),
    );
  }
  
  // Builds a text field with a Date Picker suffix
  Widget _buildDateField(TextEditingController controller, String label, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: () => _selectDate(context, controller),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.openSans(color: _textColor),
          suffixIcon: const Icon(Icons.calendar_today, color: _secondaryAccentColor),
          fillColor: Colors.white,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        ),
        style: GoogleFonts.openSans(color: _textColor),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return '$label is required';
          }
          return null;
        },
      ),
    );
  }

  // Builds a dropdown field
  Widget _buildDropdownField(String label, List<String> items, String? currentValue, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.white),
        ),
        child: DropdownButtonFormField<String>(
          hint: Text(label, style: GoogleFonts.openSans(color: _textColor)),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: GoogleFonts.openSans(color: _textColor),
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: onChanged,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '$label is required';
            }
            return null;
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      backgroundColor: const Color.from(alpha: 1, red: 0.953, green: 0.878, blue: 0.71),
      appBar: AppBar(
        toolbarHeight: 70,
        title: Text('Application Form', style: GoogleFonts.merriweather(color: Colors.white, fontWeight: FontWeight.bold)),
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
            padding: const EdgeInsets.only(right: 10.0),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Static Test Details Header ---
              Text(
                'Job Posting Details',
                style: GoogleFonts.merriweather(fontSize: 20, fontWeight: FontWeight.bold, color: _textColor),
              ),
              const Divider(color: _accentColor),
              
              // 1. Title & Company Name
              _buildTextField(_titleController, 'Title', required: true),
              _buildTextField(_companyController, 'Company Name', required: true),
              
              // 2. Job Description (Multi-line)
              _buildTextField(_descriptionController, 'Job description', maxLines: 5, required: true),
              
              // 3. Job Timing (Start and End Time)
              Row(
                children: [
                  Expanded(child: _buildTimeField(_startTimeController, 'Job Timing (Start)', required: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTimeField(_endTimeController, 'Job Timing (End)', required: true)),
                ],
              ),
              
              // 4. Qualification (Dropdown + Other option)
              _buildDropdownField(
                'Qualification (Degree)', 
                _qualificationOptions, 
                _selectedQualification, 
                (newValue) {
                  setState(() { _selectedQualification = newValue; });
                }
              ),
              
              // Conditional field for 'Other' qualification
              if (_selectedQualification == 'Other') 
                _buildTextField(_otherQualificationController, 'Specify Qualification', required: true),
              
              // 5. Field/Department (Dropdown + Other option)
              _buildDropdownField(
                'Qualification (Field)', 
                _fieldOptions, 
                _selectedField, 
                (newValue) {
                  setState(() { _selectedField = newValue; });
                }
              ),
              
              // Conditional field for 'Other' field
              if (_selectedField == 'Other') 
                _buildTextField(_otherFieldController, 'Specify Field', required: true),
              
              // 6. Experience & Salary
              _buildTextField(_experienceController, 'Minimum Experience (Years)', keyboardType: TextInputType.number, required: true),
              _buildTextField(_salaryController, 'Salary (e.g., Annual CTC)', required: true, keyboardType: TextInputType.number),

              // 7. Job Schedule Date (Date Picker)
              _buildDateField(_startDateController, 'Start Date (DD/MM/YYYY)', required: true),

              // 7. Job Schedule Date (Date Picker)
              _buildDateField(_endDateController, 'End Date (DD/MM/YYYY)', required: true),
              const SizedBox(height: 30),

              // --- POST Button ---
              ElevatedButton(
                onPressed: _isPosting ? null : _postJob,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(76, 88, 138, 1),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isPosting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'POST',
                        style: GoogleFonts.merriweather(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}