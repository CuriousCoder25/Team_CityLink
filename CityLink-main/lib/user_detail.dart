import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserDetailsScreen extends StatefulWidget {
  const UserDetailsScreen({super.key});

  @override
  _UserDetailsScreenState createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  String? _detectedMunicipality;
  List<String> _municipalityList = [];
  String? _selectedMunicipality;
  final _formKey = GlobalKey<FormState>();
  String? _userId; // Hold the userId from arguments
  String? _firstName, _lastName, _citizenshipNumber, _email, _phoneNumber;
  bool _isCheckingCitizenship = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Extract arguments passed from OTP screen
    final arguments = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _userId = arguments['userId']; // Retrieve userId
    _phoneNumber = arguments['phoneNumber']; // Retrieve phoneNumber

    // Provide a fallback in case 'detectedMunicipality' is null
    _detectedMunicipality = arguments['detectedMunicipality'] ?? 'Unknown Municipality'; // Default value
    _fetchMunicipalities();
  }


  Future<void> _fetchMunicipalities() async {
    final snapshot = await FirebaseFirestore.instance.collection('Municipalities').get();
    setState(() {
      _municipalityList = snapshot.docs.map((doc) => doc.data()['name'] as String).toList();

      // Ensure that the detected municipality exists in the list, or fallback to the first item
      if (_detectedMunicipality != null && _municipalityList.contains(_detectedMunicipality)) {
        _selectedMunicipality = _detectedMunicipality;
      } else {
        _selectedMunicipality = _municipalityList.isNotEmpty ? _municipalityList.first : null;
      }
    });
  }

  Future<bool> _isCitizenshipNumberUnique(String citizenshipNumber) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('Users')
        .where('citizenship_number', isEqualTo: citizenshipNumber)
        .get();

    return querySnapshot.docs.isEmpty;
  }

  Future<void> _saveDetails() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() {
        _isCheckingCitizenship = true;
      });

      // Check for unique citizenship number
      bool isUnique = await _isCitizenshipNumberUnique(_citizenshipNumber!);

      setState(() {
        _isCheckingCitizenship = false;
      });

      if (!isUnique) {
        // Show error if the citizenship number already exists
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Citizenship number is already in use.')),
        );
        return;
      }

      // Save the user details if the citizenship number is unique
      await FirebaseFirestore.instance.collection('Users').doc(_userId).set({
        'name': _firstName,
        'surname': _lastName,
        'citizenship_number': _citizenshipNumber,
        'email': _email,
        'phone_number': _phoneNumber, // Save the phone number
      });

      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // First Dropdown for Municipality
              DropdownButtonFormField<String>(
                value: _selectedMunicipality,
                items: _municipalityList.map((municipality) {
                  return DropdownMenuItem(value: municipality, child: Text(municipality));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMunicipality = value;
                  });
                },
                decoration: const InputDecoration(labelText: 'Municipality'),
              ),

              TextFormField(
                decoration: const InputDecoration(labelText: 'First Name'),
                onSaved: (value) => _firstName = value,
                validator: (value) => value!.isEmpty ? 'First name is required' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Last Name'),
                onSaved: (value) => _lastName = value,
                validator: (value) => value!.isEmpty ? 'Last name is required' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Citizenship Number'),
                onSaved: (value) => _citizenshipNumber = value,
                validator: (value) => value!.isEmpty ? 'Citizenship number is required' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email (Optional)'),
                onSaved: (value) => _email = value,
              ),
              const SizedBox(height: 20),
              _isCheckingCitizenship
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _saveDetails,
                child: const Text('Save & Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}