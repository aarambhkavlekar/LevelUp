import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:levelup/application_recruiter.dart';
import 'dart:async';
import 'package:levelup/home_recruiter.dart';

// Theme Definitions (Reusing your colors)
const Color _parchmentColor = Color(0xFFF3E0B5);
const Color _cardColor = Color(0xFFFCF7E0);
const Color _textColor = Color(0xFF2C2C2C);
const Color _accentColor = Color(0xFF4C588A);
const Color _secondaryAccentColor = Color(0xFF8B4513);
const Color _submitButtonColor = Color(0xFF4C588A);

// Data Model for a single Question
class QuestionBlock {
  String question = '';
  List<String> options = ['', '', '', ''];
  int correctOptionIndex = -1;

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'correct_index': correctOptionIndex,
    };
  }
}

// Special option value for when no job posts exist
const String _noPostingsOption = 'Add Job Posting ';

class AptitudeTestForm extends StatefulWidget {
  final Map<String, dynamic> userData;

  const AptitudeTestForm(this.userData, {super.key});

  @override
  State<AptitudeTestForm> createState() => _AptitudeTestFormState();
}

class _AptitudeTestFormState extends State<AptitudeTestForm> {
  final _formKey = GlobalKey<FormState>();

  // NEW CONTROLLER for Job Posting
  String? _selectedJobPosting;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _marksController = TextEditingController();

  // DATE CONTROLLERS
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  List<QuestionBlock> _questions = [QuestionBlock()];
  bool _isSubmitting = false;

  // List to hold fetched job posting titles
  List<String> _jobPostingTitles = [];
  bool _isLoadingJobTitles = true;

  @override
  void initState() {
    super.initState();
    _fetchJobPostingTitles();
  }

