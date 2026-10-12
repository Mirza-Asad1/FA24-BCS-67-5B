import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RegistrationScreen(),
    );
  }
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final nameController = TextEditingController();
  final regController = TextEditingController();

  String gender = 'Male';
  bool reading = false;
  bool sports = false;
  String optionChoice = 'Option 1';
  String? selectedItem;
  String department = 'CS';

  @override
  void dispose() {
    nameController.dispose();
    regController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Text
              const Text(
                'Student Registration Form',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              // 2. TextField - Name
              SizedBox(
                width: 300,
                child: TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Student Name'),
                ),
              ),

              // 3. TextField - Registration Number
              SizedBox(
                width: 300,
                child: TextField(
                  controller: regController,
                  decoration: const InputDecoration(
                    labelText: 'Registration Number',
                  ),
                ),
              ),

              // 4. Radio buttons - Gender
              const Text('Gender'),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: 'Male',
                    groupValue: gender,
                    onChanged: (v) => setState(() => gender = v!),
                  ),
                  const Text('Male'),
                  Radio<String>(
                    value: 'Female',
                    groupValue: gender,
                    onChanged: (v) => setState(() => gender = v!),
                  ),
                  const Text('Female'),
                ],
              ),

              // 5. Checkboxes - Hobbies
              const Text('Hobbies'),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Checkbox(
                    value: reading,
                    onChanged: (v) => setState(() => reading = v!),
                  ),
                  const Text('Reading'),
                  Checkbox(
                    value: sports,
                    onChanged: (v) => setState(() => sports = v!),
                  ),
                  const Text('Sports'),
                ],
              ),

              // 6. Option List - shows options, one can be chosen
              const Text('Option List'),
              SizedBox(
                width: 300,
                child: Column(
                  children: ['Option 1', 'Option 2', 'Option 3']
                      .map(
                        (o) => ListTile(
                          dense: true,
                          title: Text(o, textAlign: TextAlign.center),
                        ),
                      )
                      .toList(),
                ),
              ),

              // 7. Selection List - items that can be selected (tap)
              const Text('Selection List'),
              SizedBox(
                width: 300,
                child: Column(
                  children: ['Item A', 'Item B', 'Item C']
                      .map(
                        (item) => ListTile(
                          dense: true,
                          title: Text(item, textAlign: TextAlign.center),
                          selected: selectedItem == item,
                          onTap: () => setState(() => selectedItem = item),
                        ),
                      )
                      .toList(),
                ),
              ),

              // 8. Dropdown - Department
              const Text('Department'),
              DropdownButton<String>(
                value: department,
                items: ['CS', 'IT', 'SE', 'AI']
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => setState(() => department = v!),
              ),

              // 9. Simple button
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Button pressed')),
                  );
                },
                child: const Text('Button'),
              ),

              // 10. Submit button
              ElevatedButton(
                onPressed: () {
                  final hobbies = [
                    if (reading) 'Reading',
                    if (sports) 'Sports',
                  ].join(', ');
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Submitted'),
                      content: Text(
                        'Name: ${nameController.text}\n'
                        'Reg No: ${regController.text}\n'
                        'Gender: $gender\n'
                        'Hobbies: ${hobbies.isEmpty ? "None" : hobbies}\n'
                        'Selected item: ${selectedItem ?? "None"}\n'
                        'Department: $department',
                      ),
                    ),
                  );
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
