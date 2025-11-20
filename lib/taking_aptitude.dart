import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // For the Timer
import 'package:google_fonts/google_fonts.dart';
import 'package:levelup/home_emp.dart';

// NOTE: Ensure 'package:levelup/home_emp.dart' is available or remove it if not needed.
// import 'package:levelup/home_emp.dart'; // Keeping it commented out unless user provides this file.

// -------------------------------------------------------------------
// MODELS
// -------------------------------------------------------------------

class TestDetails {
  final String id;
  final String testName; // Corresponds to test_title
  final int totalMarks;
  final int durationMinutes;
  final int totalQuestions;
  final String companyName;
  final String dateRangeEnd; // Retained as String based on your data structure

  TestDetails({
    required this.id,
    required this.testName,
    required this.totalMarks,
    required this.durationMinutes,
    required this.totalQuestions,
    required this.companyName,
    required this.dateRangeEnd,
  });
}

class Question {
  final String id;
  final String text;
  final List<String> options;
  // The correct answer is the option string, derived from the 'correct_index' in Firestore.
  final String correctAnswer; 
  
  Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctAnswer,
  });
}

// Reusable Detail Chip Widget (Unchanged)
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String value;

  const _DetailChip({required this.icon, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color:  Colors.grey[600]),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value, 
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.black87)
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// THE MAIN APTITUDE TEST TAKING PAGE
// -------------------------------------------------------------------

class AptitudeTestPage extends StatefulWidget {
  final String recruiterCin;
  final String testTitle; // Corresponds to test_title in Firestore (e.g., "ui/ux")
  final Map<String, dynamic> userData; // Contains employee_email

  const AptitudeTestPage(
    this.recruiterCin,
    this.testTitle,
    this.userData,{
    super.key,
    
  });

  @override
  State<AptitudeTestPage> createState() => _AptitudeTestPageState();
}

class _AptitudeTestPageState extends State<AptitudeTestPage> {
  // State management
  bool _isLoading = true;
  bool _isTestStarted = false;
  TestDetails? _testDetails; // Holds the fetched test document data
  
  // Test data and state
  List<Question> _questions = [];
  Map<String, String> _selectedAnswers = {}; // {questionId: selectedOption}
  
  // Timer variables
  int _timeRemaining = 0;
  Timer? _timer;
  
  // Test calculation variables
  double _marksPerQuestion = 0.0;
  
  // Database IDs (for the 'takes' collection)
  late final String _currentUserEmail;
  
  @override
  void initState() {
    super.initState();
    
    _currentUserEmail = widget.userData['email']?.toString() ?? 'unknown_user';
    
    _fetchTestAndQuestions(); 
  }
  
  // --- Back Button Prevention Logic (Unchanged) ---
  
