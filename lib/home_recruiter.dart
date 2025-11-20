import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// Note: We'll assume the imports for profile/login pages are appropriately named for 'Recruiter' or use the existing ones for a complete, runnable example.
import 'profile_recruiter.dart'; 
import 'login_page.dart'; 
import 'firebase_options.dart'; 
import 'application_recruiter.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'aptitudet_recruiter.dart';
import 'locate_employee.dart'; // We'll rename this logic later if a 'locate employee' screen exists

// --- NEW IMPORTS for Firebase Firestore ---
import 'package:cloud_firestore/cloud_firestore.dart';

// --- Theme & Color Definitions ---
const Color _parchmentColor = Color(0xFFF3E0B5); // Light cream background
const Color _cardColor = Color(0xFFFCF7E0); // Lighter card/inner content background
const Color _textColor = Color(0xFF2C2C2C); // Dark charcoal text
const Color _accentColor = Color(0xFF4C588A); // Indigo accent (icons/buttons)
const Color _secondaryAccentColor = Color(0xFF8B4513); // Sienna brown (top logo bar)
const Color _iconBackgroundColor = Color(0xFFE4C38B); // Mid-tone background for icons
const double _drawerWidthFactor = 0.75; // Drawer takes up 75% of screen width

// --- Recruiter Dashboard (Explore View) ---
class RecruiterDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  const RecruiterDashboard(this.userData, {super.key});

  @override
  State<RecruiterDashboard> createState() => _RecruiterDashboardState();
}

class _RecruiterDashboardState extends State<RecruiterDashboard> {
  int _selectedIndex = 0; // For bottom navigation bar (Explore/Applications)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // Key for Drawer access
  
  // New variable to hold the user's email/ID and CIN
  String get _userEmail => widget.userData['email'] as String? ?? 'Guest User';
  // IMPORTANT: Assume 'cin' is stored in userData for matching job postings
  String get _userCIN => widget.userData['cin_no'] as String? ?? ''; 

  // Define the pages for the BottomNavigationBar
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
    
