import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/story.dart';
import '../../providers/auth.dart';
import '../../utils/guest_auth_helper.dart';

class BookRequestsScreen extends StatefulWidget {
  static const routeName = '/book-requests';

  const BookRequestsScreen({Key? key}) : super(key: key);

  @override
  State<BookRequestsScreen> createState() => _BookRequestsScreenState();
}

class _BookRequestsScreenState extends State<BookRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    final story = Provider.of<Story>(context, listen: false);
    await story.fetchBookRequests();
    if (mounted) setState(() => _isLoading = false);
  }

  void _showRequestForm() {
    final auth = Provider.of<Auth>(context, listen: false);
    if (auth.isGuest) {
      GuestAuthHelper.showGuestLoginDialog(context, 'request books');
      return;
    }

    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final reasonController = TextEditingController();
    String? selectedGenre;

    final genres = [
      'Self-Help',
      'Business',
      'Psychology',
      'Finance',
      'Science',
      'Philosophy',
      'Productivity',
      'Health',
      'Relationships',
      'History',
      'Creativity',
      'Spirituality',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Request a Book 📚',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Book Title *'),
              ),
              const SizedBox(height: 12),

              // Author
              TextField(
                controller: authorController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Author (optional)'),
              ),
              const SizedBox(height: 12),

              // Genre dropdown
              StatefulBuilder(
                builder: (context, setModalState) {
                  return DropdownButtonFormField<String>(
                    value: selectedGenre,
                    dropdownColor: const Color(0xFF16213E),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Genre (optional)'),
                    items: genres
                        .map((g) => DropdownMenuItem(
                              value: g,
                              child: Text(g),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setModalState(() => selectedGenre = val);
                    },
                  );
                },
              ),
              const SizedBox(height: 12),

              // Reason
              TextField(
                controller: reasonController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration:
                    _inputDecoration('Why do you want this book? (optional)'),
              ),
              const SizedBox(height: 20),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;
                    final story = Provider.of<Story>(ctx, listen: false);
                    final success = await story.submitBookRequest(
                      title: titleController.text.trim(),
                      author: authorController.text.trim().isEmpty
                          ? null
                          : authorController.text.trim(),
                      genre: selectedGenre,
                      reason: reasonController.text.trim().isEmpty
                          ? null
                          : reasonController.text.trim(),
                    );
                    Navigator.of(ctx).pop();
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Book request submitted! 📚')),
                      );
                      _loadRequests();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Submit Request',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.amber),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: Text(
          'Book Requests',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Browse'),
            Tab(text: 'My Requests'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRequestForm,
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: Text(
          'Request Book',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBrowseTab(),
                _buildMyRequestsTab(),
              ],
            ),
    );
  }

  Widget _buildBrowseTab() {
    return Consumer<Story>(
      builder: (ctx, story, _) {
        final requests = story.bookRequests;
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('📚', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  'No book requests yet',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to request a book!',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadRequests,
          color: Colors.amber,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (ctx, index) {
              final req = requests[index];
              return _buildRequestCard(req, showUpvote: true);
            },
          ),
        );
      },
    );
  }

  Widget _buildMyRequestsTab() {
    return Consumer<Story>(
      builder: (ctx, story, _) {
        final auth = Provider.of<Auth>(context, listen: false);
        final userId = auth.userId;
        final myRequests = story.bookRequests
            .where((r) => r['user']?['id']?.toString() == userId.toString())
            .toList();

        if (myRequests.isEmpty) {
          return Center(
            child: Text(
              'You haven\'t requested any books yet',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: myRequests.length,
          itemBuilder: (ctx, index) {
            return _buildRequestCard(myRequests[index], showUpvote: false);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(dynamic req, {required bool showUpvote}) {
    final statusColor = {
          'pending': Colors.orange,
          'approved': Colors.blue,
          'rejected': Colors.red,
          'generated': Colors.green,
        }[req['status']] ??
        Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  req['title'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  (req['status'] ?? 'pending').toString().toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (req['author'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'by ${req['author']}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white54,
              ),
            ),
          ],
          if (req['reason'] != null && req['reason'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              req['reason'],
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white38,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'by @${req['user']?['username'] ?? 'unknown'}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white30,
                ),
              ),
              const Spacer(),
              if (showUpvote)
                GestureDetector(
                  onTap: () {
                    final story = Provider.of<Story>(context, listen: false);
                    story.upvoteBookRequest(req['id']);
                  },
                  child: Row(
                    children: [
                      Icon(
                        req['has_upvoted'] == true
                            ? Icons.thumb_up
                            : Icons.thumb_up_outlined,
                        size: 18,
                        color: req['has_upvoted'] == true
                            ? Colors.amber
                            : Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${req['upvotes'] ?? 0}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
