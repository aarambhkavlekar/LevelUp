import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_emp.dart';
import 'login_page_emp.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'locate_company.dart';
import 'searchpage.dart';
import 'apptitudetestselection.dart';
import 'application_employee.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- Theme & Color Definitions ---
const Color _parchmentColor = Color(0xFFF3E0B5); // Light cream background
const Color _cardColor = Color(0xFFFCF7E0); // Lighter card/inner content background
const Color _textColor = Color(0xFF2C2C2C); // Dark charcoal text
const Color _accentColor = Color(0xFF4C588A); // Indigo accent (icons/buttons)
const Color _iconBackgroundColor = Color(0xFFE4C38B); // Mid-tone background for icons
const double _drawerWidthFactor = 0.75; // Drawer takes up 75% of screen width

// --- NEW WIDGET: EmployeeAppliedJobsScreen (The Core Implementation) ---

class EmployeeAppliedJobsScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String userEmail;

  // Corrected Constructor
  const EmployeeAppliedJobsScreen( this.userData, this.userEmail,{super.key});

  // --- Helper: SnackBar Message ---
  void _showMessage(BuildContext context, String message, Color color) {
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

  // --- CORE LOGIC: Delete Application ---
  Future<void> _deleteApplication(BuildContext context, String applicationId) async {
final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    // Show confirmation dialog before deleting
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Application'),
        content: const Text('Are you sure you want to withdraw this application?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('WITHDRAW', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
    if (!confirm) return;
    try {
      // Delete the document using the application's unique ID
      await _firestore.collection('application').doc(applicationId).delete();
      _showMessage(context, 'Application withdrawn successfully!', Colors.green);
    } on FirebaseException catch (e) {
      _showMessage(context, 'Error withdrawing application: ${e.message}', Colors.red);
    } catch (e) {
      _showMessage(context, 'An unexpected error occurred.', Colors.red);
    }
  }

  // --- Helper Widget: Applied Job Card ---
  Widget _buildAppliedJobCard({
    required BuildContext context,
    required String applicationId, // New: Document ID for deletion
    required String title,
    required String companyName,
    required String location,
    required String applicationDate,
    required String status,
  }) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'accepted':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      case 'pending':
      default:
        statusColor = _accentColor;
        break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: _textColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row containing Icon/Title/Company AND Delete Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Placeholder (for logo/icon)
              Container(
                width: 50,
                height: 50,
                margin: const EdgeInsets.only(right: 15),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    title.isNotEmpty ? title[0].toUpperCase() : 'U',
                    style: GoogleFonts.merriweather(
                        fontSize: 24, fontWeight: FontWeight.bold, color: _accentColor),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: GoogleFonts.merriweather(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Company Name
                    Text(
                      companyName,
                      style: GoogleFonts.openSans(
                        fontSize: 14,
                        color: _textColor.withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // NEW: Delete Button (Trash Bin)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _deleteApplication(context, applicationId),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Location and Date Row (Unchanged)
          Row(
            children: [
              const Icon(Icons.location_on, color: _textColor, size: 14),
              const SizedBox(width: 4),
              Text(
                location,
                style: GoogleFonts.openSans(fontSize: 14, color: _textColor.withOpacity(0.8)),
              ),
              const SizedBox(width: 15),
              const Icon(Icons.calendar_today, color: _textColor, size: 12),
              const SizedBox(width: 4),
              Text(
                applicationDate,
                style: GoogleFonts.openSans(fontSize: 12, color: _textColor.withOpacity(0.8)),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Applied/Status Button (Unchanged)
          Center(
            child: ElevatedButton(
              onPressed: () {
                _showMessage(
                    context, 'Application status is: $status', statusColor);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 3,
              ),
              child: Text(
                status.toUpperCase(),
                style: GoogleFonts.merriweather(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    // NOTE: Using 'application' as per your existing code.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final applicationsCollection = _firestore.collection('application'); 
    final jobPostingsCollection = _firestore.collection('job_postings');

    return Container(
      color: const Color.fromRGBO(243, 224, 181, 1),
      child: Column(
        children: [
          const SizedBox(height: 30),
          // Title
          Text(
            'Applied Jobs',
            style: GoogleFonts.merriweather(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color.fromRGBO(120, 101, 78, 1.0),
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: applicationsCollection
                  .where('employee_email', isEqualTo: userEmail)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _accentColor));
                }

                if (snapshot.hasError) {
                  // Show the error clearly if the index is still missing
                   return Center(child: Text(
                    'Error loading applications. Check your Firebase index for employee_email and application_date.', 
                    style: GoogleFonts.openSans(color: Colors.red.shade900, fontSize: 16),
                    textAlign: TextAlign.center,
                  ));
                }

                final applicationDocs = snapshot.data?.docs ?? [];
                if (applicationDocs.isEmpty) {
                  return Center(
                    child: Text(
                      'You haven\'t applied for any jobs yet.',
                      style: GoogleFonts.merriweather(fontSize: 18, color: _textColor.withOpacity(0.7)),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: applicationDocs.length,
                  itemBuilder: (context, index) {
                    final applicationDoc = applicationDocs[index]; // Get DocumentSnapshot
                    final applicationId = applicationDoc.id; // CAPTURE THE DOCUMENT ID
                    final applicationData = applicationDoc.data() as Map<String, dynamic>;
                    final jobId = applicationData['job_id'] as String? ?? '';
                    final applicationStatus = applicationData['status'] as String? ?? 'Pending';

                    // Date formatting logic (unchanged)
                    String dateString = 'N/A';
                    final dateTimestamp = applicationData['application_date'];
                    if (dateTimestamp is Timestamp) {
                      final date = dateTimestamp.toDate();
                      dateString = '${date.day} ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.year}';
                    } else if (dateTimestamp is String) {
                       dateString = dateTimestamp;
                    }
                    if (jobId.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    // 3. Inner FutureBuilder: Fetches the actual job details
                    return FutureBuilder<DocumentSnapshot>(
                      future: jobPostingsCollection.doc(jobId).get(),
                      builder: (context, jobSnapshot) {
                        if (jobSnapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor))),
                          );
                        }
                        if (jobSnapshot.hasError || !jobSnapshot.hasData || !jobSnapshot.data!.exists) {
                          return _buildAppliedJobCard(
                            context: context,
                            applicationId: applicationId, // PASS ID
                            title: 'Job Not Found (ID: $jobId)',
                            companyName: 'N/A',
                            location: 'N/A',
                            applicationDate: dateString,
                            status: applicationStatus,
                          );
                        }

                        // 4. Data retrieved: Extract and pass to the card
                        final jobData = jobSnapshot.data!.data() as Map<String, dynamic>;
                        final jobTitle = jobData['title'] as String? ?? 'Unknown Job Title';
                        final companyName = jobData['company_name'] as String? ?? 'Unknown Company';
                        final location = jobData['location'] as String? ?? 'N/A'; 

                        return _buildAppliedJobCard(
                          context: context,
                          applicationId: applicationId, // PASS ID
                          title: jobTitle,
                          companyName: companyName,
                          location: location,
                          applicationDate: dateString,
                          status: applicationStatus,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- NEW WIDGET: EmployeeSavedJobsScreen (The Core Implementation) ---

class EmployeeSavedJobsScreen extends StatelessWidget {
  final String userEmail;
  final Map<String, dynamic> userData;
  const EmployeeSavedJobsScreen(this.userData, this.userEmail,{ super.key});

void _showMessage(BuildContext context, String message, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: GoogleFonts.openSans(
            color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

  // Logic to remove the saved job from Firestore
void _removeSavedJob(
    BuildContext context, String jobId, String email, String title) async {
  final firestore = FirebaseFirestore.instance;
  final savedJobsCollection = firestore.collection('saved_jobs');

  try {
    // 1. Find the specific document in saved_jobs using job_id and user_email
    // This looks up the document ID (the key) in the saved_jobs collection.
    final querySnapshot = await savedJobsCollection
        .where('job_id', isEqualTo: jobId)
        .where('user_email', isEqualTo: email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      // 2. Delete the document using its found ID
      final docId = querySnapshot.docs.first.id;
      await savedJobsCollection.doc(docId).delete();

      // 3. Success message
      _showMessage(context, 'Job "$title" REMOVED from saved list.', _accentColor);
    } else {
      _showMessage(
          context, 'Error: Could not find job "$title" in saved list.', Colors.red);
    }
  } on FirebaseException catch (e) {
    _showMessage(context, 'Error removing job: ${e.message}', Colors.red);
  } catch (e) {
    _showMessage(context, 'An unexpected error occurred.', Colors.red);
  }
}

  // --- Helper Widget: Saved Job Card (Matches the Explore Job Content style) ---
 Widget _buildSavedJobCard(
    BuildContext context, // 👈 ADDED
    Map<String, dynamic> userData,
    String jobId, // 👈 ADDED
    String title,
    String companyName,
    String description,
    String minExperience,
    String location,
){
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: _textColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  title,
                  style: GoogleFonts.merriweather(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _accentColor,
                  ),
                ),
              ),
              // --- MODIFICATION: Use IconButton for removal ---
              IconButton(
                icon: const Icon(Icons.bookmark, color: Colors.green, size: 24),
                onPressed: () {
                  // Call the removal function when the user taps the bookmark
                  _removeSavedJob(context, jobId, userEmail, title);
                },
                padding: EdgeInsets.zero, // To keep the alignment clean
                constraints: const BoxConstraints(),
              ),
              // --- END MODIFICATION ---
            ],
          ),
          const SizedBox(height: 8),
          Text(
            companyName,
            style: GoogleFonts.openSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.work_history, color: _textColor, size: 14),
              const SizedBox(width: 4),
              Text(
                'Exp: $minExperience',
                style: GoogleFonts.openSans(fontSize: 12, color: _textColor.withOpacity(0.8)),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.location_on, color: _textColor, size: 14),
              const SizedBox(width: 4),
              Text(
                location,
                style: GoogleFonts.openSans(fontSize: 12, color: _textColor.withOpacity(0.8)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Description: $description',
            style: GoogleFonts.openSans(
              fontSize: 12,
              color: _textColor.withOpacity(0.8),
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.pushReplacement(context, 
                MaterialPageRoute(builder: (context) => JobApplicationPage(userData,jobId,userEmail)),
                );
              },
              child: Text(
                'View Details',
                style: GoogleFonts.merriweather(
                  color: _accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  // Inside EmployeeSavedJobsScreen class
  Widget build(BuildContext context) {
    // 1. Get a reference to the Firestore instance and collections
    final firestore = FirebaseFirestore.instance;
    // This collection gives us the list of SAVED job IDs by the user.
    final savedJobsCollection = firestore.collection('saved_jobs');
    // This is the collection where the actual JOB DETAILS are stored.
    final jobPostingsCollection = firestore.collection('job_postings');

    return Container(
      color: _parchmentColor, // Use the primary background color
      child: Column(
        children: [
          const SizedBox(height: 30),
          // Title
          Text(
            'YOUR SAVED JOBS',
            style: GoogleFonts.merriweather(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color.fromRGBO(120, 101, 78, 1.0),
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            // 2. Outer StreamBuilder: Fetches the list of saved job documents (which contain job_id)
            child: StreamBuilder<QuerySnapshot>(
              stream: savedJobsCollection.where('user_email', isEqualTo: userEmail).snapshots(),
              builder: (context, snapshot) {
                // --- Loading State for the list of saved jobs ---
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _accentColor));
                }

                // --- Error State ---
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading saved jobs list: ${snapshot.error}', style: GoogleFonts.openSans(color: Colors.red)));
                }

                final savedJobs = snapshot.data?.docs ?? [];

                // --- No Data State ---
                if (savedJobs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bookmark_border, size: 80, color: _accentColor),
                          const SizedBox(height: 20),
                          Text(
                            'No Saved Jobs Yet!',
                            style: GoogleFonts.merriweather(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Tap the bookmark icon on job listings in the Explore tab to save them here.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.openSans(fontSize: 16, color: _textColor.withOpacity(0.8)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // --- Data Available State (ListView) ---
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: savedJobs.length,
                  itemBuilder: (context, index) {
                    final savedJobData = savedJobs[index].data() as Map<String, dynamic>;
                    final jobId = savedJobData['job_id'] as String? ?? ''; // Get the job_id

                    if (jobId.isEmpty) {
                      return const SizedBox.shrink(); // Skip if job_id is missing
                    }

                    // 3. Inner FutureBuilder: Fetches the actual job details using the job_id
                    return FutureBuilder<DocumentSnapshot>(
                      // Future is a one-time fetch of the job details document
                      future: jobPostingsCollection.doc(jobId).get(),
                      builder: (context, jobSnapshot) {
                        // --- Loading State for single job details ---
                        if (jobSnapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor)
                            )),
                          );
                        }

                        // --- Error/Not Found State for single job ---
                        if (jobSnapshot.hasError || !jobSnapshot.hasData || !jobSnapshot.data!.exists) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Text(
                              'Job ID ($jobId) details not found or error occurred.',
                              style: GoogleFonts.openSans(fontSize: 12, color: Colors.red),
                            ),
                          );
                        }

                        // 4. Data retrieved: Extract and pass to the card
                        final jobData = jobSnapshot.data!.data() as Map<String, dynamic>;

                        final title = jobData['title'] as String? ?? 'Job Title N/A';
                        final companyName = jobData['company_name'] as String? ?? 'Company N/A';
                        final description = jobData['job_description'] as String? ?? 'No description provided.';
                        final minExperience = jobData['min_experience'] as String? ?? '0 years';
                        final location = jobData['location'] as String? ?? 'Anywhere';

                        return _buildSavedJobCard(
                          context, // 👈 PASS CONTEXT
                          userData,
                          jobId, // 👈 PASS JOB ID
                          title,
                          companyName,
                          description,
                          minExperience,
                          location,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// --- Employee Dashboard (Explore View) ---
// -----------------------------------------------------------------------------

class EmployeeDashboard extends StatefulWidget {
  // 1. ADD: User data parameter to the constructor
  final Map<String, dynamic> userData;

  const EmployeeDashboard(this.userData, {super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  int _selectedIndex = 0; // For bottom navigation bar
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // Key for Drawer access

  // New variable to hold the user's email/ID
  String get _userEmail => widget.userData['email'] as String? ?? 'Guest User';

  // 1. ADD: Variables to hold required user data from the userData map
  String get _userLocation => widget.userData['location'] as String? ?? '----';
  String get _userQualification => widget.userData['department'] + widget.userData['degree']  as String? ?? '----';

  // 4. NEW: List of pages for the BottomNavigationBar
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    // Initialize Firebase if it hasn't been already.
    if (Firebase.apps.isEmpty) {
      Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    _widgetOptions = <Widget>[
      _buildExploreView(context), // Index 0: Explore/Home View
      EmployeeSavedJobsScreen(widget.userData,widget.userData['email']), // Index 1: Saved View
      // FIX: Pass required parameters to EmployeeAppliedJobsScreen
      EmployeeAppliedJobsScreen(
        widget.userData,
        widget.userData['email'], // This is the string being looked for
      ), // Index 2: Applied View
    ];
  }

  // 2. NEW: Helper function to display a SnackBar message
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // 3. NEW: Logic for 'locate companies' functionality check
  void _handleLocateCompanies() {
    // Check if location is missing
    if (_userLocation == "----") {
      _showMessage('Please update your **Location** in your Profile to locate nearby companies.');
      return;
    }
    // Check if qualification is missing
    if (_userQualification == "----") {
      _showMessage('Please update your **Qualification** in your Profile to find relevant companies.');
      return;
    }

    // If both are present, proceed to the actual "Locate Companies" screen/logic
    Navigator.push(context, MaterialPageRoute(builder: (context) => LocationBasedSearchPage(widget.userData)));
  }


  // --- Helper Widget: Rounded Setting Icon Card ---
  Widget _buildSettingCard({
    required IconData icon,
    required String label1,
    required String label2,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _iconBackgroundColor,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: _textColor.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 30, color: _accentColor),
          ),
          const SizedBox(height: 8),
          Text(
            label1,
            textAlign: TextAlign.center,
            style: GoogleFonts.merriweather(
              fontSize: 14,
              color: _textColor,
            ),
          ),
          Text(
            label2,
            textAlign: TextAlign.center,
            style: GoogleFonts.merriweather(
              fontSize: 14,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  // --- New Widget: Welcome User Header ---
  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello,',
            style: GoogleFonts.openSans(
              fontSize: 18,
              color: _textColor.withOpacity(0.8),
            ),
          ),
          Text(
            widget.userData['firstName'] + ' ' + widget.userData['lastName'],
            style: GoogleFonts.merriweather(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _accentColor,
            ),
          ),
        ],
      ),
    );
  }

  // --- EXPLORE VIEW WIDGET (Previous body content, now a function) ---
  Widget _buildExploreView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildWelcomeHeader(),
          const SizedBox(height: 10),

          // --- 1. Manage Your Settings Section ---
          _buildSectionHeader('MANAGE YOUR SETTINGS'),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSettingCard(
                  icon: Icons.person_outline,
                  label1: 'Update',
                  label2: 'Profile',
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => EmployeeProfilePage(widget.userData)),
                    );
                  }),
              _buildSettingCard(
                  icon: Icons.add_circle_outline,
                  label1: 'Aptitude',
                  label2: 'test',
                  onTap: () {
                     Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => AptitudeTestScreen(widget.userData)),
                      );
                  }),
              // 4. UPDATE: Call the new handler function
              _buildSettingCard(
                  icon: Icons.location_on_outlined,
                  label1: 'locate',
                  label2: 'companies',
                  onTap: _handleLocateCompanies),
            ],
          ),
          const SizedBox(height: 25),

          // --- 2. Recommended Companies Section ---
          _buildSectionHeader('RECOMMENDED COMPANIES'),
          _buildRecommendedJobsView(context),
          const SizedBox(height: 20),

          // --- 3. Recommended Jobs Section ---
          _buildSectionHeader('RECOMMENDED JOBS'),
          _buildRecommendedapplicationView(context),
          const SizedBox(height: 20),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey, // Attach the key to the Scaffold
      backgroundColor: const Color.fromRGBO(243, 224, 181, 1),
      drawer: _buildCustomDrawer(context), // Add the custom drawer here
      body: SafeArea(
        child: Column(
          children: [
            // --- Top Bar (Header/App Bar) ---
            _buildCustomAppBar(context),

            // 5. UPDATE: Display the selected widget/screen
            Expanded(
              child: _widgetOptions.elementAt(_selectedIndex),
            ),

            // --- Bottom Navigation Bar ---
            _buildBottomNavBar(),
          ],
        ),
      ),
    );
  }


  // --- Custom Widget: Top App Bar (Remains the same) ---
  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      height: 70,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient( // Use LinearGradient here
          colors: [
            Color.fromRGBO(90, 76, 59, 1.0), // Note: use 1.0 for full opacity
            Color.fromRGBO(120, 101, 78, 1.0),
            Color.fromARGB(230, 131, 114, 94),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Menu Icon (opens the custom drawer)
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 30),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          Image.asset(
              'assets/images/logo.png', // 👈 Make sure the path matches your pubspec.yaml
              height: 200,        // adjust size as needed
            fit: BoxFit.contain,
            ),
        ],
      ),
    );
  }

  // --- Custom Widget: Section Header (Remains the same) ---
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title,
        style: GoogleFonts.merriweather(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: _textColor.withOpacity(0.8),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // --- Custom Drawer Menu (Remains the same with updates) ---
  Widget _buildCustomDrawer(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    // Helper for Menu Buttons
    Widget buildMenuButton(String label, {required VoidCallback onTap, IconData? icon}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 5,
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size(double.infinity, 50),
          ),
          child: Text(
            label,
            style: GoogleFonts.merriweather(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

    return Drawer(
      width: screenWidth * _drawerWidthFactor, // Set width to 75% of screen
      backgroundColor: Colors.transparent, // Use transparent background for rounded corner effect
      child: Padding(
        padding: const EdgeInsets.only(right: 20.0, top: 20.0), // Padding on the right/top for the shadow
        child: Container(
          decoration: BoxDecoration(
            color: _cardColor, // Light cream background for the menu content
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
            border: Border.all(color: _textColor.withOpacity(0.2), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: _textColor.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(4, 4),
              ),
            ],
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              // Header with Title and Back Button
              Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button (as requested by the user's image)
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: _accentColor, size: 30),
                      onPressed: () => Navigator.pop(context), // Closes the drawer
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: _accentColor,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          'Menu Bar',
                          style: GoogleFonts.merriweather(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Display User ID in the drawer header
                    Center(
                      child: Text(
                        'Logged in as: $_userEmail',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.openSans(
                          fontSize: 14,
                          color: _textColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // Menu Items
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    buildMenuButton('Home', onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedIndex = 0; // Go to Explore view
                      });
                    }),
                    // NOTE: Passing userData is crucial for the profile page
                    buildMenuButton('Profile', onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(context, MaterialPageRoute(builder: (context) => EmployeeProfilePage(widget.userData)));
                    }),
                    // 5. UPDATE: Call the new handler function
                    buildMenuButton('locate companies', onTap: () {
                      Navigator.pop(context); // Close drawer before showing the SnackBar/navigation
                      _handleLocateCompanies();
                    }),
                    buildMenuButton('Applications', onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedIndex = 2; // Go to Applied view
                      });
                    }),
                    buildMenuButton('Aptitude test', onTap: () {
                      // TODO: Navigate to Aptitude Test screen
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => AptitudeTestScreen(widget.userData)),
                      );
                      
                    }),
                    buildMenuButton('Search', onTap: () {
                      // TODO: Navigate to Search screen
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => JobSearchPage(widget.userData)),
                      );
                    }),
                    buildMenuButton('LogOut', onTap: () {
                      // Navigate to Login Page
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const EmployeesLoginPage()),
                      );
                    }),
                    const SizedBox(height: 10),
                    const Divider(color: _textColor, thickness: 0.5),
                    const SizedBox(height: 10),
                    buildMenuButton('Privacy Policy', onTap: () {}),
                    buildMenuButton('QNA', onTap: () {}),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- Custom Widget: Bottom Navigation Bar (Updated logic) ---
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: _cardColor,
        selectedItemColor: _accentColor,
        unselectedItemColor: _textColor.withOpacity(0.6),
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border),
            label: 'Saved', // Index 1
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: 'Applied', // Index 2
          ),
        ],
      ),
    );
  }

  // ... (Keep all existing code: imports, color definitions, EmployeeAppliedJobsScreen, EmployeeSavedJobsScreen, EmployeeDashboard class definition, _EmployeeDashboardState class definition, initState, _showMessage, _handleLocateCompanies, _buildSettingCard, _buildRecommendationCard, _companyContent, _jobContent, _buildWelcomeHeader, _buildCustomAppBar, _buildSectionHeader, _buildCustomDrawer, _buildBottomNavBar) ...

// -----------------------------------------------------------------------------
// --- NEW WIDGET: Horizontal Job Card (For Explore View) ---
// -----------------------------------------------------------------------------

  Widget _buildHorizontalJobCard(
    BuildContext context,
    String jobId,
    String title,
    String companyName,
    String industry,
    String description,
    String location,
  ) {
    // A smaller, more compact card for the horizontal list
    return InkWell(
      onTap: () {
        // TODO: Navigate to the full job details page using the jobId
        // For now, just show a message.
        _showMessage('Viewing details for: $title by $companyName');
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.90, // Card width: 90% of screen
        margin: const EdgeInsets.only(right: 15),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _accentColor.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: _textColor.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  width:  80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)
                    ]
                  ),
                  child: Column(
                    children: [
                      Text(title[0], style: GoogleFonts.merriweather(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _accentColor,
                      ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 5,width: 25,),
                Column(
                  children: [
                    //name
                    Text(
                      title,
                      style: GoogleFonts.merriweather(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _accentColor,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 2),

                    // organization
                    Text(
                      'ORG: ' + companyName,
                      style: GoogleFonts.openSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),

                    // industry
                    Text(
                      'Industry: ' + industry,
                      style: GoogleFonts.openSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 5),
                  ]
                ),
                ],
            ),
            const SizedBox(height: 8),
            // description
            Text(
              'Description: '+ description,
              style: GoogleFonts.openSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),

            // Location 
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: _textColor, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          location,
                          style: GoogleFonts.openSans(
                              fontSize: 10,
                              color: _textColor.withOpacity(0.8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

// -----------------------------------------------------------------------------
// --- NEW WIDGET: Horizontal Job Card (For Explore View) ---
// -----------------------------------------------------------------------------

  // Inside _EmployeeDashboardState class
Widget _buildHorizontalapplicationCard(
    BuildContext context,
    String jobId,
    String title,
    String companyName,
    String experience,
    String description,
  ) {
    // 1. Wrap the card in a fixed-width container for the horizontal ListView
    return InkWell(
      onTap: () {
        // TODO: Implement navigation to job details
        _showMessage('Viewing job details for $title at $companyName');
      },
      child: Container(
        // Set a fixed width for the card in the horizontal list
        width: MediaQuery.of(context).size.width * 0.80, // 80% of screen width
        margin: const EdgeInsets.only(top: 8, bottom: 8, right: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(252, 247, 224, 1),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: _textColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // Ensure column content is vertically spread if needed
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  // Top Row: Title and Bookmark
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(76, 88, 138, 1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'TITLE: $title',
                          style: GoogleFonts.merriweather(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromARGB(255, 76, 88, 138),
                          ),
                        ),
                      ),
                      IconButton(
                          icon: const Icon(Icons.bookmark_border, color: _accentColor, size: 20),
                          onPressed: () {
                            _SaveJobs(context,jobId,widget.userData['email'],title);
                          },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Company and Experience Details
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                        'Company : $companyName',
                        style: GoogleFonts.openSans(
                          fontSize: 12,
                          color: const Color.fromRGBO(44, 44, 44, 1).withOpacity(0.8),
                        ),
                      ),
                      Text(
                        'Experience : $experience',
                        style: GoogleFonts.openSans(
                          fontSize: 12,
                          color: _textColor.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Description
                      Text(
                        'Description: $description',
                        style: GoogleFonts.openSans(
                          fontSize: 12,
                          color: _textColor.withOpacity(0.8),
                        ),
                        maxLines: 4, // Allow multiple lines for description
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  
                  // Spacer to push the arrow down (or align to bottom)
                  const Spacer(), 
                  
                  // Arrow button (placed inside the Expanded column for better alignment)
                   Align(
                      alignment: Alignment.centerRight,
                      child: Icon(Icons.arrow_right, color: _accentColor, size: 30),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Inside _EmployeeDashboardState class
void _SaveJobs(
    BuildContext context, String jobId, String email, String title) async {
  // Ensure the function can run asynchronously
  final firestore = FirebaseFirestore.instance;
  final savedJobsCollection = firestore.collection('saved_jobs');

  try {
    // 1. Check if a document already exists with this specific jobId AND user email.
    final querySnapshot = await savedJobsCollection
        .where('job_id', isEqualTo: jobId)
        .where('user_email', isEqualTo: email)
        .limit(1) // Optimization: stop after finding the first match
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      // Job already exists, show feedback
      _showMessage('Job "$title" is ALREADY SAVED!');
      return;
    }

    // 2. Job does not exist, so create a new document to save it
    await savedJobsCollection.add({
      'job_id': jobId,
      'user_email': email,
      'job_title': title,
      'saved_date': FieldValue.serverTimestamp(), // Records the current time
    });

    // 3. Success message
    _showMessage('Job "$title" SUCCESSFULLY SAVED!');

  } on FirebaseException catch (e) {
    // Handle specific Firestore errors (e.g., permission denied)
    _showMessage('Error saving job: ${e.message}');
  } catch (e) {
    // Handle any other unexpected errors
    _showMessage('An unexpected error occurred.');
  }
}

// -----------------------------------------------------------------------------
// --- NEW WIDGET: Recommended recruiter List (Firestore Driven) ---
// -----------------------------------------------------------------------------

  Widget _buildRecommendedJobsView(BuildContext context) {
    // Use the qualification from the user data to filter jobs
    final String userIndustry = widget.userData['department'] as String? ?? '----';
    final firestore = FirebaseFirestore.instance;
    final jobsCollection = firestore.collection('recruiters');

    // Display a title suggesting the basis of the recommendation
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 150, // Fixed height for the horizontal list
          child: StreamBuilder<QuerySnapshot>(
            // Filter the documents where 'industry' matches the employee's qualification
            // and limit to a maximum of 4 results.
            stream: jobsCollection
                .where('industry', isEqualTo: userIndustry)
                .limit(4)
                .snapshots(),
            builder: (context, snapshot) {
              // --- Loading State ---
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _accentColor));
              }

              // --- Error State ---
              if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: GoogleFonts.openSans(color: Colors.red)));
              }

              final jobDocs = snapshot.data?.docs ?? [];

              // --- No Data State ---
              if (jobDocs.isEmpty) {
                return Center(
                  child: Text(
                    'No jobs found matching your qualification.',
                    style: GoogleFonts.merriweather(
                        fontSize: 16, color: _textColor.withOpacity(0.7)),
                  ),
                );
              }

              // --- Data Available State (Horizontal ListView) ---
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: jobDocs.length,
                itemBuilder: (context, index) {
                  final data = jobDocs[index].data() as Map<String, dynamic>;
                  final jobId = jobDocs[index].id;

                  // Safely extract data. Assume job_title, company_name, and location fields exist.
                  final title = data['name'] as String? ?? 'Unknown Job';
                  final companyName = data['organization'] as String? ?? 'Unknown org';
                  final industry = data['industry'] as String? ?? 'Unknown industry';
                  final description = data['description'] as String? ?? 'Unknown description';
                  final location = data['location'] as String? ?? 'None';

                  return _buildHorizontalJobCard(
                    context,
                    jobId,
                    title,
                    companyName,
                    industry,
                    description,
                    location,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }


// -----------------------------------------------------------------------------
// --- NEW WIDGET: Recommended Jobs List (Firestore Driven) ---
// -----------------------------------------------------------------------------

  Widget _buildRecommendedapplicationView(BuildContext context) {
    // Use the qualification from the user data to filter jobs
    final String userdegree= widget.userData['degree'] as String? ?? '----';
    final String userdepartment= widget.userData['department'] as String? ?? '----';
    final firestore = FirebaseFirestore.instance;
    final jobsCollection = firestore.collection('job_postings');

    // Display a title suggesting the basis of the recommendation
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220, // Fixed height for the horizontal list
          child: StreamBuilder<QuerySnapshot>(
            // Filter the documents where 'industry' matches the employee's qualification
            // and limit to a maximum of 4 results.
            stream: jobsCollection
                .where('qualification_degree', isEqualTo: userdegree)
                .where('qualification_field',isEqualTo: userdepartment)
                .limit(4)
                .snapshots(),
            builder: (context, snapshot) {
              // --- Loading State ---
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _accentColor));
              }

              // --- Error State ---
              if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: GoogleFonts.openSans(color: Colors.red)));
              }

              final jobDocs = snapshot.data?.docs ?? [];

              // --- No Data State ---
              if (jobDocs.isEmpty) {
                return Center(
                  child: Text(
                    'No jobs found matching your qualification.',
                    style: GoogleFonts.merriweather(
                        fontSize: 16, color: _textColor.withOpacity(0.7)),
                  ),
                );
              }

              // --- Data Available State (Horizontal ListView) ---
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: jobDocs.length,
                itemBuilder: (context, index) {
                  final data = jobDocs[index].data() as Map<String, dynamic>;
                  final jobId = jobDocs[index].id;

                  // Safely extract data. Assume job_title, company_name, and location fields exist.
                  final title = data['title'] as String? ?? 'Unknown Application';
                  final companyName = data['company_name'] as String? ?? 'Unknown org';
                  final experience = data['min_experience'] as String? ?? 'no experience';
                  final description = data['job_description'] as String? ?? 'Unknown description';

                  return _buildHorizontalapplicationCard(
                      context,
                      jobId,
                      title,
                      companyName,
                      experience,
                      description,
                    );
                },
              );
            },
          ),
        ),
      ],
    );
  }


}