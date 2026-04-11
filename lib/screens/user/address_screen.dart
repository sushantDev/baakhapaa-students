import 'package:baakhapaa/screens/story/story_screen.dart';
import 'package:flutter/material.dart';
import '../../utils/puppet_screen_mapping.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

import '../../providers/auth.dart';
import '../../helpers/helpers.dart';
import '../../widgets/header.dart';
import '../../utils/debug_logger.dart';

class AddressScreen extends StatefulWidget {
  static const routeName = '/address-screen';
  const AddressScreen({Key? key}) : super(key: key);

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen>
    with PuppetInteractionMixin {
  final _formKey = GlobalKey<FormState>();
  var _isInit = true;
  late Map<String, dynamic> _user = {};
  TextEditingController _countryController = TextEditingController();
  TextEditingController _addressController = TextEditingController();
  TextEditingController _stateController = TextEditingController();
  TextEditingController _zipCodeController = TextEditingController();
  late Map<String, String> initialData;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _user = Provider.of<Auth>(context, listen: false).user;

      // Handle null values by setting empty strings instead of displaying "null"
      _countryController.text =
          _user['country'] == null || _user['country'] == "null"
              ? ''
              : _user['country'].toString();

      _addressController.text =
          _user['address'] == null || _user['address'] == "null"
              ? ''
              : _user['address'].toString();

      _stateController.text = _user['state'] == null || _user['state'] == "null"
          ? ''
          : _user['state'].toString();

      _zipCodeController.text =
          _user['zipcode'] == null || _user['zipcode'] == "null"
              ? ''
              : _user['zipcode'].toString();

      // Store initial data using safe values (empty string instead of "null")
      initialData = {
        'country': _countryController.text,
        'address': _addressController.text,
        'state': _stateController.text,
        'zipcode': _zipCodeController.text,
        'username': _user['username']?.toString() ?? '',
        'name': _user['name']?.toString() ?? '',
        'email': _user['email']?.toString() ?? '',
        'phone_number': _user['phone_number']?.toString() ?? '',
        'dob': _user['dob']?.toString() ?? '',
      };

      _isInit = false;
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _countryController.dispose();
    _addressController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }

  Future<void> updateProfile() async {
    final Map<String, String> data = {
      'country': _countryController.text,
      'address': _addressController.text,
      'state': _stateController.text,
      'zipcode': _zipCodeController.text,
      'username': _user['username'].toString(),
      'name': _user['name'].toString(),
      'email': _user['email'].toString(),
      'phone_number': _user['phone_number'].toString(),
      'dob': _user['dob'].toString(),
    };

    // Checking if there are any changes in the profile data
    if (DeepCollectionEquality().equals(data, initialData)) {
      return showScaffoldMessenger(context, 'Nothing to update.');
    }

    if (_formKey.currentState!.validate()) {
      try {
        var auth = Provider.of<Auth>(context, listen: false);
        await auth.updateUser(data);
        showScaffoldMessenger(context, 'Your address has been updated.');
        Navigator.of(context).pushNamed(StoryScreen.routeName);
        DebugLogger.auth('Username submitData ${data}');
      } catch (error) {
        showScaffoldMessenger(context, 'Oops! Some error occurred.');
      }
    } else {
      showScaffoldMessenger(context, 'You missed something. Please check.');
    }
  }

  Future<void> _showWarning(BuildContext context) async {
    final bool shouldSendEmail = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Are You Sure Want To Delete?'),
          content: Text(
              'All the data will be deleted with including all the your achievement and history \n\n'
              'Once deleted you will not be able to reactivate your account once its deleted \n\n'
              'We will take 2 weeks of buffering to complete process. \n\n'
              'For further information reach us in our social media @baakhapaa.app \n\n'
              'Email us : baakhapaa@gmail.com'),
          actions: <Widget>[
            InkWell(
              splashColor: Colors.black26,
              onTap: () {
                Navigator.of(context).pop(true);
                Navigator.of(context).pushNamedAndRemoveUntil(
                    '/', (Route<dynamic> route) => false);
                Provider.of<Auth>(context, listen: false).signout();
              },
              child: Text(
                'Delete Account',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 17,
                ),
              ),
            ),
            InkWell(
              splashColor: Colors.black26,
              onTap: () {
                Navigator.of(context).pop(false);
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 17,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (shouldSendEmail) {
      final Email email = Email(
        body:
            'Hi I am  ${initialData['name']},  writing this email to request the deactivation of my account with your service.'
            'I have decided to discontinue using your service and would appreciate it if you could deactivate my account as soon as possible. I understand that this action is irreversible and that all my data and information associated with the account will be permanently deleted.\n\n'
            'If there are any outstanding fees or charges associated with my account, please let me know and provide me with the necessary steps to settle them.\n\n'
            'Thank you for your assistance with this matter. I have appreciated using your service and wish you all the best in the future.\n\n'
            'Sincerely,'
            ' ${initialData['email']},',
        subject: 'Account delete request (${initialData['name']},}\n)',
        recipients: ['baakhapaa@gmail.com'],
        attachmentPaths: ['/path/to/attachment'],
        isHTML: false,
      );
      await FlutterEmailSender.send(email);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context: context, titleText: 'Address Information'),
      body: RefreshIndicator(
        onRefresh: () async {
          // Add refresh functionality if needed
        },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          child: Column(
            children: [
              // Address Form Card
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
                                  Colors.green.shade400,
                                  Colors.green.shade600
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Address Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Country Field
                      _buildFormField(
                        controller: _countryController,
                        label: 'Country',
                        hintText: 'Enter your country',
                        icon: Icons.flag_circle,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your country';
                          }
                          return null;
                        },
                      ),

                      // Address Field
                      _buildFormField(
                        controller: _addressController,
                        label: 'Address',
                        hintText: 'Enter your address',
                        icon: Icons.map,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your address';
                          }
                          return null;
                        },
                      ),

                      // State Field
                      _buildFormField(
                        controller: _stateController,
                        label: 'State',
                        hintText: 'Enter your state',
                        icon: Icons.pin_drop_outlined,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your state';
                          }
                          return null;
                        },
                      ),

                      // Zip Code Field
                      _buildFormField(
                        controller: _zipCodeController,
                        label: 'Zip Code',
                        hintText: 'Enter your zip code',
                        icon: Icons.onetwothree_outlined,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your zip code';
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
                            updateProfile();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
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
                                'Update Address',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 16),

                      // Delete Account Button
                      Container(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showWarning(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
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
                              Icon(Icons.delete_forever, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Delete Account',
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
    required String hintText,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.next,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Container(
            margin: EdgeInsets.all(8),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.green,
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
              color: Colors.green,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.05),
        ),
      ),
    );
  }
}
