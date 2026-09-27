import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const StudentCardApp());
}

// ============================================================
// MAIN APP
// ============================================================

class StudentCardApp extends StatefulWidget {
  const StudentCardApp({super.key});

  @override
  State<StudentCardApp> createState() => _StudentCardAppState();
}

class _StudentCardAppState extends State<StudentCardApp> {
  bool isDarkMode = false;

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Student Card',
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // LIGHT THEME
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF3F4F8),
        fontFamily: 'Roboto',
      ),

      // DARK THEME
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF111318),
        fontFamily: 'Roboto',
      ),

      home: StudentCardScreen(
        isDarkMode: isDarkMode,
        onThemeChanged: toggleTheme,
      ),
    );
  }
}

// ============================================================
// STUDENT CARD SCREEN
// ============================================================

class StudentCardScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeChanged;

  const StudentCardScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<StudentCardScreen> createState() => _StudentCardScreenState();
}

class _StudentCardScreenState extends State<StudentCardScreen> {
  // ----------------------------------------------------------
  // STUDENT INFORMATION
  // ----------------------------------------------------------

  String name = 'Mirza Asad';
  String regNumber = 'FA24-BCS-067';
  String department = 'Computer Science';
  String semester = '5th Semester';
  String section = 'Section B';
  String email = 'mohammadasadmunir@gmail.com';

  // ----------------------------------------------------------
  // GET ALL INFORMATION FOR QR / SHARE
  // ----------------------------------------------------------

  String get studentInformation {
    return '''
Student Card

Name: $name
Registration Number: $regNumber
Department: $department
Semester: $semester
Section: $section
Email: $email
''';
  }

  // ==========================================================
  // EDIT STUDENT INFORMATION
  // ==========================================================

  void editStudentInformation() {
    final nameController = TextEditingController(text: name);
    final regController = TextEditingController(text: regNumber);
    final departmentController = TextEditingController(text: department);
    final semesterController = TextEditingController(text: semester);
    final sectionController = TextEditingController(text: section);
    final emailController = TextEditingController(text: email);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Edit Student Information',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: regController,
                  decoration: const InputDecoration(
                    labelText: 'Registration Number',
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: departmentController,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    prefixIcon: Icon(Icons.school),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: semesterController,
                  decoration: const InputDecoration(
                    labelText: 'Semester',
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sectionController,
                  decoration: const InputDecoration(
                    labelText: 'Section',
                    prefixIcon: Icon(Icons.groups),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save'),
              onPressed: () {
                setState(() {
                  name = nameController.text;
                  regNumber = regController.text;
                  department = departmentController.text;
                  semester = semesterController.text;
                  section = sectionController.text;
                  email = emailController.text;
                });

                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Student information updated!',
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // COPY INFORMATION
  // ==========================================================

  void copyToClipboard(String value, String label) {
    Clipboard.setData(
      ClipboardData(text: value),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==========================================================
  // SHOW QR CODE
  // ==========================================================

  void showQRCode() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Student QR Code',
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: 250,
            height: 290,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(
                  data: studentInformation,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Scan this QR code to view student information',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // SHARE STUDENT INFORMATION
  // ==========================================================

  Future<void> shareStudentInformation() async {
    await Share.share(
      studentInformation,
      subject: 'Student Card - $name',
    );
  }

  // ==========================================================
  // BUILD SCREEN
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Student Card',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Toggle Dark Mode',
            onPressed: widget.onThemeChanged,
            icon: Icon(
              widget.isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 30,
            ),
            child: StudentCard(
              imagePath: 'assets/images/Student.jpeg',
              name: name,
              regNumber: regNumber,
              department: department,
              semester: semester,
              section: section,
              email: email,
              onEdit: editStudentInformation,
              onQR: showQRCode,
              onShare: shareStudentInformation,
              onCopyEmail: () {
                copyToClipboard(
                  email,
                  'Email',
                );
              },
              onCopyReg: () {
                copyToClipboard(
                  regNumber,
                  'Registration number',
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// STUDENT CARD WIDGET
// ============================================================

class StudentCard extends StatelessWidget {
  final String imagePath;
  final String name;
  final String regNumber;
  final String department;
  final String semester;
  final String section;
  final String email;

  final VoidCallback onEdit;
  final VoidCallback onQR;
  final VoidCallback onShare;
  final VoidCallback onCopyEmail;
  final VoidCallback onCopyReg;

  const StudentCard({
    super.key,
    required this.imagePath,
    required this.name,
    required this.regNumber,
    required this.department,
    required this.semester,
    required this.section,
    required this.email,
    required this.onEdit,
    required this.onQR,
    required this.onShare,
    required this.onCopyEmail,
    required this.onCopyReg,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF3B41C5);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 380,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1F26) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ==================================================
          // HEADER
          // ==================================================

          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF3B41C5),
                      Color(0xFF6366F1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: Column(
                    children: [
                      Text(
                        'STUDENT CARD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          letterSpacing: 3,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'CSC303 • MOBILE APPLICATION DEVELOPMENT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ==================================================
              // STUDENT IMAGE
              // ==================================================

              Positioned(
                top: 62,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: AssetImage(imagePath),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 60),

          // ==================================================
          // NAME
          // ==================================================

          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1F2333),
            ),
          ),

          const SizedBox(height: 8),

          // ==================================================
          // REGISTRATION NUMBER
          // ==================================================

          GestureDetector(
            onTap: onCopyReg,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF292D3A) : const Color(0xFFEEF0FE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    regNumber,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.copy,
                    size: 14,
                    color: primaryColor,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 25),

          // ==================================================
          // INFORMATION
          // ==================================================

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 25,
            ),
            child: Column(
              children: [
                // DEPARTMENT
                InfoRow(
                  icon: Icons.school_rounded,
                  label: 'Department',
                  value: department,
                ),

                const Divider(height: 25),

                // SEMESTER
                InfoRow(
                  icon: Icons.calendar_month_rounded,
                  label: 'Semester',
                  value: semester,
                ),

                const Divider(height: 25),

                // SECTION
                InfoRow(
                  icon: Icons.groups_rounded,
                  label: 'Section',
                  value: section,
                ),

                const Divider(height: 25),

                // EMAIL
                InfoRow(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  value: email,
                  trailing: IconButton(
                    tooltip: 'Copy Email',
                    onPressed: onCopyEmail,
                    icon: const Icon(
                      Icons.copy,
                      size: 18,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // ==================================================
          // ACTION BUTTONS
          // ==================================================

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(
                      Icons.edit,
                    ),
                    label: const Text(
                      'Edit',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onQR,
                    icon: const Icon(
                      Icons.qr_code_2,
                    ),
                    label: const Text(
                      'QR Code',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onShare,
                icon: const Icon(
                  Icons.share,
                ),
                label: const Text(
                  'Share Student Card',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 25),

          // ==================================================
          // FOOTER
          // ==================================================

          Text(
            'CSC303 • Student Profile',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.grey.shade500,
            ),
          ),

          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

// ============================================================
// INFORMATION ROW
// ============================================================

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // ICON BOX
        Container(
          padding: const EdgeInsets.all(9),

          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF292D3A) : const Color(0xFFEEF0FE),
            borderRadius: BorderRadius.circular(10),
          ),

          // FIX:
          // Previously this was:
          // Icons.info_outline
          //
          // Now it uses the icon passed to InfoRow.
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFF3B41C5),
          ),
        ),

        const SizedBox(width: 14),

        // TEXT
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.grey,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // TRAILING BUTTON
        if (trailing != null) trailing!,
      ],
    );
  }
}
