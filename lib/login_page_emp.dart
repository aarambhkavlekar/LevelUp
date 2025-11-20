import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:levelup/SignInSelectionPage.dart'; 
// Renamed the import to match the new file name (home_emp.dart)
import 'home_emp.dart'; // <-- Use EmployeeDashboard
import 'signin_page_emp.dart'; // File containing the Employees Sign Up Page
import 'package:cloud_firestore/cloud_firestore.dart'; 

// --- Color Definitions (Matching the established parchment/vintage theme) ---
const Color _parchmentColor = Color(0xFFF3E0B5); // Light cream background
const Color _cardColor = Color(0xFFFCF7E0); // Lighter card background
const Color _textColor = Color(0xFF2C2C2C); // Dark charcoal text
const Color _buttonColor = Color(0xFF4C588A); // Indigo button color

// FIX: Add 'const' to the constructor in login_page.dart
class EmployeesLoginPage extends StatefulWidget {
  const EmployeesLoginPage({super.key}); // <--- Make sure this 'const' is present!

  @override
  State<EmployeesLoginPage> createState() => _EmployeesLoginPageState();
}
class _EmployeesLoginPageState extends State<EmployeesLoginPage> {
  // Controllers for input fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _contactController = TextEditingController(); 

  // State variable to hold and display error messages
  String _errorMessage = ''; 

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _contactController.dispose(); 
    super.dispose();
  }
  
  // Function to handle login using Firestore
  void _handleLogin() async {
    // Clear previous errors at the start of a new attempt
    setState(() {
      _errorMessage = ''; 
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final contact = _contactController.text.trim(); 

    if (email.isEmpty || password.isEmpty || contact.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter all required details.')),
        );
        return;
    }
    
    // --- Firestore Check Logic ---
    try {
      final db = FirebaseFirestore.instance;
      
      // Query the 'employees' collection for the provided email.
      final querySnapshot = await db.collection('employees') // <-- Targeting 'employees' collection
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // User not found
        setState(() {
          _errorMessage = 'Invalid details';
        });
        return;
      }

      // User document found, retrieve the stored data
      // Use .data() which returns Map<String, dynamic>
      final userData = querySnapshot.docs.first.data(); 
      final storedContact = userData['contact'] as String?;
      final storedPassword = userData['password'] as String?;
      
      // Check if the provided contact AND password match the stored data
      if (storedContact == contact && storedPassword == password) {
        // Success: Show a green SnackBar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Employees Login Successful for $email!"),
              backgroundColor: Colors.green,
            ),
          );
          
          // PASS USER DATA TO EmployeeDashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                // 1. MODIFICATION: Pass the userData map to the constructor
                builder: (context) => EmployeeDashboard(userData)),
          );
        }
      } else {
        // Contact or Password mismatch
        setState(() {
          _errorMessage = 'Invalid details';
        });
      }

    } catch (e) {
      // Handle Firebase and network errors
      print('Firestore Error during employees login: $e'); 
      setState(() {
        _errorMessage = 'An error occurred during login. Please check connection.';
      });
    }
  }

  // Helper function to create the styled input field (consistent with Sign Up Page)
  Widget _buildInputField({
    required TextEditingController controller,
    required String labelText,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
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
          controller: controller, 
          obscureText: isPassword,
          keyboardType: keyboardType,
          style: const TextStyle(color: _textColor, fontSize: 16),
          decoration: InputDecoration(
            labelText: labelText,
            labelStyle: TextStyle(color: _textColor.withOpacity(0.6), fontSize: 16),
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
                    const SizedBox(height: 50),
                    // Main Welcome Title (using GoogleFonts.merriweather)
                    Text(
                      "Welcome to\nLevelUp", 
                      textAlign: TextAlign.center,
                      style: GoogleFonts.merriweather(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // --- Form Card Container (The main visual element) ---
                    Container(
                      padding: const EdgeInsets.all(30.0), 
                      margin: const EdgeInsets.only(top: 10, bottom: 20),
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
                          // Card Header: Login Title (Indigo)
                          Center(
                            child: Text(
                              "Employees Login",
                              style: GoogleFonts.merriweather(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: _buttonColor, 
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Email Input
                          _buildInputField(
                              controller: _emailController,
                              labelText: "Email",
                              keyboardType: TextInputType.emailAddress),

                          // Contact Input
                          _buildInputField(
                              controller: _contactController,
                              labelText: "Contact",
                              keyboardType: TextInputType.phone),

                          // Password Input
                          _buildInputField(
                              controller: _passwordController,
                              labelText: "Password",
                              isPassword: true),
                          
                          const SizedBox(height: 10), // Reduced spacing here

                          // Error Message Display
                          if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: Text(
                                _errorMessage,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          
                          // Space before the actual button
                          const SizedBox(height: 10), 

                          // Log In Button
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
                              onPressed: _handleLogin, 
                              child: const Text(
                                "Log In",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),
                          
                          // Bottom Navigation Row (Back and Signin)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Back Button
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: _textColor, size: 28),
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => const SignInSelectionPage()),
                                  );
                                },
                              ),
                              
                              // Signin Text Button
                              TextButton(
                                onPressed: () {
                                  // Navigate to the Employees Sign Up Page
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => const SignInPage()), // Navigates to Employees Sign In
                                  );
                                },
                                child: const Text(
                                  "Sign up",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _textColor,
                                  ),
                                ),
                              ),
                            ],
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
            // NOTE: Uncomment and fix the image asset path if needed
            child: Center(
              child: Image.asset(
                'assets/images/logo.png', // 👈 make sure path matches your YAML
                height: 200,   // adjust size as needed
                fit: BoxFit.contain,
              ),
              
            ),
            // Temporary Text placeholder for logo since asset path is unknown
          ),

          ],
        ),
      ),
    );
  }
}