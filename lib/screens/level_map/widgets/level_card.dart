import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'level_models.dart';
import 'package:baakhapaa/models/subscription.dart';

class LevelCard extends StatefulWidget {
  final LevelData level;
  final UserBenefitUsage? unlockAchievementBenefit;
  final bool isUnlockingAchievement;
  final Function(int) onUnlockAchievement;

  const LevelCard({
    Key? key,
    required this.level,
    this.unlockAchievementBenefit,
    this.isUnlockingAchievement = false,
    required this.onUnlockAchievement,
  }) : super(key: key);

  @override
  State<LevelCard> createState() => _LevelCardState();
}

class _LevelCardState extends State<LevelCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.level.isCompleted && !_isExpanded) {
      return _buildCompletedCard(context);
    }

    final bool isCurrent = widget.level.isCurrent;
    final bool isLocked = !widget.level.isCompleted && !isCurrent;
    final List<RequirementData> visualReqs =
        widget.level.requirements.where((r) => r.imageUrl != null).toList();
    final List<RequirementData> standardReqs =
        widget.level.requirements.where((r) => r.imageUrl == null).toList();

    final int completedTasks =
        widget.level.requirements.where((r) => r.isCompleted).length;
    final int totalTasks = widget.level.requirements.length;
    final double progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    return GestureDetector(
      onTap: () {
        if (widget.level.isCompleted) {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1611),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: widget.level.isCompleted
                  ? const Color(0xFFD4A056).withOpacity(0.3)
                  : const Color.fromARGB(255, 113, 113, 113),
              width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(10.0),
              margin: const EdgeInsets.all(5.0),
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color.fromARGB(58, 255, 255, 255), width: 2),
              ),
              child: Row(
                children: [
                  // Level Image
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color.fromARGB(59, 247, 247, 247),
                          width: 1),
                      image: widget.level.imageUrl != null
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(
                                  widget.level.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: widget.level.imageUrl == null
                        ? const Center(
                            child: Icon(Icons.stars,
                                color: Colors.amber, size: 32))
                        : null,
                  ),
                  const SizedBox(width: 16),
                  // Level Info and Progress
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LEVEL ${widget.level.number}'.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        // if (widget.level.subtitle.isNotEmpty) ...[
                        //   const SizedBox(height: 4),
                        //   Text(
                        //     widget.level.subtitle,
                        //     style: const TextStyle(
                        //       color: Colors.white60,
                        //       fontSize: 11,
                        //       fontStyle: FontStyle.italic,
                        //     ),
                        //     maxLines: 2,
                        //     overflow: TextOverflow.ellipsis,
                        //   ),
                        // ],
                        if (!isLocked) ...[
                          const SizedBox(height: 4),
                          Text(
                            '$completedTasks / $totalTasks tasks complete',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Progress Bar
                          Stack(
                            children: [
                              Container(
                                height: 12,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3D2F26),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              if (progress > 0)
                                FractionallySizedBox(
                                  widthFactor: progress,
                                  child: Container(
                                    height: 18,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFD4A056),
                                          Color(0xFFF7E2A9),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFD4A056)
                                              .withOpacity(0.5),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color.fromARGB(58, 255, 255, 255), width: 2),
              ),
              child: Column(
                children: [
                  // Featured Task Section
                  if (visualReqs.isNotEmpty) ...[
                    _buildSectionDivider('FEATURED TASK'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 104, // Height of card + padding
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        clipBehavior: Clip.hardEdge,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: visualReqs.map((req) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () =>
                                    _showTasksPopup(context, widget.level),
                                child: Container(
                                  width:
                                      240, // Fixed width for scrollable cards
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: const Color.fromARGB(
                                            102, 255, 209, 72),
                                        width: 3),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: CachedNetworkImage(
                                          imageUrl: req.imageUrl!,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              req.text,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              widget.level.isCompleted
                                                  ? 'Task completed.'
                                                  : 'Progress this task to level up.',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.5),
                                                fontSize: 10,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],

                  // Task List Section
                  if (standardReqs.isNotEmpty) ...[
                    _buildSectionDivider('TASK LIST'),
                    Container(
                      // padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: standardReqs.map((req) {
                          return _buildRequirementRow(context, req, isCurrent);
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
            // Footer Status
            const SizedBox(height: 16),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  widget.level.isCompleted
                      ? 'Completed'
                      : (isCurrent
                          ? 'Complete the tasks to reach to next level'
                          : 'Locked'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1611),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
              color: const Color.fromARGB(255, 230, 176, 100).withOpacity(0.6),
              width: 5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1611),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFFD4A056).withOpacity(0.3), width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            // mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Checkmark
              // const Icon(
              //   fontWeight: FontWeight.bold,
              //   Icons.check_rounded,
              //   color: Color.fromARGB(255, 230, 176, 100),
              //   size: 32,
              // ),
              // Level Text
              const SizedBox(width: 10),
              Expanded(
                child: Center(
                  child: Text(
                    'LEVEL ${widget.level.number}'.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              // Reward Points or Expand indicator
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C241E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10, width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white10, width: 1),
                          ),
                          child: ClipOval(
                            child: widget.level.imageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: widget.level.imageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Image.asset(
                                        'assets/images/coins.png',
                                        fit: BoxFit.contain),
                                    errorWidget: (context, url, error) =>
                                        Image.asset('assets/images/coins.png',
                                            fit: BoxFit.contain),
                                  )
                                : Image.asset('assets/images/coins.png',
                                    fit: BoxFit.contain),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.level.requirements.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const Expanded(
              child: Divider(color: Colors.white10, indent: 16, endIndent: 8)),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const Expanded(
              child: Divider(color: Colors.white10, indent: 8, endIndent: 16)),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(
      BuildContext context, RequirementData req, bool isCurrent) {
    final bool reqCompleted = req.isCompleted;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reqCompleted
              ? const Color(0xFFD4A056).withOpacity(0.3)
              : Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: reqCompleted ? const Color(0xFFD4A056) : Colors.white24,
                width: 2,
              ),
              color: reqCompleted
                  ? const Color(0xFFD4A056).withOpacity(0.2)
                  : Colors.transparent,
            ),
            child: reqCompleted
                ? const Icon(Icons.check, size: 14, color: Color(0xFFD4A056))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  req.text,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (req.currentProgress != null &&
                    req.requiredValue != null &&
                    !reqCompleted) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${req.currentProgress} / ${req.requiredValue}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTasksPopup(BuildContext context, LevelData level) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF120903),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: Colors.white12, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC83E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Level ${level.number}',
                    style: const TextStyle(
                      color: Color(0xFF2C1A0D),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Level Requirements',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: level.requirements.length,
                itemBuilder: (context, index) {
                  final req = level.requirements[index];
                  final bool reqCompleted = req.isCompleted;

                  final benefit = widget.unlockAchievementBenefit;
                  final hasAchievementBenefit = benefit != null &&
                      (benefit.canUse || benefit.usage.isUnlimited);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: reqCompleted
                            ? const Color(0xFF4CAF50).withOpacity(0.3)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (req.imageUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: req.imageUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 56,
                            height: 56,
                            margin: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              reqCompleted ? Icons.check : Icons.list,
                              color: reqCompleted
                                  ? const Color(0xFF4CAF50)
                                  : Colors.white30,
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (req.currentProgress != null &&
                                  req.requiredValue != null) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (req.currentProgress ?? 0) /
                                        (req.requiredValue ?? 1),
                                    backgroundColor: Colors.white10,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      reqCompleted
                                          ? const Color(0xFF4CAF50)
                                          : const Color(0xFFFFC83E),
                                    ),
                                    minHeight: 4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Progress: ${req.currentProgress} / ${req.requiredValue}',
                                  style: TextStyle(
                                    color: reqCompleted
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFFFC83E),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!reqCompleted &&
                            req.achievementId != null &&
                            hasAchievementBenefit)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Tooltip(
                              message: 'Unlock with Benefit',
                              child: InkWell(
                                onTap: widget.isUnlockingAchievement == true
                                    ? null
                                    : () {
                                        Navigator.of(context)
                                            .pop(); // Close popup first
                                        widget.onUnlockAchievement(
                                            req.achievementId!);
                                      },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.amber.withOpacity(0.5)),
                                  ),
                                  child: const Icon(Icons.bolt,
                                      color: Colors.amber, size: 20),
                                ),
                              ),
                            ),
                          ),
                        if (reqCompleted)
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Icon(
                              Icons.check_circle,
                              color: Color(0xFF4CAF50),
                              size: 24,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
