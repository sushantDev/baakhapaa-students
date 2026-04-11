import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/affiliate.dart';
import '../../providers/auth.dart';
import '../../utils/debug_logger.dart';
import '../others/creator_request_screen.dart';

class AffiliateDashboardScreen extends StatefulWidget {
  static const routeName = '/affiliate-dashboard';

  const AffiliateDashboardScreen({super.key});

  @override
  State<AffiliateDashboardScreen> createState() =>
      _AffiliateDashboardScreenState();
}

class _AffiliateDashboardScreenState extends State<AffiliateDashboardScreen> {
  bool _isLoading = false;
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _fetchAffiliateStatus();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  Future<void> _fetchAffiliateStatus() async {
    setState(() => _isLoading = true);
    try {
      // Fetch user data from /api/v2/user which contains affiliate status
      await Provider.of<Auth>(context, listen: false).getUser();
      // Also potentially fetch product data from AffiliateProvider if needed
      await Provider.of<AffiliateProvider>(context, listen: false)
          .fetchAffiliateStatus();
    } catch (e) {
      DebugLogger.error('Error fetching affiliate status: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinProgram() async {
    setState(() => _isLoading = true);
    try {
      await Provider.of<AffiliateProvider>(context, listen: false)
          .joinAffiliateProgram();

      // Refresh status to update UI and Auth provider state
      await _fetchAffiliateStatus();

      if (mounted) {
        String message = 'Application submitted successfully!';
        // Check if we just transitioned to pending
        final auth = Provider.of<Auth>(context, listen: false);
        if (auth.affiliateProgramStatus == 'pending') {
          message = 'Your application is now pending review.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(' $e'), backgroundColor: Colors.green),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final affiliateProvider = Provider.of<AffiliateProvider>(context);
    final authProvider = Provider.of<Auth>(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Affiliate Program',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAffiliateStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: _buildBody(affiliateProvider, authProvider),
            ),
    );
  }

  Widget _buildBody(AffiliateProvider affiliate, Auth auth) {
    // Prioritize Auth provider status as it comes from /api/v2/user
    if (auth.isAffiliate) {
      return _buildApprovedView();
    }

    final status = auth.affiliateProgramStatus;

    if (status == 'pending') {
      return _buildPendingView();
    }

    if (status == 'rejected') {
      return _buildRejectedView(auth);
    }

    // Default "Not Applied" state
    return auth.role != 'creator'
        ? _buildNonCreatorView()
        : _buildJoinProgramView();
  }

  Widget _buildNonCreatorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.handshake_rounded,
                  size: 64, color: Colors.amber.shade700),
            ),
            const SizedBox(height: 32),
            Text(
              'Creators Only',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Join our affiliate program to start earning commissions by promoting products you love!',
              style: TextStyle(
                  fontSize: 15, color: Colors.grey.shade600, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed(CreatorRequestScreen.routeName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('Become a Creator',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinProgramView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.rocket_launch_rounded,
                  size: 64, color: Colors.amber.shade700),
            ),
            const SizedBox(height: 32),
            Text(
              'Ready to Get Started?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Join our affiliate program to start earning commissions by promoting products you love!',
              style: TextStyle(
                  fontSize: 15, color: Colors.grey.shade600, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _joinProgram,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.handshake_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('Join Affiliate Program',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.verified_rounded,
                  size: 64, color: Colors.green.shade600),
            ),
            const SizedBox(height: 32),
            Text(
              'Congratulations! You\'re an Affiliate!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'You\'re now part of our affiliate program. Start earning commissions by promoting products you love!',
              style: TextStyle(
                  fontSize: 15, color: Colors.grey.shade600, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb_outline,
                      size: 18, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Text(
                    'Sell products to earn commissions!',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hourglass_empty_rounded,
                  size: 64, color: Colors.orange.shade600),
            ),
            const SizedBox(height: 32),
            Text(
              'Application Pending',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Please wait 24-48 hours while our team verifies your profile.',
              style: TextStyle(
                  fontSize: 15, color: Colors.grey.shade600, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedView(Auth auth) {
    final remarks = auth.affiliateRemarks;
    final cooldown = auth.affiliateCooldown;
    final remainingDays = cooldown?['cooldown_days'] ?? 0;
    final nextApplyDateStr = cooldown?['can_reapply_at'];
    bool canReapply = cooldown?['can_reapply'] ?? false;

    DateTime? nextApplyDate;
    if (nextApplyDateStr != null) {
      nextApplyDate = DateTime.tryParse(nextApplyDateStr.toString());

      // Local fallback: if date has passed but can_reapply is still false
      if (!canReapply &&
          nextApplyDate != null &&
          DateTime.now().isAfter(nextApplyDate)) {
        canReapply = true;
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cancel_rounded,
                  size: 64, color: Colors.red.shade600),
            ),
            const SizedBox(height: 32),
            Text(
              'Application Not Approved',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
              textAlign: TextAlign.center,
            ),
            if (remarks != null && remarks.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade200, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Feedback',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      remarks,
                      style:
                          TextStyle(color: Colors.grey.shade800, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (remainingDays > 0 && !canReapply) ...[
              Text(
                'You can reapply in $remainingDays ${remainingDays == 1 ? 'day' : 'days'}',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              if (nextApplyDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Available: ${DateFormat.yMMMd().format(nextApplyDate)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ),
            ] else if (canReapply) ...[
              Text(
                'The cooldown period has ended. You can now reapply.',
                style: TextStyle(
                    fontSize: 15,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: canReapply ? _joinProgram : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canReapply ? Colors.amber.shade600 : Colors.grey.shade300,
                foregroundColor:
                    canReapply ? Colors.white : Colors.grey.shade600,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
              ),
              child: Text(
                canReapply ? 'Reapply Now' : 'Check Back Later',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