    // Initialize the list of widgets after userData is available
    _widgetOptions = <Widget>[
      _buildExploreView(context), // Index 0: Explore/Home View
      RecruiterApplicationsScreen(_userCIN), // Index 1: Applications View
    ];
  }

  // Helper function to display a SnackBar message
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _accentColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Logic for 'locate employees' functionality
  void _handleLocateEmployees() {
    if (widget.userData['location'] == "----") {
      _showMessage('Please update your **Location** in your Profile to locate nearby companies.');
      return;
    }
    // For this example, we'll navigate to a generic placeholder screen.
    Navigator.push(context, MaterialPageRoute(builder: (context) =>  RecruiterSearchPage(widget.userData)));
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

  // --- Helper Widget: Recommendation Card (Employee/Job Application) ---
  Widget _buildRecommendationCard({
    required Widget content,
    bool showArrow = true,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: content),
          if (showArrow)
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 20),
              child: Icon(Icons.arrow_right, color: _accentColor, size: 30),
            ),
        ],
      ),
    );
  }

  // --- Employee Content Widget (for Recommended Employees) ---
  Widget _employeeContent({
    required String name,
    required String location,
    required String email,
    required String experience,
    required String imagePath, // Placeholder for image asset
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Employee Profile Image Placeholder
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 60,
            height: 60,
            color: _iconBackgroundColor.withOpacity(0.5),
            child: const Icon(Icons.person, color: _accentColor, size: 40),
            // In a real app, use Image.asset or Image.network here
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Name: $name',
                style: GoogleFonts.merriweather(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Location: $location',
                style: GoogleFonts.openSans(fontSize: 12, color: _textColor.withOpacity(0.8)),
              ),
              Text(
                'Email: $email',
                style: GoogleFonts.openSans(fontSize: 12, color: _textColor.withOpacity(0.8)),
              ),
              Text(
                'Experience: $experience',
                style: GoogleFonts.openSans(fontSize: 12, color: _textColor.withOpacity(0.8)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Job Application Content Widget ---
  Widget _jobApplicationContent(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _secondaryAccentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: _secondaryAccentColor),
          ),
          child: Text(
            'TITLE: $title',
            style: GoogleFonts.merriweather(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _secondaryAccentColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Description: $description',
          style: GoogleFonts.openSans(
            fontSize: 12,
            color: _textColor.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
  
  // --- Welcome User Header ---
  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome ,',
            style: GoogleFonts.openSans(
              fontSize: 18,
              color: _textColor.withOpacity(0.8),
            ),
          ),
          Text(
            widget.userData['name'], // Just display the username part of the email
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


  // --- EXPLORE VIEW WIDGET (Previous body content) ---
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
                          builder: (context) => RecruiterProfilePage(widget.userData)), 
                    );
                  }),
              _buildSettingCard(
                  icon: Icons.add_circle_outline,
                  label1: 'Add more',
                  label2: 'Application',
                  onTap: () {
                    Navigator.pushReplacement(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => JobApplicationForm(widget.userData))
                    );
                  }),
              _buildSettingCard(
                  icon: Icons.location_on_outlined,
                  label1: 'locate',
                  label2: 'employees',
                  onTap: _handleLocateEmployees),
            ],
          ),
          const SizedBox(height: 25),

          // --- 2. Recommended Employees Section ---
          _buildSectionHeader('RECOMMENDED EMPLOYEES'),
          _buildRecommendationCard(
            content: _employeeContent(
              name: "Michael Nguyen",
              location: "San Francisco, CA",
              email: "michael.ngu@email.com",
              experience: "Over 5 years of expertise in customer support and IT operations.",
              imagePath: 'assets/images/michael.jpg',
            ),
          ),
          _buildRecommendationCard(
            content: _employeeContent(
              name: "Jennifer Thompson",
              location: "New York, NY",
              email: "jennifer@email.com",
              experience: "6 years of expertise in customer support and IT operations.",
              imagePath: 'assets/images/jennifer.jpg',
            ),
          ),
          const SizedBox(height: 25),

          // --- 3. Jobs Applications Section ---
          _buildSectionHeader('JOBS APPLICATIONS'),
          _buildRecommendationCard(
            content: _jobApplicationContent(
              "Title: Data Analyst",
              "Description: Collect, interpret, and analyze large datasets to provide actionable business insights.",
            ),
            showArrow: false,
          ),
          _buildRecommendationCard(
            content: _jobApplicationContent(
              "Title: Cloud Engineer",
              "Description: Deploy, manage, and optimize cloud infrastructure. Ensure system scalability, reliability, and security.",
            ),
            showArrow: false,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey, // Attach the key to the Scaffold
      backgroundColor: _parchmentColor,
      drawer: _buildCustomDrawer(context), // Add the custom drawer here
      body: SafeArea(
        child: Column(
          children: [
            // --- Top Bar (Header/App Bar) ---
            _buildCustomAppBar(context),

            // --- Main Content (Selected View) ---
            Expanded(
              // Use the widget from the list based on the selected index
              child: _widgetOptions.elementAt(_selectedIndex), 
            ),
            
            // --- Bottom Navigation Bar ---
            _buildBottomNavBar(),
          ],
        ),
      ),
    );
  }


  // --- Custom Widget: Top App Bar (Slightly modified to match the style) ---
  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      height: 70,
      width: double.infinity,
      decoration: BoxDecoration( // Optional: rounded corners
            gradient: LinearGradient(
              begin: Alignment.topCenter, // Start of the gradient
              end: Alignment.bottomCenter, // End of the gradient
              colors: [
                const Color.fromRGBO(90, 76, 59, 100), // Starting color
                const Color.fromRGBO(120, 101, 78, 100), // Middle color
                const Color.fromARGB(230, 131, 114, 94), // Ending color
              ],
            ),
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

  // --- Custom Widget: Section Header (Unchanged) ---
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
  
  // --- Custom Drawer Menu (Omitted for brevity, assuming no change needed) ---
  Widget _buildCustomDrawer(BuildContext context) {
    // ... (Your existing _buildCustomDrawer code here)
    final double screenWidth = MediaQuery.of(context).size.width;
    
    // Helper for Menu Buttons
    Widget buildMenuButton(String label, {required VoidCallback onTap}) {
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
      backgroundColor: Colors.transparent, 
      child: Padding(
        padding: const EdgeInsets.only(right: 20.0, top: 20.0), 
        child: Container(
          decoration: BoxDecoration(
            color: _cardColor, 
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
                    // Display User ID/Email in the drawer header
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
                    buildMenuButton('Profile', onTap: () {
                       Navigator.pop(context); 
                       Navigator.push(context, MaterialPageRoute(builder: (context) => RecruiterProfilePage(widget.userData)));
                    }),
                    // Button: locate employee
                    buildMenuButton('locate employee', onTap: () {
                      Navigator.pop(context); 
                      _handleLocateEmployees();
                    }),
                    // Button: Add Applications (This context is confusing, but following the screenshot)
                    buildMenuButton('Add Applications', onTap: () {
                      Navigator.pushReplacement(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => JobApplicationForm(widget.userData))
                      );
                    }),
                    // Button: Add Aptitude Test (Following the screenshot)
                    buildMenuButton('Add Aptitude Test', onTap: () {
                      Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    // Assuming EmployeeProfilePage can handle recruiter data for simplicity
                                    builder: (context) => AptitudeTestForm(widget.userData)), 
                              );
                      _showMessage('Navigate to the "Add Aptitude Test" configuration.');
                    }),
                    // Log Out
                    buildMenuButton('LogOut', onTap: () {
                      Navigator.pushReplacement(
                        context, 
                        MaterialPageRoute(builder: (context) => const LoginPage()),
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

  // --- Custom Widget: Bottom Navigation Bar ---
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
            label: 'Explore', // From screenshot
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_outline), // Changed icon to match typical 'Applications'/'Saved' context
            label: 'Applications', // From screenshot
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// --- NEW WIDGET: RecruiterApplicationsScreen ---
// -----------------------------------------------------------------------------

class RecruiterApplicationsScreen extends StatelessWidget {
  final String cin; // The recruiter's CIN to filter job postings
  const RecruiterApplicationsScreen(this.cin,{super.key});

  // --- Helper Widget: Job Posting Card (Matches the screenshot style) ---
  Widget _buildJobPostCard(
      String title,
      String companyName,
      String experience,
      String startdate,
      String enddate,
      ) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _iconBackgroundColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child : const Icon(Icons.post_add, color: _accentColor, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.merriweather(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      companyName,
                      style: GoogleFonts.openSans(
                        fontSize: 14,
                        color: _textColor.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Location and Date Row
                    Row(
                      children: [
                        const Icon(Icons.work_history, color: _accentColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          experience,
                          style: GoogleFonts.openSans(
                            fontSize: 12,
                            color: _textColor.withOpacity(0.7),
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.calendar_month, color: _accentColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          startdate + ' - ' + enddate,
                          style: GoogleFonts.openSans(
                            fontSize: 12,
                            color: _textColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // --- Header Widget ---
  Widget _buildHeader() {
    return Column(
      children: [
        const SizedBox(height: 30),
        // Main 'Saved' Title
        Text(
          'APPLICATIONS',
          style: GoogleFonts.merriweather(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: const Color.fromRGBO(120, 101, 78, 1.0),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get a reference to the Firestore collection
    final firestore = FirebaseFirestore.instance;
    final jobPostingCollection = firestore.collection('job_postings');

    // 2. Build the StreamBuilder to fetch data
    return Container(
      color: _parchmentColor, // Use the same background color
      child: Column(
        children: [
          // Header content (Title and decorative elements)
          _buildHeader(),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Filter the documents where 'cin_no' matches the recruiter's CIN
              stream: jobPostingCollection.where('cin_no', isEqualTo: cin).snapshots(),
              builder: (context, snapshot) {
                // --- Loading State ---
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _accentColor));
                }

                // --- Error State ---
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading data: ${snapshot.error}', style: GoogleFonts.openSans(color: Colors.red)));
                }

                // --- No Data State ---
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        cin.isEmpty 
                            ? 'Error: Your CIN is not available. Please check your profile.' 
                            : 'You have not posted any jobs yet (CIN: $cin).',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.merriweather(fontSize: 16, color: _textColor.withOpacity(0.8)),
                      ),
                    ),
                  );
                }

                // --- Data Available State ---
                final jobPostings = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: jobPostings.length,
                  itemBuilder: (context, index) {
                    final data = jobPostings[index].data() as Map<String, dynamic>;
                    
                    // Safely extract data, providing fallbacks
                    final title = data['title'] as String? ?? 'Title Not Available';
                    final companyName = data['company_name'] as String? ?? 'Company Name Not Available';
                    final experience = data['min_experience'] as String? ?? 'no Experience';
                    final startDate = data['start_date'] as String? ?? '-';
                    final endDate = data['end_date'] as String? ?? '-';

                    return _buildJobPostCard(
                      title,
                      companyName,
                      experience,
                      startDate,
                      endDate,
                    );
                  },
                );
              },
            ),
          ),
          
          // Re-adding the bottom navigation bar overlay to complete the look
          // Note: The actual BottomNavigationBar is handled by the parent Scaffold.
          // This is just for visual completeness of the screenshot style below the list.
          Container(height: 70, color: Colors.transparent), // Space for the actual bottom nav bar
        ],
      ),
    );
  }
}

// --- Placeholder for the Navigation Target ---
class LocationBasedSearchPagePlaceholder extends StatelessWidget {
  const LocationBasedSearchPagePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Locate Employees'),
        backgroundColor: _secondaryAccentColor,
      ),
      body: const Center(
        child: Text('Map/Search view for locating employees goes here.'),
      ),
    );
  }
}