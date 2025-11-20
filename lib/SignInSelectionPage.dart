import 'package:flutter/material.dart';
import 'login_page.dart';      // Recruiter Login Page
import 'login_page_emp.dart'; // Employee Login Page

class SignInSelectionPage extends StatefulWidget {
  const SignInSelectionPage({super.key});

  @override
  State<SignInSelectionPage> createState() => _SignInSelectionPageState();
}

class _SignInSelectionPageState extends State<SignInSelectionPage>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _contentController;
  late Animation<double> _logoFadeAnimation;
  late Animation<Offset> _logoSlideAnimation;
  late Animation<double> _titleFadeAnimation;
  late Animation<Offset> _titleSlideAnimation;
  late Animation<double> _button1FadeAnimation;
  late Animation<Offset> _button1SlideAnimation;
  late Animation<double> _button2FadeAnimation;
  late Animation<Offset> _button2SlideAnimation;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Logo animations
    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    _logoSlideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    // Title animation
    _titleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _titleSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Button 1 animation (Recruiter)
    _button1FadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeIn),
      ),
    );

    _button1SlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );

    // Button 2 animation (Employee)
    _button2FadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.5, 0.8, curve: Curves.easeIn),
      ),
    );

    _button2SlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
      ),
    );

    // Start animations
    Future.delayed(const Duration(milliseconds: 100), () {
      _logoController.forward();
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      _contentController.forward();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(212, 195, 153, 1),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
             // 🔹 Animated Logo Placeholder (replace with Image.asset later)
            SlideTransition(
              position: _logoSlideAnimation,
              child: FadeTransition(
                opacity: _logoFadeAnimation,
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(60),
                        // ✅ No background color here, only shadow if needed
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromRGBO(212, 195, 153, 1).withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(60),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
              const SizedBox(height: 40),

              // SignIn Title
              SlideTransition(
                position: _titleSlideAnimation,
                child: FadeTransition(
                  opacity: _titleFadeAnimation,
                  child: const Text(
                    'SignIn',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C4168),
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 35),

              // Recruiter Button
              SlideTransition(
                position: _button1SlideAnimation,
                child: FadeTransition(
                  opacity: _button1FadeAnimation,
                  child: _buildButton(
                    'Recruiter',
                    const Color.fromRGBO(76, 88, 138, 1),

                    Colors.white,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Employee Button
              SlideTransition(
                position: _button2SlideAnimation,
                child: FadeTransition(
                  opacity: _button2FadeAnimation,
                  child: _buildButton(
                    'Employee',
                    Colors.grey.shade400,
                    Colors.black,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EmployeesLoginPage(),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    String text,
    Color backgroundColor,
    Color textColor,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(29),
          ),
          elevation: 3,
          shadowColor: Colors.black.withOpacity(0.25),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            fontFamily: 'Roboto',
            color: textColor,
          ),
        ),
      ),
    );
  }
}
