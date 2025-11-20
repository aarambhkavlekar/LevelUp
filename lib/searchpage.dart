import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_emp.dart';


// You must replace this with your actual firebase_options.dart file import
// import 'firebase_options.dart'; 

// --- 1. Data Models ---

class JobPosting {
  final String jobId; 
  final String title; 
  final String description;
  final String companyName;
  final String minExperience;
  final String qualificationDegree;
  final String department;

  JobPosting({
    required this.jobId,
    required this.title,
    required this.description,
    required this.companyName,
    required this.minExperience,
    required this.qualificationDegree,
    required this.department,
  });

  factory JobPosting.fromFirestore(String id, Map<String, dynamic> data) {
    return JobPosting(
      jobId: id,
      // ASSUMPTION: Using 'job_title' if available, or 'company_name' as the primary title display.
      title: data['title'], 
      description: data['job_description'] ?? 'No Description provided.',
      companyName: data['company_name'] ?? 'N/A',
      minExperience: data['min_experience'] ?? '0 year', 
      qualificationDegree: data['qualification_degree'] ?? 'N/A', 
      department: data['department'] ?? 'N/A',
    );
  }
}

// UserData class is removed, using Map<String, dynamic> directly.


// --- 2. Firestore Service ---

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<JobPosting>> fetchJobPostings({
    required String? searchText,
    required String? domain, 
    required String? userType, 
    required String? department, 
  }) async {
    Query query = _db.collection('job_postings');

    // 1. Apply Tag Filters (using qualification_degree for Domain)
    if (domain != null && domain != 'All') {
      query = query.where('qualification_degree', isEqualTo: domain);
    }
    
    // 2. Apply Tag Filters (using qualification_department for Domain)
    if (department != null && department != 'All') {
      query = query.where('qualification_field', isEqualTo: department);
    }

    // 3. Apply Tag Filters (using usertype)
    if (userType != null && userType != 'All') {
      query = query.where('min_experience', isEqualTo: userType);
    }


    final snapshot = await query.get();

    List<JobPosting> jobs = snapshot.docs.map((doc) {
      return JobPosting.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
    }).toList();

    // 2. Client-Side Filtering (for text search and complex filters like User Type)
    // jobs = jobs.where((job) {
    //   // A. Text Search: Title, Company, or Description
    //   bool matchesSearch = true;
    //   if (searchText != null && searchText.isNotEmpty) {
    //     final lowerSearch = searchText.toLowerCase();
    //     matchesSearch = job.title.toLowerCase().contains(lowerSearch) ||
    //         job.description.toLowerCase().contains(lowerSearch) ||
    //         job.companyName.toLowerCase().contains(lowerSearch);
    //   }

    //   // B. User Type Filter: Maps min_experience to selected type
    //   bool matchesUserType = true;
    //   if (userType != null && userType != 'All') {
    //     final minExp = int.tryParse(job.minExperience.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    //     if (userType == '5 year') {
    //       matchesUserType = minExp == 5;
    //     } else if (userType == '2 year') {
    //       matchesUserType = minExp > 2;
    //     }
    //   }

    //   return matchesSearch && matchesUserType;
    // }).toList();

    

    return jobs;
  }

  // Application check using the employee_email from userData Map
  Future<bool> hasUserApplied(String jobId, String userEmail) async {
    final snapshot = await _db.collection('application') 
        .where('jobId', isEqualTo: jobId) 
        .where('employee_email', isEqualTo: userEmail) // Check against the user's email
        .limit(1) 
        .get();

    return snapshot.docs.isNotEmpty;
  }
}


// --- 3. Job Search Page UI/Logic (UPDATED) ---

class JobSearchPage extends StatefulWidget {
  // CHANGED: userData is now Map<String, dynamic>
  final Map<String, dynamic> userData; 

  const JobSearchPage(this.userData,{super.key});

  @override
  State<JobSearchPage> createState() => _JobSearchPageState();
}

