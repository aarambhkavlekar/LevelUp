import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'home_emp.dart';
import 'login_page_emp.dart';
import 'package:google_fonts/google_fonts.dart'; 
// NOTE: Assuming 'firebase_options.dart' contains the necessary configuration
import 'firebase_options.dart'; 

// --- Color Definitions (Refined to match the parchment/vintage theme) ---
const Color _parchmentColor = Color(0xFFF3E0B5); // Light cream background
const Color _cardColor = Color(0xFFFCF7E0); // Lighter card background
const Color _textColor = Color(0xFF2C2C2C); // Dark charcoal text
const Color _buttonColor = Color(0xFF4C588A); // Indigo button color

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  // Text controllers updated to match the First Name and Last Name fields in the image
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Initialization check for Firebase
  @override
  void initState() {
    super.initState();
    // Initialize Firebase if it hasn't been already.
    // In a typical Flutter environment, this is usually done in main()
    if (Firebase.apps.isEmpty) {
      Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose(); // Dispose the new controller
    _contactController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Function to submit data to Firestore
  Future<void> _submitData() async {
    // Basic validation updated for First Name and Last Name
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all required fields.')),
        );
      }
      return;
    }

    try {
      // Add data to a 'recruiters' collection with updated field names
      await FirebaseFirestore.instance.collection('employees').add({
        'firstName': _firstNameController.text.trim(), // Updated field name
        'lastName': _lastNameController.text.trim(),   // Updated field name (replaces cin_no)
        'contact': _contactController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(), // In a real app, hash this!
        'createdAt': Timestamp.now(),
      });
      final email = _emailController.text.trim();
      final db = FirebaseFirestore.instance;
      final querySnapshot = await db.collection('employees') // <-- Targeting 'employees' collection
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      final userData = querySnapshot.docs.first.data(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recruiter account created successfully!')),
        );
        // Navigate to the Login Page upon success
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => EmployeeDashboard(userData)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create account: $e')),
        );
      }
    }
  }

  // Helper function to create the styled input field (matching the original look)
  Widget _buildInputField({
    required TextEditingController controller,
    required String labelText,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    // Defines the padding used for all text fields
    const textFieldPadding = EdgeInsets.symmetric(vertical: 8.0);

    return Padding(
      padding: textFieldPadding,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 0,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: controller, // Link controller
          obscureText: isPassword,
          keyboardType: keyboardType,
          style: const TextStyle(color: _textColor, fontSize: 16),
          decoration: InputDecoration(
            labelText: labelText,
            labelStyle: TextStyle(color: _textColor.withOpacity(0.6), fontSize: 16),
            // Remove border for a cleaner look
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _parchmentColor, // Light cream background
      body: SafeArea(
        child: Column(
          children: [
            // Expanded area for the main content (form card)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    // Main Welcome Title (using GoogleFonts.merriweather)
                    Text(
                      "Welcome to LevelUp !",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.merriweather(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // --- Form Card Container (The main visual element) ---
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 0,
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Card Header (Back arrow and "Enter your Details")
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: _textColor),
                                onPressed: () {
                                  // Navigate back to LoginPage (assuming it handles both types)
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const EmployeesLoginPage(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              const Text("Enter your Details", style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _textColor,
                                )
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // First Name Input 
                          _buildInputField(controller: _firstNameController, labelText: "First Name"),

                          // Last Name Input
                          _buildInputField(
                              controller: _lastNameController,
                              labelText: "Last Name"), 
                          
                          // Contact No Input
                          _buildInputField(
                              controller: _contactController,
                              labelText: "Contact No.",
                              keyboardType: TextInputType.phone),

                          // Email Input
                          _buildInputField(
                              controller: _emailController,
                              labelText: "Email",
                              keyboardType: TextInputType.emailAddress),

                          // Password Input
                          _buildInputField(
                              controller: _passwordController,
                              labelText: "Password",
                              isPassword: true),
                          
                          const SizedBox(height: 30),

                          // Create Account Button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _buttonColor, // Indigo
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 5,
                              ),
                              onPressed: _submitData, // Call the submit function
                              child: const Text(
                                "Create Account",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 🔻 Bottom Solid Color Bar
            Container(
            height: 100,
            width: double.infinity,
            decoration: const BoxDecoration(
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
            child: Center(
              child: Image.asset(
                'assets/images/logo.png', // 👈 make sure path matches your YAML
                height: 200,  // adjust size as needed
                fit: BoxFit.contain,
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
