import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BlockedCreatorsScreen extends StatefulWidget {
  static const routeName = '/blocked-creators-screen';

  const BlockedCreatorsScreen({Key? key}) : super(key: key);

  @override
  State<BlockedCreatorsScreen> createState() => _BlockedCreatorsScreenState();
}

class _BlockedCreatorsScreenState extends State<BlockedCreatorsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _pendingUnblocks = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBlockedUsers(forceRefresh: true);
    });
  }

  Future<void> _loadBlockedUsers({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context.read<Auth>().fetchBlockedUsers(forceRefresh: forceRefresh);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmUnblock(String username) async {
    final shouldUnblock = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Unblock tutor'),
            content: Text('Allow @$username to appear in your feeds again?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Unblock'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldUnblock || !mounted) {
      return;
    }

    setState(() {
      _pendingUnblocks.add(username);
    });

    try {
      await context.read<Auth>().unblockUser(username);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('@$username has been unblocked.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _pendingUnblocks.remove(username);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context: context, titleText: 'Blocked Tutors'),
      body: RefreshIndicator(
        onRefresh: () => _loadBlockedUsers(forceRefresh: true),
        child: Consumer<Auth>(
          builder: (context, auth, _) {
            final blockedUsers = auth.blockedUsers;

            if (_isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_errorMessage != null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.block, size: 54, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: OutlinedButton(
                      onPressed: () => _loadBlockedUsers(forceRefresh: true),
                      child: const Text('Try again'),
                    ),
                  ),
                ],
              );
            }

            if (blockedUsers.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 80),
                  Icon(Icons.verified_user_outlined,
                      size: 54, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'You have not blocked any tutors.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'If you block someone from a profile or story, they will appear here so you can unblock them later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: blockedUsers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final user = blockedUsers[index] as Map<String, dynamic>;
                final username = user['username']?.toString() ?? '';
                final displayName = user['name']?.toString().trim();
                final isPending = _pendingUnblocks.contains(username);

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.red.shade100,
                          child: Icon(Icons.block, color: Colors.red.shade600),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName != null && displayName.isNotEmpty
                                    ? displayName
                                    : '@$username',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (displayName != null &&
                                  displayName.isNotEmpty &&
                                  username.isNotEmpty)
                                Text(
                                  '@$username',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: isPending || username.isEmpty
                              ? null
                              : () => _confirmUnblock(username),
                          child: isPending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Unblock'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
