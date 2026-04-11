import 'dart:convert';
import 'dart:io';

import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/screens/user/address_screen.dart';
import 'package:baakhapaa/screens/user/user_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../utils/puppet_screen_mapping.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:page_transition/page_transition.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/auth.dart';
import 'package:provider/provider.dart';
import '../../widgets/header.dart';
import '../auth/forgot_password_screen.dart';
import 'edit_profile_screen.dart';

class UserDetailsScreen extends StatefulWidget {
  static const routeName = '/user-details-screen';

  const UserDetailsScreen({Key? key}) : super(key: key);

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen>
    with PuppetInteractionMixin {
  var _isInit = true;
  late Map<String, dynamic> _user = {};

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _user = Provider.of<Auth>(context, listen: false).user;
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  String get userImageUrl {
    final images = json.encode(_user['images']);
    final decodedImage = json.decode(images).length;
    String imageUrl;
    if (decodedImage == 0) {
      imageUrl =
          'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg';
    } else {
      imageUrl = json.decode(images)[0]['thumbnail'];
    }
    return imageUrl;
  }

  void _pickImage(ImageSource source) async {
    WidgetsFlutterBinding.ensureInitialized();
    // Request gallery permission
    final status = await Permission.camera.status;
    if (status.isGranted) {
      // Permission granted, pick image
      try {
        final image = await ImagePicker().pickImage(source: source);
        if (image == null) return;
        File img = File(image.path);
        Provider.of<Auth>(context, listen: false)
            .updateUserImage(img)
            .then((_) {
          Navigator.of(context).pushNamed(UserScreen.routeName);
        });
      } on PlatformException catch (e) {
        Navigator.of(context).pop();
        throw ('Error $e');
      }
    } else if (status.isDenied) {
      WidgetsFlutterBinding.ensureInitialized();
      try {
        var permissionStatus = await Permission.camera.request();
        // Check the return value of the `request()` method.
        if (permissionStatus.isGranted) {
          // Permission granted.
        } else if (permissionStatus.isDenied) {
          // Permission denied.
        } else if (permissionStatus.isPermanentlyDenied) {
          // Permission permanently denied.
          showCameraPermissionAlert(context);
        }
      } on PlatformException catch (e) {
        throw (e);
      }
    }
  }

  void showCameraPermissionAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permission Required'),
          content: Text(
              'Your app needs permission to access the camera in order to take photos. To grant permission, go to Settings > Privacy > Camera and enable permission for your app.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Helper function to safely display user data
  String getUserDataSafe(String key, {String emptyText = 'Empty'}) {
    if (_user[key] == null ||
        _user[key] == 'null' ||
        _user[key].toString().isEmpty) {
      return emptyText;
    }
    return _user[key].toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(
          context: context,
          titleText: '${context.l10n.users} ${context.l10n.details}'),
      body: RefreshIndicator(
        onRefresh: () async {
          // Add refresh functionality if needed
        },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          child: Column(
            children: [
              // Profile Header Card
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
                child: Column(
                  children: [
                    // Profile Picture with Upload Button
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.amber, Colors.orange],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(3),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: userImageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  CircularProgressIndicator(),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.amber.withValues(alpha: 0.1),
                                child: Icon(Icons.person,
                                    size: 40, color: Colors.amber),
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _pickImage(ImageSource.gallery),
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Color(0xFF2A2A2A)
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // User Name
                    Text(
                      getUserDataSafe('name', emptyText: 'Not provided'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),

                    // Email
                    Text(
                      getUserDataSafe('email', emptyText: 'Not provided'),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),

                    // Rank
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade300,
                            Colors.green.shade600
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_circle_up_outlined,
                              color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Rank: ${getUserDataSafe('rank', emptyText: '0')}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // General Information Card
              _buildInfoCard(
                title: context.l10n.generalInformation,
                icon: Icons.person,
                color: Colors.blue,
                items: [
                  _InfoItem(Icons.person, context.l10n.fullName,
                      getUserDataSafe('name', emptyText: 'Not provided')),
                  _InfoItem(Icons.email, context.l10n.email,
                      getUserDataSafe('email', emptyText: 'Not provided')),
                  _InfoItem(Icons.account_circle, context.l10n.username,
                      getUserDataSafe('username', emptyText: 'Not provided')),
                  _InfoItem(
                      Icons.phone,
                      context.l10n.contact,
                      getUserDataSafe('phone_number',
                          emptyText: 'Not provided')),
                  _InfoItem(Icons.cake, context.l10n.dateOfBirth,
                      getUserDataSafe('dob', emptyText: 'Not provided')),
                ],
                onTap: () {
                  if (_user['phone_number'] != null &&
                      _user['phone_number'] != 'null' &&
                      _user['phone_number'].toString().isNotEmpty) {
                    showDialog<void>(
                      context: context,
                      barrierDismissible: true,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Color(0xFF1E1E1E)
                                  : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Information'),
                            ],
                          ),
                          content: SingleChildScrollView(
                            child: ListBody(
                              children: <Widget>[
                                Text(
                                    'You have already updated your general information.'),
                                SizedBox(height: 8),
                                Text('Please contact us for further updates.'),
                              ],
                            ),
                          ),
                          actions: <Widget>[
                            TextButton(
                              child: Text('OK'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        );
                      },
                    );
                  } else {
                    Navigator.push(
                      context,
                      PageTransition(
                        child: EditProfileScreen(),
                        type: PageTransitionType.rightToLeft,
                      ),
                    );
                  }
                },
              ),

              // Bio Card
              _buildInfoCard(
                title: "Bio",
                icon: Icons.description,
                color: Colors.purple,
                items: [
                  _InfoItem(
                    Icons.info_outline,
                    "Short Bio",
                    getUserDataSafe('bio',
                        emptyText: 'Tell us about yourself...'),
                  ),
                ],
                onTap: () {
                  final auth = Provider.of<Auth>(context, listen: false);
                  final currentValue = getUserDataSafe('bio', emptyText: '');
                  final TextEditingController _bioController =
                      TextEditingController(text: currentValue);

                  showDialog<void>(
                    context: context,
                    barrierDismissible: true,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Row(
                          children: const [
                            Icon(Icons.description, color: Colors.purple),
                            SizedBox(width: 8),
                            Text('Edit Bio'),
                          ],
                        ),
                        content: TextField(
                          controller: _bioController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: "Write something about yourself",
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          ElevatedButton(
                            child: const Text('Save'),
                            onPressed: () async {
                              final newBio = _bioController.text.trim();

                              try {
                                await auth.updateUser({
                                  'bio': newBio,
                                });

                                Navigator.of(context).pop();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Bio updated successfully.')),
                                );

                                setState(() {
                                  _user['bio'] = newBio;
                                });
                              } catch (error) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Failed to update bio.')),
                                );
                              }
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

// Interaction Points Fee Card
              if (_user['role'] == 'creator')
                _buildInfoCard(
                  title: "Interaction Fee",
                  icon: Icons.monetization_on,
                  color: Colors.green,
                  items: [
                    _InfoItem(
                      Icons.money,
                      "Points Fee",
                      getUserDataSafe('interaction_points_fee', emptyText: '0'),
                    ),
                  ],
                  onTap: () {
                    final auth = Provider.of<Auth>(context, listen: false);
                    final currentValue = getUserDataSafe(
                        'interaction_points_fee',
                        emptyText: '0');
                    final TextEditingController _feeController =
                        TextEditingController(text: currentValue);

                    showDialog<void>(
                      context: context,
                      barrierDismissible: true,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF1E1E1E)
                                  : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Row(
                            children: const [
                              Icon(Icons.monetization_on, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Edit Fee'),
                            ],
                          ),
                          content: TextField(
                            controller: _feeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Enter fee in points",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('Cancel'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            ElevatedButton(
                              child: const Text('Save'),
                              onPressed: () async {
                                final newFee = _feeController.text.trim();

                                if (newFee.isEmpty ||
                                    int.tryParse(newFee) == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Please enter a valid number.')),
                                  );
                                  return;
                                }

                                try {
                                  await auth.updateUser({
                                    'interaction_points_fee': newFee,
                                  });

                                  Navigator.of(context).pop();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Interaction fee updated to $newFee points.')),
                                  );

                                  setState(() {
                                    _user['interaction_points_fee'] = newFee;
                                  });
                                } catch (error) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Failed to update interaction fee.')),
                                  );
                                }
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),

              // Address Information Card
              _buildInfoCard(
                title: context.l10n.addressInformation,
                icon: Icons.location_on,
                color: Colors.green,
                items: [
                  _InfoItem(Icons.public, context.l10n.country,
                      getUserDataSafe('country', emptyText: 'Not specified')),
                  _InfoItem(Icons.location_city, context.l10n.state,
                      getUserDataSafe('state', emptyText: 'Not specified')),
                  _InfoItem(Icons.home, context.l10n.address,
                      getUserDataSafe('address', emptyText: 'Not specified')),
                  _InfoItem(Icons.mail, context.l10n.postalCode,
                      getUserDataSafe('zipcode', emptyText: 'Not specified')),
                ],
                onTap: () {
                  Navigator.push(
                    context,
                    PageTransition(
                      child: AddressScreen(),
                      type: PageTransitionType.rightToLeft,
                    ),
                  );
                },
              ),

              // Security Card
              _buildInfoCard(
                title: context.l10n.security,
                icon: Icons.security,
                color: Colors.orange,
                items: [
                  _InfoItem(Icons.lock, context.l10n.changePassword, '*********'
                      // 'Update your account security'
                      ),
                ],
                onTap: () {
                  Navigator.push(
                    context,
                    PageTransition(
                      child: ForgotPasswordScreen(),
                      type: PageTransitionType.rightToLeft,
                    ),
                  );
                },
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<_InfoItem> items,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF2A2A2A)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
              SizedBox(height: 16),

              // Items
              ...items
                  .map((item) => Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              size: 20,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item.value,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;

  _InfoItem(this.icon, this.label, this.value);
}