class _JobSearchPageState extends State<JobSearchPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  
  // Filter States
  String? _selectedDomain = 'All'; 
  String? _selectedUserType = 'All'; 
  String? _selectedDepartment= 'All'; 
  
  Key _futureBuilderKey = UniqueKey(); 
  
  // Dropdown Options
  final List<String> _domains = ['All', 'B.E.', 'M.Tech', 'B.Sc']; 
  final List<String> _userTypes = ['All', '5 year', '2 year']; 
  final List<String> _departments = ['All', 'Computer Science', 'Civil','Mechanical']; 

  // Store user email for frequent application checks
  late final String _userEmail;

  @override
  void initState() {
    super.initState();
    // Safely extract email from the userData map
    _userEmail = widget.userData['email'] ?? 'unknown@example.com';
    _searchController.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onFilterChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    setState(() {
      _futureBuilderKey = UniqueKey();
    });
  }
  
  Widget _buildFilterDropdown({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        margin: const EdgeInsets.symmetric(vertical: 2.0),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(252, 247, 224, 1),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.white54),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
            dropdownColor: const Color.fromRGBO(252, 247, 224, 1),
            style: const TextStyle(color: Colors.black, fontSize: 14),
            items: items.map<DropdownMenuItem<String>>((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                onChanged(newValue);
              });
              _onFilterChanged(); 
            },
          ),
        ),
      ),
    );
  }

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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildSearchBar(),
              const SizedBox(height: 12),
              
              // --- Filter Dropdowns Row 1 ---
              Row(
                children: [
                  _buildFilterDropdown(
                    value: _selectedDomain, items: _domains,
                    onChanged: (val) => _selectedDomain = val,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              const SizedBox(height: 8),
              
              // --- Filter Dropdowns Row 2 ---
              Row(
                children: [
                  _buildFilterDropdown(
                    value: _selectedUserType, items: _userTypes,
                    onChanged: (val) => _selectedUserType = val,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterDropdown(
                    value: _selectedDepartment, items: _departments,
                    onChanged: (val) => _selectedDepartment = val,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // --- Job List (FutureBuilder) ---
              Expanded(
                child: FutureBuilder<List<JobPosting>>(
                  key: _futureBuilderKey, 
                  future: _firestoreService.fetchJobPostings(
                    searchText: _searchController.text.trim(),
                    domain: _selectedDomain,
                    userType: _selectedUserType,
                    department: _selectedDepartment,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFE8C8A8)));
                    } else if (snapshot.hasError) {
                      print('Firestore Error: ${snapshot.error}');
                      return Center(child: Text('Error: ${snapshot.error.toString()}', style: const TextStyle(color: Colors.red)));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No job postings found.', style: TextStyle(color: Colors.black)));
                    }
                    
                    final jobs = snapshot.data!;
                    return ListView.builder(
                      itemCount: jobs.length,
                      itemBuilder: (context, index) {
                        final job = jobs[index];
                        
                        // Check application status for each job
                        return FutureBuilder<bool>(
                          future: _firestoreService.hasUserApplied(job.jobId, _userEmail),
                          builder: (context, appliedSnapshot) {
                            final hasApplied = appliedSnapshot.data ?? false; 
                            return _buildJobCard(job, hasApplied);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EAE8), 
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Hinted search text',
          border: InputBorder.none,
          icon: const Icon(Icons.menu, color: Colors.black54),
          suffixIcon: IconButton(
            icon: const Icon(Icons.search, color: Colors.black54),
            onPressed: _onFilterChanged,
          ),
        ),
        onSubmitted: (_) => _onFilterChanged(),
      ),
    );
  }

  Widget _buildJobCard(JobPosting job, bool hasApplied) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(252, 247, 224, 1), 
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasApplied ? Colors.green : const Color(0xFFE8C8A8),
          width: hasApplied ? 2.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // TITLE Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(76, 88, 138, 1).withOpacity(0.1), 
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'TITLE: ${job.title}', 
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 76, 88, 138),
                  ),
                ),
              ),
              // Applied Status
              Row(
                children: [
                  if (hasApplied)
                    const Text('APPLIED', style: TextStyle(color: Color.fromARGB(255, 21, 50, 22), fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Icon(
                    hasApplied ? Icons.bookmark : Icons.bookmark_border,
                    color: hasApplied ? Color.fromARGB(255, 21, 50, 22) : Colors.black,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Description
          Text(
            'Description: ${job.description}',
            style: const TextStyle(color: Color.fromRGBO(44, 44, 44, 1), fontSize: 14),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          // Metadata
          Text(
            'Company: ${job.companyName} | Exp: ${job.minExperience} | Degree: ${job.qualificationDegree}',
            style: const TextStyle(color: Color.fromRGBO(44, 44, 44, 1), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