  // --- New Data Fetching Method ---
  Future<void> _fetchJobPostingTitles() async {
    final String recruiterCin = widget.userData['cin_no'] as String? ?? '';
    if (recruiterCin.isEmpty) {
      _showSnackBar('Cannot load job postings.', color: Colors.red);
      setState(() {
        _isLoadingJobTitles = false;
        _jobPostingTitles = [_noPostingsOption]; // Fallback option
        _selectedJobPosting = _noPostingsOption;
      });
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('job_postings')
          .where('cin_no', isEqualTo: recruiterCin)
          .get();

      final titles = querySnapshot.docs.map((doc) => doc['title'] as String).toList();
      
      setState(() {
        _jobPostingTitles = titles;
        if (_jobPostingTitles.isEmpty) {
          _jobPostingTitles.add(_noPostingsOption);
          _selectedJobPosting = _noPostingsOption;
        } else {
          // Optionally pre-select the first item if posts exist
          _selectedJobPosting = _jobPostingTitles.first;
        }
        _isLoadingJobTitles = false;
      });
    } catch (e) {
      print('Error fetching job postings: $e');
      _showSnackBar('Error loading job postings.', color: Colors.red);
      setState(() {
        _isLoadingJobTitles = false;
        _jobPostingTitles = [_noPostingsOption];
        _selectedJobPosting = _noPostingsOption;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _durationController.dispose();
    _marksController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  // --- Core Methods ---

  void _addQuestionBlock() {
    setState(() {
      _questions.add(QuestionBlock());
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_formKey.currentContext != null) {
        Scrollable.ensureVisible(
          _formKey.currentContext!,
          alignment: 1.0,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

  void _removeQuestionBlock(int index) {
    if (_questions.length > 1) {
      setState(() {
        _questions.removeAt(index);
      });
    }
  }

  Future<void> _submitTest() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill all required static fields.', color: Colors.orange);
      return;
    }

    // NEW VALIDATION: Check if a valid job posting is selected
    if (_selectedJobPosting == null || _selectedJobPosting == _noPostingsOption) {
      _showSnackBar('Please select a valid Job Posting to link this test to.', color: Colors.red);
      return;
    }

    if (_questions.any((q) => q.correctOptionIndex == -1 || q.question.trim().isEmpty)) {
      _showSnackBar('Please ensure every question has text and a correct answer marked.', color: Colors.orange);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final String recruiterCin = widget.userData['cin_no'] as String? ?? 'UNKNOWN_CIN';
      if (recruiterCin == 'UNKNOWN_CIN') {
        throw Exception("Recruiter CIN not found in user data.");
      }

      final Map<String, dynamic> questionsMap = {};
      _questions.asMap().entries.forEach((entry) {
        questionsMap['Question_${entry.key + 1}'] = entry.value.toMap();
      });

      final Map<String, dynamic> testData = {
        'recruiter_cin': recruiterCin,
        'job_posting_title': _selectedJobPosting, // NEW FIELD
        'test_title': _titleController.text,
        'company_name': _companyController.text,
        'no_of_questions': _questions.length,
        'duration': _durationController.text.isNotEmpty ? int.tryParse(_durationController.text) : null,
        'total_marks': _marksController.text.isNotEmpty ? int.tryParse(_marksController.text) : null,
        'start_date': _startDateController.text, // "DD/MM/YYYY" format
        'end_date': _endDateController.text,    // "DD/MM/YYYY" format
        'created_at': FieldValue.serverTimestamp(),
        ...questionsMap,
      };

      await FirebaseFirestore.instance.collection('Aptitude_test').add(testData);

      _showSnackBar('Aptitude Test submitted successfully!', color: Colors.green);
      _resetForm();

    } catch (e) {
      _showSnackBar('Failed to submit test: ${e.toString()}');
      print('Submission Error: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _companyController.clear();
    _durationController.clear();
    _marksController.clear();
    _startDateController.clear();
    _endDateController.clear();
    setState(() {
      _questions = [QuestionBlock()];
      // Reset selected job posting to initial state
      if (_jobPostingTitles.isNotEmpty) {
        _selectedJobPosting = _jobPostingTitles.first;
      }
    });
  }
  void _showSnackBar(String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // --- UI Builders ---
//Add Job POsting First
  // NEW: Builds the Job Posting Dropdown Field
  Widget _buildJobPostingDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: _selectedJobPosting,
        decoration: InputDecoration(
          labelText: 'Job',
          labelStyle: GoogleFonts.openSans(color: _textColor.withOpacity(0.7)),
          fillColor: Colors.white,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        ),
        style: GoogleFonts.openSans(color: _textColor),
        isExpanded: true,
        items: _jobPostingTitles.map((String title) {
          return DropdownMenuItem<String>(
            value: title,
            child: Text(
              title,
              style: GoogleFonts.openSans(
                color: title == _noPostingsOption ? Colors.red : _textColor,
                fontWeight: title == _noPostingsOption ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue == _noPostingsOption) {
            // Perform navigation here
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => JobApplicationForm(widget.userData)),
            );
          } else {
            // Update the selected value for normal items
            setState(() {
              _selectedJobPosting = newValue;
            });
          }
        },
        validator: (value) {
          if (value == null || value.isEmpty || value == _noPostingsOption) {
            return 'Please select a valid job posting';
          }
          return null;
        },
      ),
    );
  }
  
  // Builds a standard text field (used for title, company, marks, duration)
  Widget _buildTextField(TextEditingController controller, String label, {bool isNumeric = false, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.openSans(color: _textColor.withOpacity(0.7)),
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
          if (isNumeric && value != null && value.isNotEmpty && int.tryParse(value) == null) {
            return 'Must be a number';
          }
          return null;
        },
      ),
    );
  }

  // Builds a date field with a picker
  Widget _buildDateField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        readOnly: true, // Prevents manual text input
        onTap: () async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2101),
            builder: (context, child) {
              return Theme(
                data: ThemeData.light().copyWith(
                  primaryColor: _secondaryAccentColor, // Header background
                  colorScheme: const ColorScheme.light(primary: _secondaryAccentColor),
                  buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
                ),
                child: child!,
              );
            },
          );
          
          if (pickedDate != null) {
            String formattedDate = DateFormat('dd/MM/yyyy').format(pickedDate);
            setState(() {
              controller.text = formattedDate; // Update the text field
            });
          }
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.openSans(color: _textColor.withOpacity(0.7)),
          fillColor: Colors.white,
          filled: true,
          suffixIcon: const Icon(Icons.calendar_today, color: _secondaryAccentColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        ),
        style: GoogleFonts.openSans(color: _textColor),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '$label is required';
          }
          return null;
        },
      ),
    );
  }
  
  // Builds the dynamic question/answer block (No Change)
  Widget _buildQuestionBlock(QuestionBlock qBlock, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 25.0),
      padding: const EdgeInsets.all(15.0),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(color: _accentColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: _textColor.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${index + 1}',
                style: GoogleFonts.merriweather(fontSize: 16, fontWeight: FontWeight.bold, color: _secondaryAccentColor),
              ),
              if (_questions.length > 1)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _removeQuestionBlock(index),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: qBlock.question,
            maxLines: 3,
            onChanged: (value) => qBlock.question = value,
            decoration: InputDecoration(
              labelText: 'Type the question here',
              labelStyle: GoogleFonts.openSans(),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(10),
            ),
            style: GoogleFonts.openSans(color: _textColor),
          ),
          const SizedBox(height: 15),
          Text(
            'Options & Correct Answer (Tick the correct one)',
            style: GoogleFonts.openSans(fontWeight: FontWeight.w600, color: _textColor),
          ),
          const SizedBox(height: 5),
          ...List.generate(4, (optionIndex) {
            return Row(
              children: [
                Checkbox(
                  value: qBlock.correctOptionIndex == optionIndex,
                  onChanged: (bool? isChecked) {
                    setState(() {
                      qBlock.correctOptionIndex = isChecked! ? optionIndex : -1;
                    });
                  },
                  activeColor: _accentColor,
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: qBlock.options[optionIndex],
                    onChanged: (value) => qBlock.options[optionIndex] = value,
                    decoration: InputDecoration(
                      hintText: 'Option ${optionIndex + 1}',
                      filled: true,
                      fillColor: Colors.white,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    style: GoogleFonts.openSans(color: _textColor),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _parchmentColor,
      appBar: AppBar(
        toolbarHeight: 70,
        title: Text('Aptitude Test Form', style: GoogleFonts.merriweather(color: Colors.white, fontWeight: FontWeight.bold)),
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
            padding: const EdgeInsets.only(right: 5.0),
            child: const CircleAvatar(
              backgroundImage: AssetImage('assets/images/logo.png'),
              backgroundColor: Colors.transparent,
              radius: 30,
            ),
          ),
        ],
        leading: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RecruiterDashboard(widget.userData)),
            );
          },
          child: const Column(
            children: [
              SizedBox(height: 1),
              Image(
                image: AssetImage('assets/images/back_button.png'),
                height: 50,
              ),
              Text('BACK', style: TextStyle(color: Colors.black, fontSize: 10)),
            ],
          ),
        ),
      ),
      body: _isLoadingJobTitles
          ? const Center(child: CircularProgressIndicator(color: _accentColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Job Posting Selection ---
                    Text(
                      'JOB Detail',
                      style: GoogleFonts.merriweather(fontSize: 20, fontWeight: FontWeight.bold, color: _textColor),
                    ),
                    const Divider(color: _accentColor),
                    _buildJobPostingDropdown(), // NEW DROPDOWN

                    // --- Static Test Details ---
                    const SizedBox(height: 20),
                    Text(
                      'Test Details',
                      style: GoogleFonts.merriweather(fontSize: 20, fontWeight: FontWeight.bold, color: _textColor),
                    ),
                    const Divider(color: _accentColor),
                    _buildTextField(_titleController, 'Test Title', required: true),
                    _buildTextField(_companyController, 'Company Name', required: true),
                    _buildTextField(_durationController, 'Duration (mins)', isNumeric: true),
                    _buildTextField(_marksController, 'Total Marks', isNumeric: true),

                    // Date Fields
                    Row(
                      children: [
                        Expanded(child: _buildDateField(_startDateController, 'Start Date')),
                        const SizedBox(width: 10),
                        Expanded(child: _buildDateField(_endDateController, 'End Date')),
                      ],
                    ),

                    // --- Dynamic Questions Section ---
                    const SizedBox(height: 20),
                    Text(
                      'Add Questions',
                      style: GoogleFonts.merriweather(fontSize: 20, fontWeight: FontWeight.bold, color: _textColor),
                    ),
                    const Divider(color: _accentColor),

                    // Question Blocks
                    ..._questions.asMap().entries.map((entry) {
                      return _buildQuestionBlock(entry.value, entry.key);
                    }).toList(),

                    // "ADD QUESTIONS" Button
                    ElevatedButton.icon(
                      onPressed: _addQuestionBlock,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: Text('ADD QUESTIONS', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _secondaryAccentColor,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // --- SUBMIT Button ---
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitTest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _submitButtonColor,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'SUBMIT TEST',
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