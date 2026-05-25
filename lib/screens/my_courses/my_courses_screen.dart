// ignore_for_file: unused_local_variable

import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/providers/story.dart';
import 'package:baakhapaa/theme/app_colors.dart';
import 'package:baakhapaa/utils/guest_auth_helper.dart';
import 'package:baakhapaa/widgets/footer.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:baakhapaa/widgets/my_courses/my_courses_list_item.dart';
import 'package:baakhapaa/widgets/my_courses/my_courses_empty_state.dart';

class MyCourses extends StatefulWidget {
  static const String routeName = '/my-courses';

  const MyCourses({Key? key}) : super(key: key);

  @override
  State<MyCourses> createState() => _MyCoursesState();
}

class _MyCoursesState extends State<MyCourses> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _floatingActionController;
  var _isInit = true;
  bool _hasCheckedGuestAccess = false;

  @override
  void initState() {
    super.initState();
    _floatingActionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _isInit = false;
      final storyProvider = Provider.of<Story>(context, listen: false);
      _floatingActionController.forward();
      // Load continue watching data
      storyProvider.fetchContinueWatching();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkGuestAccess();
      });
    }
    super.didChangeDependencies();
  }

  Future<void> _checkGuestAccess() async {
    if (_hasCheckedGuestAccess) return;
    _hasCheckedGuestAccess = true;

    final auth = Provider.of<Auth>(context, listen: false);
    final isUnauthenticated = auth.isGuest ||
        !auth.isAuth ||
        (auth.user.isEmpty && !auth.isLoadingUser);
    if (isUnauthenticated) {
      final didLogin = await GuestAuthHelper.showGuestLoginDialog(
        context,
        'my courses',
      );
      if (!didLogin && mounted) {
        Navigator.of(context).pushReplacementNamed('/story-screen');
      }
    }
  }

  @override
  void dispose() {
    _floatingActionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppColors.getBackground(context);
    final primaryColor = AppColors.getPrimary(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      appBar: header(
        context: context,
        titleText: 'My Courses',
        scaffoldKey: _scaffoldKey,
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Consumer<Story>(
          builder: (context, storyProvider, _) {
            final continueWatching = storyProvider.continueWatchingItems;
            final footerHeight = Footer.estimatedHeight(context);
            final bottomPadding =
                MediaQuery.of(context).viewPadding.bottom + footerHeight + 40;

            if (continueWatching.isEmpty) {
              return Padding(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: const MyCourseEmptyState(),
              );
            }

            return CustomRefreshIndicator(
              onRefresh: () async {
                await storyProvider.fetchContinueWatching();
              },
              builder: (context, child, controller) {
                return Stack(
                  children: [
                    child,
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.topCenter,
                          heightFactor: controller.value,
                          child: SizedBox(
                            height: 80,
                            child: Material(
                              color: primaryColor.withValues(alpha: 0.1),
                              child: Center(
                                child: Transform.rotate(
                                  angle: controller.value * 6.28,
                                  child: Icon(
                                    Icons.refresh_rounded,
                                    color: primaryColor,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  12,
                  16,
                  12,
                  bottomPadding,
                ),
                itemCount: continueWatching.length,
                itemBuilder: (context, index) {
                  final course = continueWatching[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MyCourseListItem(
                      course: course,
                      index: index,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