  Future<bool> _onWillPop() async {
    if (_isTestStarted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test in progress! You must submit to exit.')),
      );
      return false; 
    }
    return true; 
  }

  // --- Data Fetching and Initialization (CORRECTED LOGIC) ---

  Future<void> _fetchTestAndQuestions() async {
    try {
      // 1. Fetch the main Aptitude Test Document using the correct fields
      final testSnapshot = await FirebaseFirestore.instance
          .collection('Aptitude_test')
          .where('recruiter_cin', isEqualTo: widget.recruiterCin)
          .where('test_title', isEqualTo: widget.testTitle) 
          .limit(1)
          .get();

      if (testSnapshot.docs.isEmpty) {
        throw Exception("Aptitude Test document not found for CIN: ${widget.recruiterCin} and Test Title: ${widget.testTitle}");
      }
      
      final testDoc = testSnapshot.docs.first;
      final testData = testDoc.data();
      
      // Parse main Test Details
      _testDetails = TestDetails(
        id: testDoc.id,
        testName: testData['test_title']?.toString() ?? widget.testTitle, 
        totalMarks: (testData['total_marks'] as num?)?.toInt() ?? 0,
        durationMinutes: (testData['duration'] as num?)?.toInt() ?? 0,
        totalQuestions: (testData['no_of_questions'] as num?)?.toInt() ?? 0,
        companyName: testData['company_name']?.toString() ?? 'N/A',
        dateRangeEnd: testData['end_date']?.toString() ?? 'N/A',
      );

      // Check for basic completeness before fetching questions
      if (_testDetails!.totalMarks == 0 || _testDetails!.durationMinutes == 0 || _testDetails!.totalQuestions == 0) {
         throw Exception("Test configuration incomplete (Marks, Duration, or Total Questions is 0).");
      }
      
      // 2. Fetch Questions by iterating through the 'Question_i' fields
      _questions = [];
      for (int i = 1; i <= _testDetails!.totalQuestions; i++) {
        final questionKey = 'Question_$i';
        
        // Ensure the field exists and is a Map
        final questionMap = testData[questionKey] as Map<String, dynamic>?; 
        
        if (questionMap != null) {
          final optionsList = List<String>.from(questionMap['options'] as List? ?? []);
          final questionText = questionMap['question']?.toString() ?? 'Question $i Text Missing';
          // Correct index is the integer value in the 'correct_index' field
          final correctIndex = (questionMap['correct_index'] as num?)?.toInt() ?? -1; 
          
          String correctAnswerStr = '';
          if (correctIndex >= 0 && correctIndex < optionsList.length) {
            // Get the actual option string using the index
            correctAnswerStr = optionsList[correctIndex]; 
          }

          _questions.add(Question(
            id: questionKey, // Use Question_i as the ID
            text: questionText,
            options: optionsList,
            correctAnswer: correctAnswerStr,
          ));
        } else {
          // If a question is missing, throw an error to prevent starting the test.
          throw Exception("Question $i data is missing or corrupted in the test document.");
        }
      }
      
      // Final check on fetched questions
      if (_questions.isEmpty) {
        throw Exception("No valid questions were successfully parsed from the test document fields.");
      }
      
      // Calculate marks per question
      _marksPerQuestion = _testDetails!.totalMarks / _questions.length;
      
      // Initialize timer based on fetched duration
      _timeRemaining = (_testDetails!.durationMinutes) * 60;
      
    } catch (e) {
      print("Error fetching test details or questions: $e");
      
      if (mounted) {
         // Show a generic error snackbar to the user
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to load test: ${e.toString().split(':').last.trim()}')),
         );
      }
      // Set details to null to render the descriptive error screen in build
      _testDetails = null; 
      _questions = [];
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // NOTE: _parseDate method is no longer needed since dateRangeEnd is a String in TestDetails.
  
  // --- Timer Logic (Unchanged) ---
  void _startTimer() {
    if (_isTestStarted) return; 
    
    // Safety check before starting
    if (_testDetails == null || _questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot start: Test data is missing or incomplete.')),
      );
      return;
    }
    
    setState(() {
      _isTestStarted = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_timeRemaining > 0) {
        setState(() {
          _timeRemaining--;
        });
      } else {
        timer.cancel();
        _handleSubmitTest(isTimeout: true);
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  // --- Submission Logic (Unchanged) ---

  void _handleSubmitTest({bool isTimeout = false}) async {
    if (!mounted || _testDetails == null) return;
    
    _timer?.cancel();
    setState(() {
      _isTestStarted = false;
      _isLoading = true; // Show loading indicator
    });

    int correctAnswers = 0;
    double marksObtained = 0.0;
    
    // Calculate Score
    for (var question in _questions) {
      final selected = _selectedAnswers[question.id];
      if (selected != null && selected == question.correctAnswer) {
        correctAnswers++;
        marksObtained += _marksPerQuestion; 
      }
    }
    
    // Submission data for the 'takes' collection
    final submissionData = {
      'employee_email': _currentUserEmail,
      'recruiter_cin_no': widget.recruiterCin,
      'job_title': widget.testTitle, // Using the testTitle passed in the constructor
      'test_id': _testDetails!.id,
      'marks_achieved': marksObtained.round(), 
      'correct_answers': correctAnswers,
      'total_questions': _questions.length,
      'duration_taken_seconds': (_testDetails!.durationMinutes * 60) - _timeRemaining,
      'date_completed': FieldValue.serverTimestamp(),
      'is_timeout': isTimeout,
    };
    
    // Store in 'takes' collection
    try {
      await FirebaseFirestore.instance.collection('takes').add(submissionData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isTimeout 
                  ? 'Time up! Test submitted automatically. Score: ${marksObtained.round()} / ${_testDetails!.totalMarks}'
                  : 'Test submitted successfully! Score: ${marksObtained.round()} / ${_testDetails!.totalMarks}',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        // Navigate back to the employee dashboard (Assuming EmployeeDashboard is the intended screen)
        // If EmployeeDashboard is not available, change this to Navigator.pop(context)
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => EmployeeDashboard(widget.userData)));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => EmployeeDashboard(widget.userData) )); 
      }
    } catch (e) {
      print('Error submitting test results: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submission failed. Check your database connection.')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  // --- UI Building (Unchanged) ---
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color.fromRGBO(243, 224, 181, 1),
        appBar: AppBar(
          title: Text('Aptitude Test',style: GoogleFonts.merriweather(color: Colors.white, fontWeight: FontWeight.bold)),
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
          automaticallyImplyLeading: !_isTestStarted, 
          leading: _isTestStarted 
              ? null 
              : GestureDetector(
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
          actions: 
          <Widget>[
            if (_isTestStarted)
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: Text(
                    'Time Left: ${_formatTime(_timeRemaining)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _timeRemaining < 60 ? Colors.red.shade700 : Colors.white,
                    ),
                  ),
                ),
              )
              else 
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
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : (_testDetails == null || _questions.isEmpty) 
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        "Test details or questions could not be loaded from the database. Please check Firestore paths/data.", 
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.red),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: _isTestStarted ? _buildQuestionList() : _buildPreStartScreen(),
                      ),
                      _buildBottomButton(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildPreStartScreen() {
    final details = _testDetails!; 
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                details.testName,
                style: GoogleFonts.merriweather(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo.shade700),
              ),
              const Divider(height: 20),
              _DetailChip(icon: Icons.business, value: details.companyName),
              _DetailChip(icon: Icons.timer, value: '${details.durationMinutes} minutes'),
              _DetailChip(icon: Icons.question_mark, value: '${_questions.length} Questions'),
              _DetailChip(icon: Icons.score, value: '${details.totalMarks} Total Marks (${_marksPerQuestion.toStringAsFixed(1)} per Q)'),
              const SizedBox(height: 24),
              const Text(
                'Warning: You cannot exit once the test has started until you submit or the timer runs out.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final question = _questions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}. ${question.text}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const Divider(),
                ...question.options.map((option) {
                  return RadioListTile<String>(
                    title: Text(option, style: const TextStyle(fontSize: 15)),
                    value: option,
                    groupValue: _selectedAnswers[question.id],
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          _selectedAnswers[question.id] = value;
                        });
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: const Color.fromRGBO(243, 224, 181, 1),
      child: ElevatedButton(
        // Button is disabled if loading or test details failed to load
        onPressed: (_isLoading || _testDetails == null || _questions.isEmpty) 
            ? null 
            : (_isTestStarted ? _handleSubmitTest : _startTimer),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isTestStarted ? Colors.green.shade700 : const Color.fromRGBO(76, 88, 138, 1),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          _isTestStarted ? 'SUBMIT TEST' : 'START TEST',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}