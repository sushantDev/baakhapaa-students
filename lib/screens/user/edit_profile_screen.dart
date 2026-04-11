import 'package:baakhapaa/screens/user/user_screen.dart';
import 'package:flutter/material.dart';
import '../../utils/puppet_screen_mapping.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../helpers/helpers.dart';
import 'package:collection/collection.dart';

import '../../providers/auth.dart';
import '../../widgets/header.dart';
import '../../../utils/debug_logger.dart';

class EditProfileScreen extends StatefulWidget {
  static const routeName = '/edit-profile-screen';

  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with PuppetInteractionMixin {
  final _formKey = GlobalKey<FormState>();
  var _isInit = true;
  late Map<String, dynamic> _user = {};
  TextEditingController _nameController = TextEditingController();
  TextEditingController _usernameController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _contactNumberController = TextEditingController();
  TextEditingController _dobController = TextEditingController();
  String? _usernameError = null;
  late Map<String, String> initialData;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _user = Provider.of<Auth>(context, listen: false).user;
      _nameController.text =
          _user['name'] == null ? '' : _user['name'].toString();
      _usernameController.text = _user['username'].toString();
      _emailController.text = _user['email'].toString();
      _contactNumberController.text =
          _user['phone_number'] == null ? '' : _user['phone_number'].toString();
      _dobController.text = _user['dob'] == null ? '' : _user['dob'].toString();
      initialData = {
        'name': _nameController.text,
        'username': _usernameController.text,
        'email': _emailController.text,
        'phone_number': _contactNumberController.text,
        'dob': _dobController.text,
      };

      _isInit = false;
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _contactNumberController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  // Define a regular expression pattern for a phone number
  final RegExp phoneRegex = RegExp(
      r'^(\+?\d{1,3})?[-.\s]?\(?\d{1,4}\)?[-.\s]?\d{1,4}[-.\s]?\d{1,4}[-.\s]?\d{1,9}$');

  // Define a validator function for the phone number input
  String? validatePhone(String value) {
    if (value.isEmpty) {
      return 'Please enter your phone number';
    }
    if (!phoneRegex.hasMatch(value)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  Future<void> updateProfile() async {
    final Map<String, String> allData = {
      'name': _nameController.text,
      'username': _usernameController.text,
      'email': _emailController.text,
      'phone_number': _contactNumberController.text,
      'dob': _dobController.text,
    };

    DebugLogger.info('📝 EDIT PROFILE: Initial data: $initialData');
    DebugLogger.info('📝 EDIT PROFILE: New data: $allData');

    if (DeepCollectionEquality().equals(allData, initialData)) {
      DebugLogger.info('⚠️ EDIT PROFILE: No changes detected');
      return showScaffoldMessenger(context, 'Nothing to update.');
    }

    // Validating the form fields
    if (_formKey.currentState!.validate()) {
      DebugLogger.info('✅ EDIT PROFILE: Form validation passed');
      try {
        var auth = Provider.of<Auth>(context, listen: false);

        // Build update data with only changed fields
        final Map<String, String> updateData = {};

        // Always send name if it has changed or has a value
        if (initialData['name'] != _nameController.text) {
          updateData['name'] = _nameController.text;
        }

        // Only send email if it has actually changed
        if (initialData['email'] != _emailController.text) {
          updateData['email'] = _emailController.text;
        }

        // Only add username if it has changed
        if (_usernameController.text.isNotEmpty &&
            initialData['username'] != _usernameController.text) {
          updateData['username'] = _usernameController.text;
        }

        // Only add phone number if it has changed
        if (_contactNumberController.text.isNotEmpty &&
            _contactNumberController.text != 'null' &&
            initialData['phone_number'] != _contactNumberController.text) {
          updateData['phone_number'] = _contactNumberController.text;
        }

        // Only add dob if it has changed
        if (_dobController.text.isNotEmpty &&
            _dobController.text != 'null' &&
            initialData['dob'] != _dobController.text) {
          updateData['dob'] = _dobController.text;
        }

        // Check if there are any changes to send
        if (updateData.isEmpty) {
          DebugLogger.info('⚠️ EDIT PROFILE: No fields changed');
          return showScaffoldMessenger(context, 'Nothing to update.');
        }

        DebugLogger.info('📝 EDIT PROFILE: Sending to API: $updateData');

        DebugLogger.info('📝 EDIT PROFILE: Calling auth.updateUser()...');
        // Update the user profile
        await auth.updateUser(updateData);
        DebugLogger.info('✅ EDIT PROFILE: Update completed successfully');
        showScaffoldMessenger(context, 'Your info has been updated.');
        Navigator.of(context).pushReplacementNamed(UserScreen.routeName);
      } catch (error) {
        // Handling network errors or any other errors that may occur during the update process
        DebugLogger.info('❌ EDIT PROFILE ERROR: $error');

        // Check for specific error types
        String errorMessage = 'Failed to update profile.';
        final errorString = error.toString();

        if (errorString.contains('Duplicate entry') ||
            errorString.contains('UniqueConstraintViolation') ||
            errorString.contains('already exists')) {
          if (errorString.contains('username')) {
            errorMessage =
                'This username is already taken. Please choose a different username.';
          } else if (errorString.contains('email')) {
            errorMessage =
                'This email is already registered. Please use a different email.';
          } else {
            errorMessage =
                'This information is already taken. Please use different details.';
          }
        } else if (errorString.contains('Email already verified')) {
          errorMessage =
              'Backend validation error. Please contact support or try updating only name, phone number, or date of birth.';
        } else if (errorString.contains('email field is required')) {
          errorMessage =
              'Backend configuration error. Please contact support - the API requires email field to be optional.';
        }

        showScaffoldMessenger(context, errorMessage);
      }
    } else {
      // If form validation fails, prompt user to check the form fields
      DebugLogger.info('❌ EDIT PROFILE: Form validation failed');
      showScaffoldMessenger(context, 'You missed something. Please check.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context: context, titleText: 'General Information'),
      body: RefreshIndicator(
        onRefresh: () async {
          // Add refresh functionality if needed
        },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          child: Column(
            children: [
              // Profile Form Card
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).brightness == Brightness.dark
                          ? Color(0xFF2A2A2A)
                          : Colors.white,
                      Theme.of(context).brightness == Brightness.dark
                          ? Color(0xFF1E1E1E)
                          : Colors.grey.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade600
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Edit Profile Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Full Name Field
                      _buildFormField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Icons.person,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your full name';
                          }
                          return null;
                        },
                      ),

                      // Username Field (can only be set once)
                      _buildFormField(
                        controller: _usernameController,
                        label: 'Username',
                        icon: Icons.person,
                        readOnly: _user['username'] != null &&
                            _user['username'].toString().isNotEmpty,
                        errorBorder: _usernameError != null,
                        onTap: () {
                          setState(() {
                            _usernameError = null;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your username';
                          }
                          return _usernameError;
                        },
                      ),

                      // Email Field
                      _buildFormField(
                        controller: _emailController,
                        label: 'Email Address',
                        icon: Icons.email,
                        readOnly: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email address';
                          }
                          return null;
                        },
                      ),

                      // Contact Number Field
                      _buildFormField(
                        controller: _contactNumberController,
                        label: 'Contact Number',
                        icon: Icons.phone_iphone_sharp,
                        keyboardType: TextInputType.phone,
                        readOnly: false,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return null; // Optional field
                          }
                          return validatePhone(value);
                        },
                      ),

                      // Date of Birth Field
                      _buildFormField(
                        controller: _dobController,
                        label: 'Date Of Birth (DOB)',
                        icon: Icons.calendar_month_outlined,
                        readOnly: true,
                        onTap: () async {
                          DateTime today = DateTime.now();
                          DateTime fifteenYearsAgo =
                              DateTime(today.year - 15, today.month, today.day);
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: fifteenYearsAgo,
                            firstDate: DateTime(1920),
                            lastDate: fifteenYearsAgo,
                          );

                          if (pickedDate != null) {
                            String formattedDate =
                                DateFormat('yyyy-MM-dd').format(pickedDate);
                            setState(() {
                              _dobController.text = formattedDate;
                            });
                          } else {
                            throw ("Date is not selected");
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your date of birth';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 24),

                      // Submit Button
                      Container(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Processing...')),
                              );
                            }
                            showDialog<void>(
                              context: context,
                              barrierDismissible: false,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  backgroundColor:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Color(0xFF1E1E1E)
                                          : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: Text('Are you sure?'),
                                  content: SingleChildScrollView(
                                    child: ListBody(
                                      children: <Widget>[
                                        Text(
                                            'If you proceed, you will not be able to update the following details:'),
                                        SizedBox(height: 8),
                                        Text('Name: ${_nameController.text}'),
                                        Text(
                                            'Username: ${_usernameController.text}'),
                                        Text('Email: ${_emailController.text}'),
                                        Text(
                                            'Contact Number: ${_contactNumberController.text}'),
                                        Text(
                                            'Date of Birth: ${_dobController.text}'),
                                        SizedBox(height: 16),
                                        Text(
                                            'You will need to contact us to change them later.'),
                                      ],
                                    ),
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      child: Text('Cancel'),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: Text('Yes, Continue'),
                                      onPressed: () async {
                                        Navigator.of(context).pop();
                                        updateProfile();
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Update Profile',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    bool readOnly = false,
    bool errorBorder = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        validator: validator,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Container(
            margin: EdgeInsets.all(8),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.blue,
              size: 20,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.blue,
              width: 2,
            ),
          ),
          errorBorder: errorBorder
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red, width: 2),
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.05),
        ),
      ),
    );
  }
}
