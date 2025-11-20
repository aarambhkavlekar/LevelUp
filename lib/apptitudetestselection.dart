import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Required for date formatting
import 'package:google_fonts/google_fonts.dart';
import 'home_emp.dart';
import 'taking_aptitude.dart';

// --- 1. Placeholder Model Classes ---

class AptitudeTest {
  final String recruiter_cin_no;
  final String id;
  final String testName;
  final int totalMarks;
  final int durationMinutes;
  final int totalQuestions;
  final String companyName;
  final DateTime dateRangeEnd; 

  AptitudeTest({
    this.recruiter_cin_no = '',
    this.id = '',
    this.testName = 'Aptitude Test',
    this.totalMarks = 0,
    this.durationMinutes = 0,
    this.totalQuestions = 0,
    this.companyName = 'Company Name',
    required this.dateRangeEnd,
  });
}

class TestResult {
  final String testId;
  final int marksAchieved;
  final int correctAnswers;
  final int totalQuestions;
  final DateTime dateCompleted;

  TestResult({
    required this.testId,
    required this.marksAchieved,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.dateCompleted,
  });
}

class Application {
  final String recruiterCinNo;
  final String jobTitle;
  
  Application({required this.recruiterCinNo, required this.jobTitle});
}

// --- 2. Main Screen Widget ---

class AptitudeTestScreen extends StatefulWidget {
  // Accepts user data map passed from the previous screen
  final Map<String, dynamic> userData;

  const AptitudeTestScreen(this.userData,{super.key});

  @override
  State<AptitudeTestScreen> createState() => _AptitudeTestScreenState();
}

class _AptitudeTestScreenState extends State<AptitudeTestScreen> {
  // 0 for New Test, 1 for Test Result
  int _selectedTabIndex = 0; 
  bool _isLoading = true;

  // Lists to hold the fetched and categorized data
  List<AptitudeTest> _newTests = [];
  List<Map<String, dynamic>> _completedTests = []; // Combines TestResult with AptitudeTest details

  // Current user's email, crucial for fetching applications
  late final String _currentUserEmail;

  @override
  void initState() {
    super.initState();
    // Safely retrieve the email from the passed userData map
    _currentUserEmail = widget.userData['email']?.toString() ?? 'default@example.com';
    _fetchTestData();
  }

  // Helper function to safely parse the 'date_completed' from the 'takes' collection
  DateTime _parseCompletedDate(dynamic dateData) {
    if (dateData is Timestamp) {
      return dateData.toDate();
    }
    if (dateData is String) {
      try {
        // Attempt to parse the common date string format from the screenshot
        // e.g., "26 October 2025 at 22:05:01 UTC+5:30" - we strip the timezone part
        return DateFormat('dd MMMM yyyy at HH:mm:ss').parse(dateData.split(' UTC')[0]);
      } catch (e) {
        // Fallback to standard DateTime parse or default
        try {
          return DateTime.parse(dateData);
        } catch (_) {
          return DateTime.now();
        }
      }
    }
    return DateTime.now();
  }

  // --- Data Fetching Logic (CORRECTED LIST POPULATION) ---

  Future<void> _fetchTestData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    // Clear lists BEFORE fetching and populating them
    _newTests.clear();
    _completedTests.clear();

