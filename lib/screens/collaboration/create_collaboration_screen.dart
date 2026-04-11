import 'package:baakhapaa/widgets/header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/collaboration_provider.dart';
import '../../helpers/helpers.dart';
import '../../widgets/collaborator_selector.dart';
import 'collaborations_screen.dart';

/// Create Collaboration Screen (Invitation-First Flow)
/// Allows users to create collaboration invitations before creating content
///
/// Workflow:
/// 1. User fills title, description, selects content type
/// 2. User selects collaborators with individual offers
/// 3. Send invitations to all collaborators
/// 4. All collaborators accept → Status becomes "active"
/// 5. Any collaborator can then create content with collaboration_id
class CreateCollaborationScreen extends StatefulWidget {
  static const routeName = '/create-collaboration';

  @override
  _CreateCollaborationScreenState createState() =>
      _CreateCollaborationScreenState();
}

class _CreateCollaborationScreenState extends State<CreateCollaborationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedContentType = 'short';
  List<Map<String, dynamic>> _selectedCollaborators = [];
  int _expiresInHours = 48;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectCollaborators() async {
    HapticFeedback.lightImpact();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CollaboratorSelector(
          initialSelected: _selectedCollaborators,
          onSelected: (selected) {
            setState(() {
              _selectedCollaborators = selected;
            });
            // Don't pop here - CollaboratorSelector handles its own navigation
          },
        ),
      ),
    );
  }

  Future<void> _createCollaboration() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCollaborators.isEmpty) {
      showTopSnackBar(context, 'Please select at least one collaborator');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    try {
      final provider =
          Provider.of<CollaborationProvider>(context, listen: false);

      final collaboration = await provider.createCollaboration(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        contentType: _selectedContentType,
        collaborators: _selectedCollaborators,
        expiresInHours: _expiresInHours,
      );

      if (collaboration != null) {
        showTopSnackBar(
          context,
          'Collaboration invitations sent!',
          backgroundColor: Colors.green,
        );

        // Navigate back to collaborations screen
        Navigator.of(context).pushReplacementNamed(
          CollaborationsScreen.routeName,
        );
      } else {
        throw 'Failed to create collaboration';
      }
    } catch (error) {
      showTopSnackBar(
        context,
        'Failed to create collaboration: ${error.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _removeCollaborator(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedCollaborators.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: header(
        context: context,
        titleText: "Create Collaboration",
      ),
      body: _isSubmitting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Sending invitations...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeaderSection(isDark),
                    SizedBox(height: 24),

                    // Title Input
                    _buildSectionTitle('Collaboration Title'),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Epic Gaming Montage',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        if (value.trim().length < 3) {
                          return 'Title must be at least 3 characters';
                        }
                        return null;
                      },
                      maxLength: 100,
                    ),
                    SizedBox(height: 16),

                    // Description Input
                    _buildSectionTitle('Description'),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        hintText:
                            'Describe what you want to create together...',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                      ),
                      maxLines: 4,
                      maxLength: 500,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Content Type Selector
                    _buildSectionTitle('Content Type'),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: Row(
                                children: [
                                  Icon(Icons.video_library, size: 20),
                                  SizedBox(width: 8),
                                  Text('Short'),
                                ],
                              ),
                              value: 'short',
                              groupValue: _selectedContentType,
                              onChanged: (value) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedContentType = value!;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: Row(
                                children: [
                                  Icon(Icons.movie, size: 20),
                                  SizedBox(width: 8),
                                  Text('Season'),
                                ],
                              ),
                              value: 'season',
                              groupValue: _selectedContentType,
                              onChanged: (value) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedContentType = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Expiration Selector
                    _buildSectionTitle('Invitation Expires In'),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: DropdownButtonFormField<int>(
                        value: _expiresInHours,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.timer),
                        ),
                        items: [
                          DropdownMenuItem(value: 24, child: Text('24 hours')),
                          DropdownMenuItem(value: 48, child: Text('48 hours')),
                          DropdownMenuItem(value: 72, child: Text('3 days')),
                          DropdownMenuItem(value: 168, child: Text('1 week')),
                        ],
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _expiresInHours = value!;
                          });
                        },
                      ),
                    ),
                    SizedBox(height: 24),

                    // Collaborators Section
                    _buildSectionTitle('Collaborators'),
                    SizedBox(height: 8),
                    _buildCollaboratorsSection(isDark),
                    SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _createCollaboration,
                        icon: Icon(Icons.send),
                        label: Text(
                          'Send Invitations (${_selectedCollaborators.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderSection(bool isDark) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple, Colors.deepPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.people,
            size: 48,
            color: Colors.white,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite & Collaborate',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Send invitations, wait for acceptance, then create content together',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildCollaboratorsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add Collaborators Button
        OutlinedButton.icon(
          onPressed: _selectCollaborators,
          icon: Icon(Icons.person_add),
          label: Text('Add Collaborators'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.purple,
            side: BorderSide(color: Colors.purple),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),

        if (_selectedCollaborators.isEmpty) ...[
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Select at least one collaborator to send invitations',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Selected Collaborators List
        if (_selectedCollaborators.isNotEmpty) ...[
          SizedBox(height: 16),
          Text(
            'Selected (${_selectedCollaborators.length})',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          ..._selectedCollaborators.asMap().entries.map((entry) {
            final index = entry.key;
            final collaborator = entry.value;
            return _buildCollaboratorChip(collaborator, index, isDark);
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildCollaboratorChip(
    Map<String, dynamic> collaborator,
    int index,
    bool isDark,
  ) {
    final username = collaborator['username'] ?? 'Unknown';
    final offerType = collaborator['offer_type'] ?? 'none';
    final amount = collaborator[
        'offer_amount']; // Fixed: was 'amount', should be 'offer_amount'

    String offerLabel = '';
    Color offerColor = Colors.grey;

    if (offerType == 'points' && amount != null) {
      offerLabel = '$amount pts';
      offerColor = Colors.amber;
    } else if (offerType == 'gift') {
      offerLabel = 'Gift';
      offerColor = Colors.pink;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.purple.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // Avatar placeholder
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.purple,
            child: Text(
              username[0].toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 12),

          // Username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@$username',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (offerType != 'none') ...[
                  SizedBox(height: 4),
                  Row(
                    children: [
                      if (offerType == 'points')
                        Image.asset(
                          'assets/images/coins.png',
                          width: 14,
                          height: 14,
                        )
                      else
                        Icon(
                          Icons.card_giftcard,
                          size: 14,
                          color: offerColor,
                        ),
                      SizedBox(width: 4),
                      Text(
                        offerLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: offerColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Remove button
          IconButton(
            onPressed: () => _removeCollaborator(index),
            icon: Icon(Icons.close),
            iconSize: 20,
            color: Colors.red,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
