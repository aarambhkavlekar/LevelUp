// job_application_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_emp.dart'; // Ensure this is the correct path

// --- Theme & Color Definitions ---
const Color _parchmentColor = Color(0xFFF3E0B5);
const Color _cardColor = Color(0xFFFCF7E0);
const Color _textColor = Color(0xFF2C2C2C);
const Color _accentColor = Color(0xFF4C588A);
// ---------------------------------

class JobApplicationPage extends StatefulWidget {
  final String jobId;
  final String userEmail;
  final Map<String, dynamic> userData;

  // Corrected Constructor using named arguments
  const JobApplicationPage(this.userData,
     this.jobId,
     this.userEmail,{
    super.key
  });
  
  @override
  State<JobApplicationPage> createState() => _JobApplicationPageState();
}

class _JobApplicationPageState extends State<JobApplicationPage> {
  // Use widget properties for consistency
  String get _userEmail => widget.userEmail;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic> _jobData = {};
  
  // New state variables for application status
  bool _isApplied = false;
  bool _isLoadingApplicationStatus = true;

  @override
  void initState() {
    super.initState();
    _checkApplicationStatus();
  }

  // --- Check Application Status on Load ---
  Future<void> _checkApplicationStatus() async {
    setState(() {
      _isLoadingApplicationStatus = true;
    });
    try {
      final applicationsCollection = _firestore.collection('application'); // NOTE: Assuming collection name is 'applications' based on previous logic, but checking for 'application' in your provided code
      
      final existingApplication = await applicationsCollection
          .where('job_id', isEqualTo: widget.jobId)
          .where('employee_email', isEqualTo: _userEmail)
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _isApplied = existingApplication.docs.isNotEmpty;
          _isLoadingApplicationStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingApplicationStatus = false;
        });
      }
      _showMessage('Error checking application status.', Colors.red);
    }
  }

  // --- Helper: SnackBar Message ---
  void _showMessage(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.openSans(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // --- Core Logic: Apply for Job ---
  void _applyForJob() async {
    if (_jobData.isEmpty) {
      _showMessage('Error: Job details not loaded yet.', Colors.red);
      return;
    }
    
    // Check again to prevent double submission
    if (_isApplied) return; 

    final String title = _jobData['title'] as String? ?? 'N/A';
    final String cinNo = _jobData['cin_no'] as String? ?? 'N/A';
    
    // NOTE: Changed to 'applications' for standard plural naming, but check your database.
    // If your collection is actually 'application', change this line back:
    // final applicationsCollection = _firestore.collection('application');
    final applicationsCollection = _firestore.collection('application'); 

    try {
      // Re-check just before saving to prevent race conditions
      final existingApplication = await applicationsCollection
          .where('job_id', isEqualTo: widget.jobId)
          .where('employee_email', isEqualTo: _userEmail)
          .limit(1)
          .get();

      if (existingApplication.docs.isNotEmpty) {
        if (mounted) setState(() => _isApplied = true);
        _showMessage('You have already applied for this job!', Colors.orange);
        return;
      }

      // 2. Save the application to the 'applications' collection
      await applicationsCollection.add({
        'job_id': widget.jobId,
        'employee_email': _userEmail,
        'job_title': title,
        'recruiter_cin_no': cinNo,
        'application_date': FieldValue.serverTimestamp(),
        'status': 'Pending', // Initial status
      });

      // 3. Success: Update state and show message
      if (mounted) {
        setState(() {
          _isApplied = true; // Button changes to APPLIED
        });
      }
      _showMessage('Successfully applied for $title!', _accentColor);
      
    } on FirebaseException catch (e) {
      _showMessage('Application Error: ${e.message}', Colors.red);
    } catch (e) {
      _showMessage('An unexpected error occurred.', Colors.red);
    }
  }

  // --- Helper Widget: Job Detail Field (Unchanged) ---
  Widget _buildDetailField(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.merriweather(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _textColor.withOpacity(0.3)),
            ),
            child: Text(
              value,
              style: GoogleFonts.openSans(
                fontSize: 14,
                color: _textColor.withOpacity(0.9),
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    Future<DocumentSnapshot> jobFuture = _firestore.collection('job_postings').doc(widget.jobId).get();

    return Scaffold(
      backgroundColor: _parchmentColor,
      appBar: AppBar(
        toolbarHeight: 70,
        title: Text('Application Form', style: GoogleFonts.merriweather(color: Colors.white, fontWeight: FontWeight.bold)),
        flexibleSpace: Container( 
          decoration: BoxDecoration(
            gradient: LinearGradient( 
              colors: [
                const Color.fromRGBO(90, 76, 59, 1.0),
                const Color.fromRGBO(120, 101, 78, 1.0),
                const Color.fromARGB(230, 131, 114, 94),
              ],
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
                // Assuming 'assets/images/logo.png' is correct
                backgroundImage: AssetImage('assets/images/logo.png'), 
                backgroundColor: Colors.transparent,
                radius: 30,
              ),
          ),
        ],
        // Custom back button
        leading: GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => EmployeeDashboard(widget.userData)),);
          },
            child: Column( 
              children: [
                const SizedBox(height: 1),
                Image.asset(
                  'assets/images/back_button.png', // Replace with your image path
                  height: 50, // Adjust height as needed
                ),
                const Text('BACK',style: TextStyle(color: Colors.black, fontSize: 10),),
              ],
            )
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: jobFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isLoadingApplicationStatus) {
            return const Center(child: CircularProgressIndicator(color: _accentColor));
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'Failed to load job details. Job ID: ${widget.jobId}',
                style: GoogleFonts.openSans(color: Colors.red),
              ),
            );
          }

          _jobData = snapshot.data!.data() as Map<String, dynamic>;

          // Safely extract data fields from job_postings
          final String title = _jobData['title'] as String? ?? 'N/A';
          final String companyName = _jobData['company_name'] as String? ?? 'N/A';
          final String description = _jobData['job_description'] as String? ?? 'N/A';

          // Correctly handle string concatenation for display:
          final String timing = (_jobData['job_timing_start'] as String? ?? 'N/A') + ' - ' + (_jobData['job_timing_end'] as String? ?? 'N/A');
          final String qualification = '${_jobData['qualification_degree'] as String? ?? 'N/A'} in ${_jobData['qualification_field'] as String? ?? 'N/A'}';
          final String experience = _jobData['min_experience'] as String? ?? 'N/A';
          final String salary = _jobData['salary_offered'] as String? ?? 'N/A';
          final String schedule = (_jobData['start_date'] as String? ?? 'N/A') + ' - ' + (_jobData['end_date'] as String? ?? 'N/A');


          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Text(
                    title,
                    style: GoogleFonts.merriweather(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: _accentColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),

                _buildDetailField('Company Name', companyName),
                _buildDetailField('Job Description', description, maxLines: 5),

                Row(
                  children: [
                    Expanded(child: _buildDetailField('Job Timing', timing)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildDetailField('Job Schedule', schedule)),
                  ],
                ),
                
                _buildDetailField('Qualification', qualification),
                _buildDetailField('Experience', experience),
                _buildDetailField('Salary (P.A.)', salary),
                
                const SizedBox(height: 30),

                // Apply Button Logic
                Center(
                  child: ElevatedButton(
                    // If already applied, onPressed is null (disabled)
                    onPressed: _isApplied ? null : _applyForJob,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isApplied ? Colors.grey : _accentColor,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 5,
                    ),
                    child: Text(
                      // Button text changes based on state
                      _isApplied ? 'APPLIED' : 'APPLY',
                      style: GoogleFonts.merriweather(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}