    try {
      final db = FirebaseFirestore.instance;

      // 1. Fetch Applications for the current user
      final appSnapshot = await db
          .collection('application')
          .where('employee_email', isEqualTo: _currentUserEmail)
          .get();

      final List<Application> applications = appSnapshot.docs.map((doc) => Application(
          recruiterCinNo: doc['recruiter_cin_no']?.toString() ?? '', 
          jobTitle: doc['job_title']?.toString() ?? '')
      ).where((app) => app.recruiterCinNo.isNotEmpty && app.jobTitle.isNotEmpty).toList();

      if (applications.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. Fetch Test Results from the 'takes' collection
      final resultsSnapshot = await db
          .collection('takes') // Corrected collection name
          .where('employee_email', isEqualTo: _currentUserEmail)
          .get();
      
      final Map<String, TestResult> resultsMap = {
        for (var doc in resultsSnapshot.docs) 
          if (doc.data().containsKey('test_id'))
            (doc['test_id'] as String): TestResult(
              testId: doc['test_id'] as String,
              // Use field names from screenshot
              marksAchieved: (doc['marks_achieved'] as num?)?.toInt() ?? 0,
              correctAnswers: (doc['correct_answers'] as num?)?.toInt() ?? 0,
              totalQuestions: (doc['total_questions'] as num?)?.toInt() ?? 0,
              dateCompleted: _parseCompletedDate(doc['date_completed']),
            )
      };

      // 3. Find and collect ALL Aptitude Tests associated with the user's applications
      List<AptitudeTest> allTests = [];
      Set<String> processedTestIds = {}; 

      final DateFormat firestoreDateFormat = DateFormat('dd/MM/yyyy');

      for (var app in applications) {
        final testSnapshot = await db
            .collection('Aptitude_test')
            .where('recruiter_cin', isEqualTo: app.recruiterCinNo)
            .where('job_posting_title', isEqualTo: app.jobTitle)
            .get();

        for (var doc in testSnapshot.docs) {
          final data = doc.data();
          final testId = doc.id;
          
          if (processedTestIds.add(testId)) { // Only process each unique test once
            final duration = (data['duration'] as num?)?.toInt() ?? 0;
            final totalQuestions = (data['no_of_questions'] as num?)?.toInt() ?? 0;
            final totalMarks = (data['total_marks'] as num?)?.toInt() ?? 0;
            
            // Date parsing logic remains for Aptitude_test end_date
            DateTime dateRangeEnd;
            final endDateString = data['end_date']?.toString();
            try {
                if (endDateString != null && endDateString.isNotEmpty) {
                  dateRangeEnd = firestoreDateFormat.parse(endDateString);
                } else {
                  dateRangeEnd = DateTime.now();
                }
            } catch (e) {
                final endDateTimestamp = data['end_date'] as Timestamp?;
                dateRangeEnd = endDateTimestamp?.toDate() ?? DateTime.now();
            }
            
            allTests.add(AptitudeTest(
                recruiter_cin_no: data['recruiter_cin'],
                id: testId,
                testName: data['test_title']?.toString() ?? 'Aptitude Test',
                totalMarks: totalMarks,
                durationMinutes: duration,
                totalQuestions: totalQuestions,
                companyName: data['company_name']?.toString() ?? 'Company Name', 
                dateRangeEnd: dateRangeEnd, 
            ));
          }
        }
      }

      // 4. Categorize the tests AFTER all fetches are complete
      for (var test in allTests) {
        if (resultsMap.containsKey(test.id)) {
            final result = resultsMap[test.id]!;
            _completedTests.add({'test': test, 'result': result});
        } else {
            _newTests.add(test);
        }
      }

    } catch (e) {
      print('FATAL ERROR in _fetchTestData: $e'); 
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(243, 224, 181, 1),
      appBar: AppBar(
        title: Text('Search',style: GoogleFonts.merriweather(color: Colors.white, fontWeight: FontWeight.bold)),
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
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Aptitude Test",
                  style: GoogleFonts.merriweather(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromRGBO(120, 101, 78, 1.0),
                  ),
                ),
                const SizedBox(height: 10),
                _buildTabToggle(),
              ],
            ),
          ),
          
          // Content Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedTabIndex == 0
                    ? _buildNewTestList()
                    : _buildTestResultList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabToggle() {
    return Container(
      decoration: BoxDecoration(
        color:  Color.fromRGBO(120, 101, 78, 1.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _TabButton(
              text: 'New Test',
              isSelected: _selectedTabIndex == 0,
              onTap: () => setState(() => _selectedTabIndex = 0),
            ),
          ),
          Expanded(
            child: _TabButton(
              text: 'Test Result',
              isSelected: _selectedTabIndex == 1,
              onTap: () => setState(() => _selectedTabIndex = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewTestList() {
    if (_newTests.isEmpty) {
      return const Center(
        child: Text('No new tests currently assigned.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _newTests.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: NewTestCard(widget.userData,test: _newTests[index]),
        );
      },
    );
  }

  Widget _buildTestResultList() {
    if (_completedTests.isEmpty) {
      return const Center(
        child: Text('No test results found.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _completedTests.length,
      itemBuilder: (context, index) {
        final data = _completedTests[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TestResultCard(
            result: data['result'] as TestResult,
            test: data['test'] as AptitudeTest,
          ),
        );
      },
    );
  }
}

// --- 3. Reusable UI Components ---

// Reusable Tab Button
class _TabButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;
  const _TabButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: isSelected ?  const Color.fromRGBO(252, 247, 224, 1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
          border: isSelected ? Border.all(color: Colors.grey.shade300) : null,
          boxShadow: isSelected 
              ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]
              : null,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Color.fromRGBO(120, 101, 78, 1.0)  : const Color.fromRGBO(252, 247, 224, 1) ,
          ),
        ),
      ),
    );
  }
}

// Card for a New Test
class NewTestCard extends StatelessWidget {
  final AptitudeTest test;
  final Map<String, dynamic> userDatafinal;
  const NewTestCard(this.userDatafinal,{super.key, required this.test});

  @override
  Widget build(BuildContext context) {
    // Format date for display (e.g., "26 sep - 30 sep 2025")
    final String dateRange = DateFormat('dd MMM yyyy').format(test.dateRangeEnd); 

    return Card(
      color: const Color.fromRGBO(252, 247, 224, 1),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Title: ' + test.testName,style: GoogleFonts.merriweather(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 76, 88, 138),
                        ),),
            const SizedBox(height: 4),

            const Divider(),

            // Row 1: Company and Date
            Row(
              children: [
                Expanded(child: _DetailChip(icon: Icons.business, value: test.companyName)),
                Expanded(child: _DetailChip(icon: Icons.calendar_month, value: dateRange)),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Duration and Questions
            Row(
              children: [
                Expanded(child: _DetailChip(icon: Icons.timer, value: '${test.durationMinutes}mins')),
                Expanded(child: _DetailChip(icon: Icons.question_mark, value: '${test.totalQuestions} questions')),
              ],
            ),
            const SizedBox(height: 16),
            
            // Start Button
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(context, 
                    MaterialPageRoute(builder: (context) => AptitudeTestPage(test.recruiter_cin_no,test.testName,userDatafinal) ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Starting ${test.testName} now...')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(76, 88, 138, 1),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Start', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// Card for a Completed Test Result
class TestResultCard extends StatelessWidget {
  final TestResult result;
  final AptitudeTest test; // Original test details for context

  const TestResultCard({super.key, required this.result, required this.test});

  @override
  Widget build(BuildContext context) {
    // Format date for display
    final String dateCompleted = DateFormat('dd MMM yyyy').format(result.dateCompleted);

    // Calculate score display (e.g., "4/5 correct")
    final String correctDisplay = '${result.correctAnswers}/${result.totalQuestions} correct';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Test Name', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(test.testName),
            const Divider(),

            // Row 1: Company and Date Completed
            Row(
              children: [
                Expanded(child: _DetailChip(icon: Icons.business, value: test.companyName)),
                Expanded(child: _DetailChip(icon: Icons.calendar_month, value: dateCompleted)),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Marks Achieved and Correct Answers
            Row(
              children: [
                Expanded(child: _DetailChip(icon: Icons.score, value: '${result.marksAchieved} marks')),
                Expanded(child: _DetailChip(icon: Icons.check_circle, value: correctDisplay, color: Colors.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


// Small widget to display an icon and a value
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color? color;

  const _DetailChip({required this.icon, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey[600]),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value, 
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: color ?? Colors.black87)
            ),
          ),
        ],
      ),
    );
  }
}