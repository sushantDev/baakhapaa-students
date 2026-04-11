// // // ┌─────────────────────────────────────────────────────────────
// // // │ Github Copiolt
// // // └─────────────────────────────────────────────────────────────

// // import 'package:flutter/material.dart';
// // import 'package:flutter_svg/svg.dart';
// // import 'package:google_fonts/google_fonts.dart';

// // // Global color constants
// // class AppColors {
// //   static const Color containerBg = Color(0xFF262626);
// //   static const Color pillBg = Color(0xFF333240);
// //   static const Color actionButtonBg = Color(0xFF474747);
// // }

// // // Global text styles
// // class AppTextStyles {
// //   static TextStyle inter({
// //     Color? color,
// //     FontWeight? fontWeight,
// //     double? fontSize,
// //   }) {
// //     return GoogleFonts.inter(
// //       color: color,
// //       fontWeight: fontWeight,
// //       fontSize: fontSize,
// //     );
// //   }

// //   static TextStyle interBold({Color? color, double? fontSize}) {
// //     return GoogleFonts.inter(
// //       color: color,
// //       fontWeight: FontWeight.bold,
// //       fontSize: fontSize,
// //     );
// //   }

// //   static TextStyle interSemiBold({Color? color, double? fontSize}) {
// //     return GoogleFonts.inter(
// //       color: color,
// //       fontWeight: FontWeight.w600,
// //       fontSize: fontSize,
// //     );
// //   }

// //   static TextStyle interMedium({Color? color, double? fontSize}) {
// //     return GoogleFonts.inter(
// //       color: color,
// //       fontWeight: FontWeight.w500,
// //       fontSize: fontSize,
// //     );
// //   }

// //   static TextStyle interExtraBold({Color? color, double? fontSize}) {
// //     return GoogleFonts.inter(
// //       color: color,
// //       fontWeight: FontWeight.w900,
// //       fontSize: fontSize,
// //     );
// //   }
// // }

// // class MovieDetailScreen extends StatelessWidget {
// //   const MovieDetailScreen({super.key});

// //   @override
// //   Widget build(BuildContext context) {
// //     final theme = Theme.of(context);
// //     return Scaffold(
// //       backgroundColor: Colors.black,
// //       appBar: AppBar(
// //         // leading: const BackButton(),
// //         title: Padding(
// //           padding: const EdgeInsets.all(4.0),
// //           child: Row(
// //             children: [
// //               Text(
// //                 'Title',
// //                 style: theme.textTheme.titleLarge!.copyWith(
// //                     fontWeight: FontWeight.bold,
// //                     color: Colors.white,
// //                     fontSize: 28),
// //               ),
// //               const Spacer(),
// //               IconButton(
// //                 onPressed: () {},
// //                 icon: const Icon(Icons.message_outlined),
// //               ),
// //               IconButton(
// //                 onPressed: () {},
// //                 icon: const Icon(Icons.card_giftcard),
// //               ),
// //             ],
// //           ),
// //         ),
// //         backgroundColor: Colors.black,
// //         elevation: 0,
// //         foregroundColor: Colors.white,
// //       ),
// //       body: SafeArea(
// //         child: SingleChildScrollView(
// //           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
// //           child: Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: const [
// //               PosterCard(),
// //               SizedBox(height: 8),
// //               LockSection(),
// //               SizedBox(height: 12),
// //               ActionButtons(),
// //               SizedBox(height: 12),
// //               // DetailsCard(),
// //               // SizedBox(height: 12),
// //               UnlockRewardsTabs(),
// //               SizedBox(height: 12),
// //               EpisodesSection(),
// //               SizedBox(height: 12),
// //               SuggestedSeasonsSection(),
// //               SizedBox(height: 12),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }

// // class PosterCard extends StatelessWidget {
// //   const PosterCard({super.key});

// //   @override
// //   Widget build(BuildContext context) {
// //     // Placeholder image from picsum - replace with your poster image or local asset
// //     const posterUrl =
// //         'https://picsum.photos/800/420?image=1062'; // change as needed

// //     return Padding(
// //       padding: const EdgeInsets.only(left: 2, right: 2, top: 0, bottom: 0),
// //       child: ClipRRect(
// //         borderRadius: BorderRadius.circular(12),
// //         child: Container(
// //           width: double.infinity,
// //           // height: 243,
// //           padding: const EdgeInsets.all(10),
// //           decoration: BoxDecoration(
// //             color: AppColors.containerBg,
// //             borderRadius: BorderRadius.circular(16),
// //           ),
// //           child: Column(
// //             crossAxisAlignment: CrossAxisAlignment.stretch,
// //             children: [
// //               Stack(
// //                 children: [
// //                   ClipRRect(
// //                     borderRadius: BorderRadius.circular(12),
// //                     child: AspectRatio(
// //                       aspectRatio: 16 / 9,
// //                       child: Image.network(
// //                         posterUrl,
// //                         fit: BoxFit.cover,
// //                         loadingBuilder: (context, child, progress) {
// //                           if (progress == null) return child;
// //                           return Container(
// //                             color: Colors.black12,
// //                             child: const Center(
// //                               child: CircularProgressIndicator(strokeWidth: 2),
// //                             ),
// //                           );
// //                         },
// //                       ),
// //                     ),
// //                   ),
// //                   // TODO: Add video progress overlay if needed
// //                   // Positioned(
// //                   //   left: 12,
// //                   //   bottom: 12,
// //                   //   right: 12,
// //                   //   child: Column(
// //                   //     crossAxisAlignment: CrossAxisAlignment.start,
// //                   //     children: [
// //                   //       Text('Episode 1 · The Beginning',
// //                   //           style: Theme.of(context)
// //                   //               .textTheme
// //                   //               .bodyLarge!
// //                   //               .copyWith(color: Colors.white)),
// //                   //       const SizedBox(height: 6),
// //                   //       ClipRRect(
// //                   //         borderRadius: BorderRadius.circular(8),
// //                   //         child: LinearProgressIndicator(
// //                   //           value: 0.2,
// //                   //           minHeight: 6,
// //                   //           backgroundColor: Colors.black38,
// //                   //           valueColor: AlwaysStoppedAnimation<Color>(
// //                   //               Theme.of(context).colorScheme.primary),
// //                   //         ),
// //                   //       ),
// //                   //       const SizedBox(height: 6),
// //                   //       Row(
// //                   //         children: const [
// //                   //           Text('10:30 / 50:00',
// //                   //               style: TextStyle(
// //                   //                   color: Colors.white70, fontSize: 12))
// //                   //         ],
// //                   //       )
// //                   //     ],
// //                   //   ),
// //                   // ),
// //                 ],
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }

// // class LockSection extends StatelessWidget {
// //   const LockSection({super.key});

// //   @override
// //   Widget build(BuildContext context) {
// //     return Padding(
// //       padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
// //       // padding: const EdgeInsets.all(0),

// //       child: Row(
// //         children: [
// //           ElevatedButton.icon(
// //             onPressed: () {},
// //             style: ElevatedButton.styleFrom(
// //               backgroundColor: AppColors.pillBg,
// //               shape: RoundedRectangleBorder(
// //                   borderRadius: BorderRadius.circular(20)),
// //               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
// //               elevation: 0,
// //             ),
// //             icon: const Icon(Icons.add, size: 18, color: Color(0xFFFFFFFF)),
// //             label: Text(
// //               'My List',
// //               style: AppTextStyles.interSemiBold(
// //                   color: Colors.white, fontSize: 14),
// //             ),
// //           ),
// //           // const SizedBox(width: 14),
// //           const Spacer(),
// //           Container(
// //             decoration: BoxDecoration(
// //                 gradient: const LinearGradient(
// //                   colors: [
// //                     Color.fromARGB(255, 105, 1, 10),
// //                     Color.fromARGB(255, 248, 2, 2)
// //                   ],
// //                   begin: Alignment.centerLeft,
// //                   end: Alignment.centerRight,
// //                 ),
// //                 borderRadius: BorderRadius.circular(28)),
// //             child: ElevatedButton(
// //               onPressed: () {},
// //               style: ElevatedButton.styleFrom(
// //                 backgroundColor: Colors.transparent,
// //                 shadowColor: Colors.transparent,
// //                 shape: RoundedRectangleBorder(
// //                     borderRadius: BorderRadius.circular(28)),
// //                 padding:
// //                     const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
// //                 elevation: 0,
// //               ),
// //               child: Row(
// //                 mainAxisSize: MainAxisSize.min,
// //                 children: [
// //                   SvgPicture.asset(
// //                     'assets/svgs/lock.svg',
// //                     width: 24,
// //                     height: 24,
// //                   ),
// //                   const SizedBox(width: 6),
// //                   Text(
// //                     'unlock now',
// //                     style: AppTextStyles.interExtraBold(
// //                         color: Colors.white, fontSize: 16),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //           // const SizedBox(width: 14),
// //           const Spacer(),
// //           OutlinedButton.icon(
// //             onPressed: () {},
// //             style: OutlinedButton.styleFrom(
// //               backgroundColor: AppColors.pillBg,
// //               side: const BorderSide(color: Colors.white12),
// //               shape: RoundedRectangleBorder(
// //                   borderRadius: BorderRadius.circular(20)),
// //               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
// //             ),
// //             icon: const Icon(Icons.share, size: 18, color: Color(0xFFFFFFFF)),
// //             label: Text(
// //               'Share',
// //               style: AppTextStyles.interSemiBold(
// //                   color: Colors.white, fontSize: 14),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }

// // class ActionButtons extends StatelessWidget {
// //   const ActionButtons({super.key});

// //   @override
// //   Widget build(BuildContext context) {
// //     return Container(
// //       width: double.infinity,
// //       padding: const EdgeInsets.all(14),
// //       decoration: BoxDecoration(
// //         color: AppColors.containerBg,
// //         borderRadius: BorderRadius.circular(16),
// //       ),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           // ⭐ Rating + Chip + Reward
// //           Row(
// //             crossAxisAlignment: CrossAxisAlignment.center,
// //             children: [
// //               // Rating + Age chip
// //               Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Row(
// //                     children: [
// //                       const Icon(Icons.star, color: Colors.amber, size: 18),
// //                       const SizedBox(width: 6),
// //                       Text(
// //                         '4.8/10',
// //                         style: AppTextStyles.interSemiBold(
// //                             color: Colors.white, fontSize: 12),
// //                       ),
// //                       const SizedBox(width: 8),
// //                       Container(
// //                         padding: const EdgeInsets.symmetric(
// //                             horizontal: 8, vertical: 3),
// //                         decoration: BoxDecoration(
// //                           color: Color.fromARGB(255, 78, 78, 78),
// //                           borderRadius: BorderRadius.circular(20),
// //                         ),
// //                         child: Text(
// //                           'U/A: 18+',
// //                           style: AppTextStyles.interMedium(
// //                               color: Colors.white, fontSize: 14),
// //                         ),
// //                       ),
// //                     ],
// //                   ),

// //                   const SizedBox(height: 4),
// //                   // Release Date
// //                   Text(
// //                     'Released at: April 12, 2019',
// //                     style: AppTextStyles.inter(
// //                         color: Color.fromRGBO(255, 255, 255, 0.541),
// //                         fontSize: 12),
// //                   ),
// //                 ],
// //               ),

// //               const Spacer(),

// //               // Reward badge
// //               Container(
// //                 padding:
// //                     const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
// //                 decoration: BoxDecoration(
// //                   gradient: const LinearGradient(
// //                     colors: [
// //                       Color.fromARGB(255, 247, 216, 14),
// //                       Color.fromARGB(255, 255, 174, 0)
// //                     ],
// //                     begin: Alignment.centerLeft,
// //                     end: Alignment.centerRight,
// //                   ),
// //                   borderRadius: BorderRadius.circular(20),
// //                 ),
// //                 child: Row(
// //                   children: const [
// //                     Image(
// //                         image: AssetImage('assets/images/coins.png'),
// //                         width: 16,
// //                         height: 16),
// //                     SizedBox(width: 5),
// //                     Text(
// //                       'Point Reward:\n500 Bpts',
// //                       style: TextStyle(
// //                         color: Colors.white,
// //                         fontSize: 11,
// //                         fontWeight: FontWeight.bold,
// //                         height: 1.2,
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //             ],
// //           ),

// //           const SizedBox(height: 10),

// //           // Description
// //           const Text(
// //             'A young woman falls for a guy with a dark secret and the two embark on a rocky relationship. '
// //             'Based on the novel by Anna Todd.',
// //             style: TextStyle(
// //               color: Colors.white,
// //               fontSize: 13.5,
// //               height: 1.4,
// //             ),
// //             maxLines: 3,
// //             overflow: TextOverflow.ellipsis,
// //           ),

// //           const SizedBox(height: 10),

// //           // See more
// //           Center(
// //             child: TextButton(
// //               onPressed: () {},
// //               style: TextButton.styleFrom(
// //                 foregroundColor: Colors.white70,
// //                 padding: EdgeInsets.zero,
// //                 minimumSize: const Size(0, 20),
// //                 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
// //               ),
// //               child: const Text(
// //                 'see more',
// //                 style: TextStyle(
// //                   fontSize: 13,
// //                   decoration: TextDecoration.underline,
// //                   decorationColor: Colors.white24,
// //                 ),
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }

// // // class DetailsCard extends StatelessWidget {
// // //   const DetailsCard({super.key});

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return Container(
// // //       padding: const EdgeInsets.all(12),
// // //       decoration: BoxDecoration(
// // //         color: const Color(0xFF1A1A1A),
// // //         borderRadius: BorderRadius.circular(10),
// // //       ),
// // //       child: Column(
// // //         children: [
// // //           Row(
// // //             // crossAxisAlignment: CrossAxisAlignment.center,
// // //             mainAxisAlignment: MainAxisAlignment.center,
// // //             children: [
// // //               Padding(
// // //                 padding:
// // //                     const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
// // //               ),
// // //               ElevatedButton(
// // //                 onPressed: () {},
// // //                 style: ElevatedButton.styleFrom(
// // //                   backgroundColor: const Color.fromARGB(255, 63, 60, 60),
// // //                   shape: RoundedRectangleBorder(
// // //                       borderRadius: BorderRadius.circular(20)),
// // //                   // padding: const EdgeInsets.symmetric(vertical: 12),
// // //                 ),
// // //                 child: const Text('Unlock',
// // //                     style: TextStyle(
// // //                         color: Colors.white,
// // //                         fontWeight: FontWeight.bold,
// // //                         fontSize: 16)),
// // //               ),
// // //               const SizedBox(width: 40),
// // //               ElevatedButton(
// // //                 onPressed: () {},
// // //                 style: ElevatedButton.styleFrom(
// // //                   backgroundColor: const Color.fromARGB(255, 63, 60, 60),
// // //                   shape: RoundedRectangleBorder(
// // //                       borderRadius: BorderRadius.circular(20)),
// // //                   // padding: const EdgeInsets.symmetric(vertical: 12),
// // //                 ),
// // //                 child: const Text('Rewards',
// // //                     style: TextStyle(
// // //                         color: Colors.white,
// // //                         fontWeight: FontWeight.bold,
// // //                         fontSize: 16)),
// // //               ),
// // //             ],
// // //           ),
// // //           const SizedBox(height: 12),
// // //           const Align(
// // //             alignment: Alignment.centerLeft,
// // //             child: Text('Points required to unlock:',
// // //                 style: TextStyle(color: Colors.white70)),
// // //           ),
// // //           const SizedBox(height: 8),
// // //           Row(
// // //             children: [
// // //               Container(
// // //                 padding:
// // //                     const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
// // //                 decoration: BoxDecoration(
// // //                   color: const Color(0xFF2B2B2B),
// // //                   borderRadius: BorderRadius.circular(20),
// // //                 ),
// // //                 child: Row(
// // //                   children: const [
// // //                     Icon(Icons.circle, color: Colors.red, size: 10),
// // //                     SizedBox(width: 8),
// // //                     Text('500 points',
// // //                         style: TextStyle(
// // //                             fontWeight: FontWeight.bold, color: Colors.white)),
// // //                   ],
// // //                 ),
// // //               ),
// // //               const SizedBox(width: 12),
// // //               Expanded(
// // //                 child: Row(
// // //                   children: [
// // //                     const Text('Badges required to unlock:',
// // //                         style: TextStyle(color: Colors.white70)),
// // //                     const SizedBox(width: 8),
// // //                     Expanded(
// // //                       child: SingleChildScrollView(
// // //                         scrollDirection: Axis.horizontal,
// // //                         child: Row(
// // //                           children: List.generate(
// // //                             4,
// // //                             (i) => Padding(
// // //                               padding:
// // //                                   const EdgeInsets.symmetric(horizontal: 6),
// // //                               child: Container(
// // //                                 width: 48,
// // //                                 height: 28,
// // //                                 decoration: BoxDecoration(
// // //                                   color: const Color(0xFF3A3A3A),
// // //                                   borderRadius: BorderRadius.circular(6),
// // //                                 ),
// // //                                 child: Center(
// // //                                     child: Text(
// // //                                   (i + 1).toString(),
// // //                                   style: const TextStyle(color: Colors.white70),
// // //                                 )),
// // //                               ),
// // //                             ),
// // //                           ),
// // //                         ),
// // //                       ),
// // //                     ),
// // //                   ],
// // //                 ),
// // //               ),
// // //             ],
// // //           ),
// // //           const SizedBox(height: 12),
// // //           const Align(
// // //             alignment: Alignment.centerLeft,
// // //             child: Text('Products required to unlock:',
// // //                 style: TextStyle(color: Colors.white70)),
// // //           ),
// // //           const SizedBox(height: 8),
// // //           SizedBox(
// // //             height: 64,
// // //             child: ListView(
// // //               scrollDirection: Axis.horizontal,
// // //               children: List.generate(
// // //                 6,
// // //                 (index) => Padding(
// // //                   padding: const EdgeInsets.symmetric(horizontal: 6),
// // //                   child: ClipRRect(
// // //                     borderRadius: BorderRadius.circular(8),
// // //                     child: Container(
// // //                       width: 64,
// // //                       color: Colors.black,
// // //                       child: Image.network(
// // //                         'https://picsum.photos/seed/p$index/200',
// // //                         fit: BoxFit.cover,
// // //                       ),
// // //                     ),
// // //                   ),
// // //                 ),
// // //               ),
// // //             ),
// // //           ),
// // //           const SizedBox(height: 12),
// // //           ElevatedButton(
// // //             onPressed: () {},
// // //             style: ElevatedButton.styleFrom(
// // //               backgroundColor: const Color(0xFFCFB26C),
// // //               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
// // //               shape: RoundedRectangleBorder(
// // //                   borderRadius: BorderRadius.circular(14)),
// // //             ),
// // //             child: Row(
// // //               mainAxisAlignment: MainAxisAlignment.center,
// // //               children: const [
// // //                 Icon(Icons.workspace_premium_outlined, color: Colors.black),
// // //                 SizedBox(width: 8),
// // //                 Text('Unlock with PREMIUM',
// // //                     style: TextStyle(color: Colors.black)),
// // //               ],
// // //             ),
// // //           ),
// // //         ],
// // //       ),
// // //     );
// // //   }
// // // }

// // class UnlockRewardsTabs extends StatelessWidget {
// //   const UnlockRewardsTabs({super.key});

// //   // Colors / gradients used to match the screenshots
// //   static const LinearGradient _goldGradient = LinearGradient(
// //     colors: [
// //       Color.fromARGB(255, 145, 118, 52),
// //       Color.fromARGB(255, 238, 208, 131),
// //       Color.fromARGB(255, 226, 185, 83),
// //       Color.fromARGB(255, 207, 178, 108),
// //     ],
// //     begin: Alignment.topLeft,
// //     end: Alignment.bottomRight,
// //   );

// //   @override
// //   Widget build(BuildContext context) {
// //     return DefaultTabController(
// //       length: 2,
// //       child: Container(
// //         padding: const EdgeInsets.all(8),
// //         decoration: BoxDecoration(
// //           color: AppColors.containerBg,
// //           borderRadius: BorderRadius.circular(16),
// //         ),
// //         child: Column(
// //           children: [
// //             // Top Tabs (pill)
// //             Container(
// //               padding: const EdgeInsets.only(top: 4, bottom: 8),
// //               decoration: BoxDecoration(
// //                 color: Colors.transparent,
// //                 borderRadius: BorderRadius.circular(12),
// //               ),
// //               child: ClipRRect(
// //                 borderRadius: BorderRadius.circular(12),
// //                 child: Material(
// //                   color: Colors.transparent,
// //                   child: TabBar(
// //                     padding: EdgeInsets.only(left: 30, right: 30),
// //                     dividerColor: Colors.transparent,
// //                     indicator: BoxDecoration(
// //                       color: AppColors.actionButtonBg,
// //                       borderRadius: BorderRadius.circular(50),
// //                     ),
// //                     indicatorSize: TabBarIndicatorSize.tab,
// //                     labelColor: Colors.white,
// //                     unselectedLabelColor: Colors.white70,
// //                     labelStyle: AppTextStyles.interExtraBold(fontSize: 16),
// //                     unselectedLabelStyle: AppTextStyles.interMedium(),
// //                     indicatorWeight: 4,
// //                     tabs: const [
// //                       Tab(
// //                         text: 'Unlock',
// //                         height: 36,
// //                       ),
// //                       // Spacer(),
// //                       Tab(text: 'Rewards', height: 36),
// //                     ],
// //                   ),
// //                 ),
// //               ),
// //             ),

// //             Divider(
// //               color: Color(0x1FFFFFFF), // very faint white (approx white10)
// //               thickness: 1,
// //               height: 1,
// //               indent: 12,
// //               endIndent: 12,
// //             ),
// //             const SizedBox(height: 12),

// //             // Tab Views - fixed height similar to your previous layout and screenshots
// //             SizedBox(
// //               height: 320,
// //               child: TabBarView(
// //                 children: [
// //                   // Unlock tab
// //                   _buildUnlockTab(),

// //                   // Rewards tab
// //                   _buildRewardsTab(),
// //                 ],
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   // Unlock tab UI (matches left screenshot)
// //   Widget _buildUnlockTab() {
// //     return Padding(
// //       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           const Text(
// //             'Points required to unlock:',
// //             style: TextStyle(color: Color(0xFFB4B4B4)),
// //           ),
// //           const SizedBox(height: 8),

// //           // Red points pill
// //           Row(
// //             children: [
// //               Container(
// //                 padding: const EdgeInsets.only(
// //                     left: 6, right: 6, top: 10, bottom: 10),
// //                 decoration: BoxDecoration(
// //                     gradient: const LinearGradient(
// //                       colors: [
// //                         Color(0xFF990000),
// //                         Color(0xFFFF0000),
// //                       ],
// //                       begin: Alignment.centerLeft,
// //                       end: Alignment.centerRight,
// //                     ),
// //                     borderRadius: BorderRadius.circular(28)),
// //                 child: Row(
// //                   // crossAxisAlignment: CrossAxisAlignment.center,
// //                   children: [
// //                     Image(
// //                         image: AssetImage('assets/images/coins.png'),
// //                         width: 16,
// //                         height: 16),
// //                     SizedBox(width: 4),
// //                     Text(
// //                       '500',
// //                       style: AppTextStyles.interBold(
// //                           color: Colors.white, fontSize: 14),
// //                     ),
// //                     Text(
// //                       ' points',
// //                       style: AppTextStyles.interSemiBold(
// //                           color: Colors.white, fontSize: 12),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //               // const SizedBox(width: 12),
// //               // const Expanded(
// //               //   child: Text('Badges required: 🏅🏅🏅',
// //               //       style: TextStyle(color: Colors.white70)),
// //               // ),
// //             ],
// //           ),

// //           const SizedBox(height: 8),

// //           // Badges required (gold cards with small progress lines)
// //           const Text('Badges required to unlock:',
// //               style: TextStyle(color: Color(0xFFB4B4B4))),
// //           const SizedBox(height: 8),
// //           SizedBox(
// //             height: 60,
// //             child: ListView.separated(
// //               scrollDirection: Axis.horizontal,
// //               itemCount: 4,
// //               separatorBuilder: (_, __) => const SizedBox(width: 10),
// //               itemBuilder: (context, index) {
// //                 // Dummy progress values for demonstration
// //                 final progress = ((index + 1) * 0.25).clamp(0.0, 1.0);
// //                 return Column(
// //                   children: [
// //                     Container(
// //                       width: 92,
// //                       height: 44,
// //                       decoration: BoxDecoration(
// //                         gradient: _goldGradient,
// //                         borderRadius: BorderRadius.circular(8),
// //                       ),
// //                       child: Center(
// //                         child: Text(
// //                           '',
// //                           style: TextStyle(
// //                             color: Colors.black.withValues(alpha: 0.8),
// //                             fontWeight: FontWeight.w700,
// //                           ),
// //                         ),
// //                       ),
// //                     ),
// //                     const SizedBox(height: 6),
// //                     Container(
// //                       width: 92,
// //                       height: 6,
// //                       decoration: BoxDecoration(
// //                         color: Colors.white12,
// //                         borderRadius: BorderRadius.circular(6),
// //                       ),
// //                       child: FractionallySizedBox(
// //                         alignment: Alignment.centerLeft,
// //                         widthFactor: progress,
// //                         child: Container(
// //                           decoration: BoxDecoration(
// //                             color: const Color(0xFFCFB26C),
// //                             borderRadius: BorderRadius.circular(6),
// //                           ),
// //                         ),
// //                       ),
// //                     ),
// //                   ],
// //                 );
// //               },
// //             ),
// //           ),

// //           const SizedBox(height: 8),

// //           // Products required (rounded thumbnails)
// //           const Text('Products required to unlock:',
// //               style: TextStyle(color: Color(0xFFB4B4B4))),
// //           const SizedBox(height: 8),
// //           SizedBox(
// //             height: 68,
// //             child: ListView.separated(
// //               scrollDirection: Axis.horizontal,
// //               itemCount: 4,
// //               separatorBuilder: (_, __) => const SizedBox(width: 10),
// //               itemBuilder: (context, index) {
// //                 return Container(
// //                   width: 56,
// //                   height: 56,
// //                   decoration: BoxDecoration(
// //                     borderRadius: BorderRadius.circular(12),
// //                     border: Border.all(color: Colors.white10),
// //                   ),
// //                   child: ClipRRect(
// //                     borderRadius: BorderRadius.circular(12),
// //                     child: Image.network(
// //                       'https://picsum.photos/seed/unlock$index/200',
// //                       fit: BoxFit.cover,
// //                     ),
// //                   ),
// //                 );
// //               },
// //             ),
// //           ),

// //           const Spacer(),

// //           // Full-width gold "Unlock with PREMIUM" pill
// //           GestureDetector(
// //             onTap: () {},
// //             child: Container(
// //               width: double.infinity,
// //               padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
// //               decoration: BoxDecoration(
// //                 gradient: _goldGradient,
// //                 borderRadius: BorderRadius.circular(50),
// //               ),
// //               child: Row(
// //                 mainAxisAlignment: MainAxisAlignment.center,
// //                 children: [
// //                   Icon(Icons.headphones, color: Colors.black),
// //                   SizedBox(width: 4),
// //                   Text(
// //                     'Unlock with PREMIUM',
// //                     style: AppTextStyles.interBold(
// //                         color: Color.fromARGB(255, 74, 63, 32), fontSize: 18),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   // Rewards tab UI (matches right screenshot)
// //   Widget _buildRewardsTab() {
// //     return Padding(
// //       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           const Text(
// //             'Points Reward:',
// //             style: TextStyle(color: Color(0xFFB4B4B4)),
// //           ),
// //           const SizedBox(height: 8),

// //           // Points reward pill (yellow/gold)
// //           Row(
// //             children: [
// //               Container(
// //                 padding:
// //                     const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
// //                 decoration: BoxDecoration(
// //                     gradient: const LinearGradient(
// //                       colors: [
// //                         Color(0xFFFFCB0C),
// //                         Color(0xFFDC9903),
// //                       ],
// //                       begin: Alignment.centerLeft,
// //                       end: Alignment.centerRight,
// //                     ),
// //                     borderRadius: BorderRadius.circular(28)),
// //                 child: Row(
// //                   children: [
// //                     Image(
// //                         image: AssetImage('assets/images/coins.png'),
// //                         width: 16,
// //                         height: 16),
// //                     SizedBox(width: 4),
// //                     Text(
// //                       '500',
// //                       style: AppTextStyles.interBold(
// //                           color: Colors.white, fontSize: 14),
// //                     ),
// //                     Text(
// //                       ' points',
// //                       style: AppTextStyles.interSemiBold(
// //                           color: Colors.white, fontSize: 12),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //               // const SizedBox(width: 12),
// //               // const Expanded(
// //               //   child: Text('Badges Rewards: 🏅🏅🏅',
// //               //       style: TextStyle(color: Colors.white70)),
// //               // ),
// //             ],
// //           ),

// //           const SizedBox(height: 8),

// //           // Badges rewards (same gold cards with progress)
// //           const Text('Badges Rewards:',
// //               style: TextStyle(color: Color(0xFFB4B4B4))),
// //           const SizedBox(height: 8),
// //           SizedBox(
// //             height: 60,
// //             child: ListView.separated(
// //               scrollDirection: Axis.horizontal,
// //               itemCount: 4,
// //               separatorBuilder: (_, __) => const SizedBox(width: 10),
// //               itemBuilder: (context, index) {
// //                 final progress = ((index + 1) * 0.2).clamp(0.0, 1.0);
// //                 return Column(
// //                   children: [
// //                     Container(
// //                       width: 92,
// //                       height: 44,
// //                       decoration: BoxDecoration(
// //                         gradient: _goldGradient,
// //                         borderRadius: BorderRadius.circular(8),
// //                       ),
// //                       child: Center(
// //                         child: Text(
// //                           '',
// //                           style: TextStyle(
// //                             color: Colors.black.withValues(alpha: 0.8),
// //                             fontWeight: FontWeight.w700,
// //                           ),
// //                         ),
// //                       ),
// //                     ),
// //                     const SizedBox(height: 6),
// //                     Container(
// //                       width: 92,
// //                       height: 6,
// //                       decoration: BoxDecoration(
// //                         color: Colors.white12,
// //                         borderRadius: BorderRadius.circular(6),
// //                       ),
// //                       child: FractionallySizedBox(
// //                         alignment: Alignment.centerLeft,
// //                         widthFactor: progress,
// //                         child: Container(
// //                           decoration: BoxDecoration(
// //                             color: const Color(0xFFCFB26C),
// //                             borderRadius: BorderRadius.circular(6),
// //                           ),
// //                         ),
// //                       ),
// //                     ),
// //                   ],
// //                 );
// //               },
// //             ),
// //           ),

// //           const SizedBox(height: 8),

// //           // Products rewards row
// //           const Text('Products Rewards:',
// //               style: TextStyle(color: Colors.white70)),
// //           const SizedBox(height: 8),
// //           SizedBox(
// //             height: 68,
// //             child: ListView.separated(
// //               scrollDirection: Axis.horizontal,
// //               itemCount: 4,
// //               separatorBuilder: (_, __) => const SizedBox(width: 10),
// //               itemBuilder: (context, index) {
// //                 return Container(
// //                   width: 56,
// //                   height: 56,
// //                   decoration: BoxDecoration(
// //                     borderRadius: BorderRadius.circular(12),
// //                     border: Border.all(color: Colors.white10),
// //                   ),
// //                   child: ClipRRect(
// //                     borderRadius: BorderRadius.circular(12),
// //                     child: Image.network(
// //                       'https://picsum.photos/seed/rewards$index/200',
// //                       fit: BoxFit.cover,
// //                     ),
// //                   ),
// //                 );
// //               },
// //             ),
// //           ),

// //           const Spacer(),

// //           // Full-width gold button (same look)
// //           GestureDetector(
// //             onTap: () {},
// //             child: Container(
// //               width: double.infinity,
// //               padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
// //               decoration: BoxDecoration(
// //                 gradient: _goldGradient,
// //                 borderRadius: BorderRadius.circular(14),
// //               ),
// //               child: Row(
// //                 mainAxisAlignment: MainAxisAlignment.center,
// //                 children: const [
// //                   Icon(Icons.workspace_premium_outlined, color: Colors.black),
// //                   SizedBox(width: 10),
// //                   Text(
// //                     'Unlock with PREMIUM',
// //                     style: TextStyle(
// //                         color: Colors.black, fontWeight: FontWeight.w700),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }

// // // -------------------- Episodes & Suggested Seasons (modified) --------------------

// // // class EpisodesSection extends StatelessWidget {
// // //   const EpisodesSection({super.key});

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     // Example episodes - replace thumbnails with real assets
// // //     final thumbnails = List.generate(
// // //         8, (i) => 'https://picsum.photos/seed/ep$i/600/360'); // placeholders

// // //     return Container(
// // //       padding: const EdgeInsets.all(12),
// // //       decoration: BoxDecoration(
// // //         color: AppColors.containerBg,
// // //         borderRadius: BorderRadius.circular(14),
// // //       ),
// // //       child: Column(
// // //         crossAxisAlignment: CrossAxisAlignment.start,
// // //         children: [
// // //           // Header
// // //           Row(
// // //             children: [
// // //               Padding(
// // //                 padding: const EdgeInsets.only(left: 10),
// // //                 child: Container(
// // //                   decoration: BoxDecoration(
// // //                       gradient: const LinearGradient(
// // //                         colors: [
// // //                           Color(0xFF2964FA),
// // //                           Color(0xFF2E45F7),
// // //                         ],
// // //                         begin: Alignment.centerLeft,
// // //                         end: Alignment.centerRight,
// // //                       ),
// // //                       borderRadius: BorderRadius.circular(12)),
// // //                   padding: const EdgeInsets.all(8),
// // //                   child: const Icon(Icons.play_circle,
// // //                       color: Color.fromARGB(255, 255, 255, 255), size: 24),
// // //                 ),
// // //               ),
// // //               const SizedBox(width: 10),
// // //               Column(
// // //                 crossAxisAlignment: CrossAxisAlignment.start,
// // //                 children: [
// // //                   Text('Episodes',
// // //                       style: Theme.of(context).textTheme.titleMedium!.copyWith(
// // //                           fontWeight: FontWeight.bold, color: Colors.white)),
// // //                   Text(
// // //                       'Lorem ipsum dolor sit amet consecte. Blandit pellentes...',
// // //                       style: TextStyle(
// // //                           color: Colors.white70,
// // //                           fontWeight: FontWeight.w500,
// // //                           fontSize: 10)),
// // //                 ],
// // //               ),
// // //               // const Spacer(),
// // //             ],
// // //           ),
// // //           const SizedBox(height: 12),

// // //           // Grid of episodes, each card styled to match the container look
// // //           GridView.builder(
// // //             physics: const NeverScrollableScrollPhysics(),
// // //             shrinkWrap: true,
// // //             itemCount: thumbnails.length,
// // //             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
// // //               crossAxisCount: 2,
// // //               mainAxisSpacing: 12,
// // //               crossAxisSpacing: 12,
// // //               childAspectRatio: 16 / 9,
// // //             ),
// // //             itemBuilder: (context, index) {
// // //               return EpisodeCard(
// // //                 imageUrl: thumbnails[index],
// // //                 label: 'EP ${index + 1}',
// // //               );
// // //             },
// // //           ),
// // //         ],
// // //       ),
// // //     );
// // //   }
// // // }

// // // class EpisodeCard extends StatelessWidget {
// // //   final String imageUrl;
// // //   final String label;
// // //   const EpisodeCard({super.key, required this.imageUrl, required this.label});

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return ClipRRect(
// // //       borderRadius: BorderRadius.circular(20),
// // //       child: Container(
// // //         decoration: BoxDecoration(
// // //           color: const Color(0xFF0F0F10),
// // //           borderRadius: BorderRadius.circular(20),
// // //           boxShadow: [
// // //             BoxShadow(
// // //               color: Colors.black.withValues(alpha: 0.45),
// // //               blurRadius: 8,
// // //               offset: const Offset(0, 4),
// // //             ),
// // //           ],
// // //         ),
// // //         child: Stack(
// // //           fit: StackFit.expand,
// // //           children: [
// // //             // Background image
// // //             Positioned.fill(
// // //               child: Image.network(imageUrl, fit: BoxFit.cover),
// // //             ),

// // //             // subtle top->bottom gradient to improve contrast
// // //             Positioned.fill(
// // //               child: Container(
// // //                 decoration: BoxDecoration(
// // //                   gradient: LinearGradient(
// // //                     colors: [
// // //                       Colors.black.withValues(alpha: 0.4),
// // //                       Colors.black.withValues(alpha: 0.05),
// // //                     ],
// // //                     begin: Alignment.bottomCenter,
// // //                     end: Alignment.topCenter,
// // //                   ),
// // //                 ),
// // //               ),
// // //             ),

// // //             // EP badge (blue) top-left
// // //             Positioned(
// // //               left: 8,
// // //               top: 8,
// // //               child: Container(
// // //                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
// // //                 decoration: BoxDecoration(
// // //                   color: Color(0xFFD2EDFF),
// // //                   borderRadius: BorderRadius.circular(10),
// // //                   boxShadow: [
// // //                     BoxShadow(
// // //                       color: Color(0xFF0064A7),
// // //                       blurRadius: 4,
// // //                       offset: const Offset(0, 2),
// // //                     ),
// // //                   ],
// // //                 ),
// // //                 child: Text(label,
// // //                     style: AppTextStyles.interBold(
// // //                         color: Color(0xFF0064A7), fontSize: 12)),
// // //               ),
// // //             ),

// // //             // // Play icon bottom-right
// // //             // Positioned(
// // //             //   right: 8,
// // //             //   bottom: 8,
// // //             //   child: Container(
// // //             //     decoration: BoxDecoration(
// // //             //       color: Colors.black54,
// // //             //       borderRadius: BorderRadius.circular(8),
// // //             //     ),
// // //             //     padding: const EdgeInsets.all(6),
// // //             //     child:
// // //             //         const Icon(Icons.play_arrow, size: 18, color: Colors.white),
// // //             //   ),
// // //             // ),
// // //           ],
// // //         ),
// // //       ),
// // //     );
// // //   }
// // // }
// // class EpisodesSection extends StatelessWidget {
// //   const EpisodesSection({super.key});

// //   @override
// //   Widget build(BuildContext context) {
// //     // Example episodes - replace thumbnails with real assets
// //     final thumbnails = List.generate(
// //         8, (i) => 'https://picsum.photos/seed/ep$i/600/360'); // placeholders

// //     return Container(
// //       padding: const EdgeInsets.all(12),
// //       decoration: BoxDecoration(
// //         color: AppColors.containerBg,
// //         borderRadius: BorderRadius.circular(14),
// //       ),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           // Header
// //           Row(
// //             children: [
// //               Padding(
// //                 padding: const EdgeInsets.only(left: 10),
// //                 child: Container(
// //                   decoration: BoxDecoration(
// //                       gradient: const LinearGradient(
// //                         colors: [
// //                           Color(0xFF2964FA),
// //                           Color(0xFF2E45F7),
// //                         ],
// //                         begin: Alignment.centerLeft,
// //                         end: Alignment.centerRight,
// //                       ),
// //                       borderRadius: BorderRadius.circular(12)),
// //                   padding: const EdgeInsets.all(8),
// //                   child: const Icon(Icons.play_circle,
// //                       color: Color.fromARGB(255, 255, 255, 255), size: 24),
// //                 ),
// //               ),
// //               const SizedBox(width: 10),
// //               Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Text('Episodes',
// //                       style: Theme.of(context).textTheme.titleMedium!.copyWith(
// //                           fontWeight: FontWeight.bold, color: Colors.white)),
// //                   Text(
// //                       'Lorem ipsum dolor sit amet consecte. Blandit pellentes...',
// //                       style: TextStyle(
// //                           color: Colors.white70,
// //                           fontWeight: FontWeight.w500,
// //                           fontSize: 10)),
// //                 ],
// //               ),
// //               // const Spacer(),
// //             ],
// //           ),
// //           const SizedBox(height: 12),

// //           // Grid of episodes, each card styled to match the container look
// //           GridView.builder(
// //             physics: const NeverScrollableScrollPhysics(),
// //             shrinkWrap: true,
// //             itemCount: thumbnails.length,
// //             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
// //               crossAxisCount: 2,
// //               mainAxisSpacing: 12,
// //               crossAxisSpacing: 12,
// //               // reduced aspect ratio so each card is taller (increased height)
// //               childAspectRatio: 16 / 11,
// //             ),
// //             itemBuilder: (context, index) {
// //               return EpisodeCard(
// //                 imageUrl: thumbnails[index],
// //                 label: 'EP ${index + 1}',
// //               );
// //             },
// //           ),
// //           const SizedBox(height: 8),
// //         ],
// //       ),
// //     );
// //   }
// // }

// // class EpisodeCard extends StatelessWidget {
// //   final String imageUrl;
// //   final String label;
// //   const EpisodeCard({super.key, required this.imageUrl, required this.label});

// //   @override
// //   Widget build(BuildContext context) {
// //     return ClipRRect(
// //       borderRadius: BorderRadius.circular(20),
// //       child: Container(
// //         decoration: BoxDecoration(
// //           color: const Color(0xFF0F0F10),
// //           borderRadius: BorderRadius.circular(20),
// //           boxShadow: [
// //             BoxShadow(
// //               color: Colors.black.withValues(alpha: 0.45),
// //               blurRadius: 8,
// //               offset: const Offset(0, 4),
// //             ),
// //           ],
// //         ),
// //         child: Stack(
// //           fit: StackFit.expand,
// //           children: [
// //             // Background image
// //             Positioned.fill(
// //               child: Image.network(imageUrl, fit: BoxFit.cover),
// //             ),

// //             // subtle top->bottom gradient to improve contrast
// //             Positioned.fill(
// //               child: Container(
// //                 decoration: BoxDecoration(
// //                   gradient: LinearGradient(
// //                     colors: [
// //                       Colors.black.withValues(alpha: 0.4),
// //                       Colors.black.withValues(alpha: 0.05),
// //                     ],
// //                     begin: Alignment.bottomCenter,
// //                     end: Alignment.topCenter,
// //                   ),
// //                 ),
// //               ),
// //             ),

// //             // EP badge (blue) top-left
// //             Positioned(
// //               left: 8,
// //               top: 8,
// //               child: Container(
// //                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
// //                 decoration: BoxDecoration(
// //                   color: Color(0xFFD2EDFF),
// //                   borderRadius: BorderRadius.circular(10),
// //                   boxShadow: [
// //                     BoxShadow(
// //                       color: Color(0xFF0064A7),
// //                       blurRadius: 4,
// //                       offset: const Offset(0, 2),
// //                     ),
// //                   ],
// //                 ),
// //                 child: Text(label,
// //                     style: AppTextStyles.interBold(
// //                         color: Color(0xFF0064A7), fontSize: 12)),
// //               ),
// //             ),

// //             // // Play icon bottom-right
// //             // Positioned(
// //             //   right: 8,
// //             //   bottom: 8,
// //             //   child: Container(
// //             //     decoration: BoxDecoration(
// //             //       color: Colors.black54,
// //             //       borderRadius: BorderRadius.circular(8),
// //             //     ),
// //             //     padding: const EdgeInsets.all(6),
// //             //     child:
// //             //         const Icon(Icons.play_arrow, size: 18, color: Colors.white),
// //             //   ),
// //             // ),
// //             Text('Name of the episode'),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }

// // // -------------------- Suggested Seasons Section (colors updated) --------------------

// // // class SuggestedSeasonsSection extends StatelessWidget {
// // //   const SuggestedSeasonsSection({super.key});

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     // sample seasons - replace with real data
// // //     final seasons = List.generate(3, (i) {
// // //       return {
// // //         'image': 'https://picsum.photos/seed/season$i/300/420',
// // //         'title': 'Season ${i + 1}',
// // //         'episodes': (6 + i).toString(),
// // //         'likes': (100 + i * 50).toString(),
// // //       };
// // //     });

// // //     return Container(
// // //       padding: const EdgeInsets.all(12),
// // //       decoration: BoxDecoration(
// // //         color: AppColors.containerBg, // updated background to match AppColors
// // //         borderRadius: BorderRadius.circular(14),
// // //       ),
// // //       child: Column(
// // //         crossAxisAlignment: CrossAxisAlignment.start,
// // //         children: [
// // //           const SizedBox(height: 6),
// // //           Row(
// // //             children: [
// // //               Text(
// // //                 'Suggested Seasons',
// // //                 style: Theme.of(context).textTheme.titleMedium!.copyWith(
// // //                       fontWeight: FontWeight.bold,
// // //                       color: Colors.white,
// // //                     ),
// // //               ),
// // //               const Spacer(),
// // //               Text(
// // //                 'see more',
// // //                 style: AppTextStyles.interMedium(
// // //                   color: Colors.white70,
// // //                   fontSize: 12,
// // //                 ),
// // //               ),
// // //             ],
// // //           ),
// // //           const SizedBox(height: 12),
// // //           SizedBox(
// // //             height: 160,
// // //             child: ListView.separated(
// // //               scrollDirection: Axis.horizontal,
// // //               itemCount: seasons.length,
// // //               separatorBuilder: (_, __) => const SizedBox(width: 12),
// // //               itemBuilder: (context, index) {
// // //                 final item = seasons[index];
// // //                 return SeasonCard(
// // //                   imageUrl: item['image']!,
// // //                   title: item['title']!,
// // //                   episodes: item['episodes']!,
// // //                   likes: item['likes']!,
// // //                 );
// // //               },
// // //             ),
// // //           ),
// // //         ],
// // //       ),
// // //     );
// // //   }
// // // }

// // // class SeasonCard extends StatelessWidget {
// // //   final String imageUrl;
// // //   final String title;
// // //   final String episodes;
// // //   final String likes;
// // //   const SeasonCard({
// // //     super.key,
// // //     required this.imageUrl,
// // //     required this.title,
// // //     required this.episodes,
// // //     required this.likes,
// // //   });

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return Container(
// // //       width: 120,
// // //       height: 220,
// // //       decoration: BoxDecoration(
// // //         // keep a slightly darker card bg but aligned with AppColors
// // //         color: const Color(0xFF0F0F10),
// // //         borderRadius: BorderRadius.circular(12),
// // //         boxShadow: [
// // //           BoxShadow(
// // //             color: Colors.black.withValues(alpha: 0.45),
// // //             blurRadius: 8,
// // //             offset: const Offset(0, 4),
// // //           ),
// // //         ],
// // //       ),
// // //       child: ClipRRect(
// // //         borderRadius: BorderRadius.circular(12),
// // //         child: Stack(
// // //           children: [
// // //             Positioned.fill(
// // //               child: Image.network(imageUrl, fit: BoxFit.cover),
// // //             ),

// // //             // top-left small lock badge (red) — unchanged color but kept consistent
// // //             Positioned(
// // //               left: 8,
// // //               top: 8,
// // //               child: Container(
// // //                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
// // //                 decoration: BoxDecoration(
// // //                   color: const Color(0xFFD84315),
// // //                   borderRadius: BorderRadius.circular(8),
// // //                 ),
// // //                 child: const Icon(Icons.lock, color: Colors.white, size: 12),
// // //               ),
// // //             ),

// // //             // bottom gradient and stats row (text styles updated)
// // //             Positioned(
// // //               left: 0,
// // //               right: 0,
// // //               bottom: 0,
// // //               child: Container(
// // //                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
// // //                 decoration: BoxDecoration(
// // //                   gradient: LinearGradient(
// // //                     colors: [
// // //                       Colors.black.withValues(alpha: 0.65),
// // //                       Colors.black.withValues(alpha: 0.0),
// // //                     ],
// // //                     begin: Alignment.bottomCenter,
// // //                     end: Alignment.topCenter,
// // //                   ),
// // //                 ),
// // //                 child: Column(
// // //                   mainAxisSize: MainAxisSize.min,
// // //                   crossAxisAlignment: CrossAxisAlignment.start,
// // //                   children: [
// // //                     Text(
// // //                       title,
// // //                       style: AppTextStyles.interSemiBold(
// // //                         color: Colors.white,
// // //                         fontSize: 13,
// // //                       ),
// // //                       maxLines: 1,
// // //                       overflow: TextOverflow.ellipsis,
// // //                     ),
// // //                     const SizedBox(height: 6),
// // //                     Row(
// // //                       children: [
// // //                         _StatIcon(
// // //                           icon: Icons.fiber_manual_record,
// // //                           label: episodes,
// // //                         ),
// // //                         const SizedBox(width: 8),
// // //                         _StatIcon(
// // //                           icon: Icons.favorite_border,
// // //                           label: likes,
// // //                         ),
// // //                         const Spacer(),
// // //                       ],
// // //                     ),
// // //                   ],
// // //                 ),
// // //               ),
// // //             ),
// // //           ],
// // //         ),
// // //       ),
// // //     );
// // //   }
// // // }

// // // class _StatIcon extends StatelessWidget {
// // //   final IconData icon;
// // //   final String label;
// // //   const _StatIcon({required this.icon, required this.label});

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return Row(
// // //       children: [
// // //         Icon(icon, size: 12, color: Colors.white70),
// // //         const SizedBox(width: 4),
// // //         Text(label,
// // //             style: AppTextStyles.inter(
// // //               color: Colors.white70,
// // //               fontSize: 12,
// // //             )),
// // //       ],
// // //     );
// // //   }
// // // }

// // class SuggestedSeasonsSection extends StatelessWidget {
// //   const SuggestedSeasonsSection({super.key});

// //   @override
// //   Widget build(BuildContext context) {
// //     // sample seasons - replace with real data
// //     final seasons = List.generate(3, (i) {
// //       return {
// //         'image': 'https://picsum.photos/seed/season$i/300/420',
// //         'title': 'Season ${i + 1}',
// //         'episodes': (6 + i).toString(),
// //         'likes': (100 + i * 50).toString(),
// //       };
// //     });

// //     final isDark = Theme.of(context).brightness == Brightness.dark;

// //     return Container(
// //       margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 1),
// //       child: AnimatedContainer(
// //         duration: const Duration(milliseconds: 600),
// //         curve: Curves.easeInOut,
// //         padding: const EdgeInsets.all(16),
// //         decoration: BoxDecoration(
// //           gradient: LinearGradient(
// //             begin: Alignment.topLeft,
// //             end: Alignment.bottomRight,
// //             colors: [
// //               isDark ? const Color(0xFF2A2A2A) : Colors.white,
// //               isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
// //             ],
// //           ),
// //           borderRadius: BorderRadius.circular(20),
// //           boxShadow: [
// //             BoxShadow(
// //               color: isDark
// //                   ? Colors.black.withValues(alpha: 0.3)
// //                   : Colors.grey.withValues(alpha: 0.15),
// //               blurRadius: 20,
// //               offset: const Offset(0, 8),
// //             ),
// //             BoxShadow(
// //               color: isDark
// //                   ? Colors.white.withValues(alpha: 0.05)
// //                   : Colors.white.withValues(alpha: 0.8),
// //               blurRadius: 1,
// //               offset: const Offset(0, 1),
// //             ),
// //           ],
// //           border: Border.all(
// //             color: isDark
// //                 ? Colors.white.withValues(alpha: 0.1)
// //                 : Colors.grey.withValues(alpha: 0.1),
// //             width: 1,
// //           ),
// //         ),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             // Header Row
// //             Row(
// //               children: [
// //                 Text(
// //                   'Suggested Seasons',
// //                   style: Theme.of(context).textTheme.titleMedium!.copyWith(
// //                         fontWeight: FontWeight.bold,
// //                         color: isDark ? Colors.white : Colors.black87,
// //                       ),
// //                 ),
// //                 const Spacer(),
// //                 Text(
// //                   'See more',
// //                   style: TextStyle(
// //                     color: isDark ? Colors.white70 : Colors.black54,
// //                     fontSize: 12,
// //                     fontWeight: FontWeight.w500,
// //                   ),
// //                 ),
// //               ],
// //             ),
// //             const SizedBox(height: 16),

// //             // Horizontal List
// //             SizedBox(
// //               height: 180,
// //               child: ListView.separated(
// //                 scrollDirection: Axis.horizontal,
// //                 itemCount: seasons.length,
// //                 separatorBuilder: (_, __) => const SizedBox(width: 12),
// //                 itemBuilder: (context, index) {
// //                   final item = seasons[index];
// //                   return SeasonCard(
// //                     imageUrl: item['image']!,
// //                     title: item['title']!,
// //                     episodes: item['episodes']!,
// //                     likes: item['likes']!,
// //                   );
// //                 },
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }

// // class SeasonCard extends StatelessWidget {
// //   final String imageUrl;
// //   final String title;
// //   final String episodes;
// //   final String likes;

// //   const SeasonCard({
// //     super.key,
// //     required this.imageUrl,
// //     required this.title,
// //     required this.episodes,
// //     required this.likes,
// //   });

// //   @override
// //   Widget build(BuildContext context) {
// //     return Container(
// //       width: 120,
// //       height: 220,
// //       decoration: BoxDecoration(
// //         color: const Color(0xFF0F0F10),
// //         borderRadius: BorderRadius.circular(12),
// //         boxShadow: [
// //           BoxShadow(
// //             color: Colors.black.withValues(alpha: 0.45),
// //             blurRadius: 8,
// //             offset: const Offset(0, 4),
// //           ),
// //         ],
// //       ),
// //       child: ClipRRect(
// //         borderRadius: BorderRadius.circular(12),
// //         child: Stack(
// //           children: [
// //             Positioned.fill(
// //               child: Image.network(imageUrl, fit: BoxFit.cover),
// //             ),
// //             Positioned(
// //               left: 8,
// //               top: 8,
// //               child: Container(
// //                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
// //                 decoration: BoxDecoration(
// //                   color: const Color(0xFFD84315),
// //                   borderRadius: BorderRadius.circular(8),
// //                 ),
// //                 child: SvgPicture.asset(
// //                   'assets/svgs/lock.svg',
// //                   width: 12,
// //                   height: 12,
// //                 ),
// //               ),
// //             ),
// //             Positioned(
// //               left: 0,
// //               right: 0,
// //               bottom: 0,
// //               child: Container(
// //                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
// //                 decoration: BoxDecoration(
// //                   gradient: LinearGradient(
// //                     colors: [
// //                       Colors.black.withValues(alpha: 0.65),
// //                       Colors.black.withValues(alpha: 0.0),
// //                     ],
// //                     begin: Alignment.bottomCenter,
// //                     end: Alignment.topCenter,
// //                   ),
// //                 ),
// //                 child: Column(
// //                   mainAxisSize: MainAxisSize.min,
// //                   crossAxisAlignment: CrossAxisAlignment.start,
// //                   children: [
// //                     Text(
// //                       title,
// //                       style: TextStyle(
// //                         color: Colors.white,
// //                         fontWeight: FontWeight.w600,
// //                         fontSize: 13,
// //                       ),
// //                       maxLines: 1,
// //                       overflow: TextOverflow.ellipsis,
// //                     ),
// //                     const SizedBox(height: 6),
// //                     Row(
// //                       children: [
// //                         _StatIcon(
// //                             icon: Icons.fiber_manual_record, label: episodes),
// //                         const SizedBox(width: 8),
// //                         _StatIcon(icon: Icons.favorite_border, label: likes),
// //                         const Spacer(),
// //                       ],
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }

// // class _StatIcon extends StatelessWidget {
// //   final IconData icon;
// //   final String label;
// //   const _StatIcon({required this.icon, required this.label});

// //   @override
// //   Widget build(BuildContext context) {
// //     return Row(
// //       children: [
// //         Icon(icon, size: 12, color: Colors.white70),
// //         const SizedBox(width: 4),
// //         Text(
// //           label,
// //           style: const TextStyle(color: Colors.white70, fontSize: 12),
// //         ),
// //       ],
// //     );
// //   }
// // }
// import 'package:baakhapaa/helpers/helpers.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:provider/provider.dart';

// import '../../widgets/header.dart';
// import '../../providers/auth.dart';
// import '../../providers/story.dart';
// import '../../providers/shorts.dart';
// import './creator_story_screen.dart';
// import '../../widgets/loading.dart';
// import '../../utils/puppet_screen_mapping.dart';
// import '../../utils/debug_logger.dart';

// class CreatorsScreen extends StatefulWidget {
//   static const routeName = '/creators-screen';

//   const CreatorsScreen({Key? key}) : super(key: key);

//   @override
//   State<CreatorsScreen> createState() => _CreatorsScreenState();
// }

// class _CreatorsScreenState extends State<CreatorsScreen>
//     with PuppetInteractionMixin {
//   var _isInit = true;
//   var _isLoading = false;
//   var _isLoadingCounts = false;
//   late List<dynamic> _creators = [];
//   late List<dynamic> _filteredCreators = [];
//   GlobalKey keyNavigation = GlobalKey();

//   // Cache for creator counts (creatorId -> {storyCount, shortsCount})
//   final Map<int, Map<String, int>> _creatorCounts = {};

//   @override
//   void didChangeDependencies() {
//     if (_isInit) {
//       setState(() {
//         _isLoading = true;
//       });
//       var auth = Provider.of<Auth>(context, listen: false);
//       auth.fetchAllCreators().then((__) {
//         setState(() {
//           _creators = auth.creators;
//           _filteredCreators = _creators;
//           _isLoading = false;
//         });

//         // Start loading counts for first batch of creators
//         _loadInitialCounts();

//         // Debug: Log creator data structure
//         if (_creators.isNotEmpty) {
//           final firstCreator = _creators.first;
//           DebugLogger.info('📊 ===== CREATOR DATA DEBUG =====');
//           DebugLogger.info(
//               '📊 All creator keys: ${firstCreator.keys.toList()}');
//           DebugLogger.info('📊 Full creator object: $firstCreator');
//           DebugLogger.info(
//               '📊 story_count field: ${firstCreator['story_count']}');
//           DebugLogger.info(
//               '📊 shorts_count field: ${firstCreator['shorts_count']}');
//           DebugLogger.info(
//               '📊 stories_count field: ${firstCreator['stories_count']}');
//           DebugLogger.info(
//               '📊 seasons_count field: ${firstCreator['seasons_count']}');
//           DebugLogger.info(
//               '📊 short_count field: ${firstCreator['short_count']}');
//           DebugLogger.info(
//               '📊 total_stories field: ${firstCreator['total_stories']}');
//           DebugLogger.info(
//               '📊 total_shorts field: ${firstCreator['total_shorts']}');
//           DebugLogger.info(
//               '📊 Calculated story count: ${_getStoryCount(firstCreator)}');
//           DebugLogger.info(
//               '📊 Calculated shorts count: ${_getShortsCount(firstCreator)}');
//           DebugLogger.info('📊 ===========================');

//           // Check if counts are missing from ALL creators
//           final missingCounts = _creators.every((c) =>
//               c['story_count'] == null &&
//               c['shorts_count'] == null &&
//               c['stories_count'] == null &&
//               c['seasons_count'] == null);

//           if (missingCounts) {
//             DebugLogger.warning('⚠️ ========================================');
//             DebugLogger.warning(
//                 '⚠️ BACKEND ISSUE: story_count and shorts_count fields are MISSING from API');
//             DebugLogger.warning(
//                 '⚠️ All ${_creators.length} creators have 0 counts');
//             DebugLogger.warning(
//                 '⚠️ Please update backend API: /user/creators/all');
//             DebugLogger.warning('⚠️ ========================================');
//           }
//         }
//       }).catchError((error) {
//         setState(() {
//           _isLoading = false;
//         });
//         DebugLogger.error('❌ Failed to load storytellers: $error');
//         // Optionally show an error message
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//               content: Text('Failed to load storytellers. Please try again.')),
//         );
//       });
//     }
//     _isInit = false;
//     super.didChangeDependencies();
//   }

//   void _filterCreators(String query) {
//     setState(() {
//       _filteredCreators = _creators
//           .where((creator) =>
//               creator['username'].toLowerCase().contains(query.toLowerCase()))
//           .toList();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: header(context: context, titleText: context.l10n.storytellers),
//       body: RefreshIndicator(
//         onRefresh: _refreshCreators,
//         child: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topCenter,
//               end: Alignment.bottomCenter,
//               colors: [
//                 Theme.of(context).brightness == Brightness.dark
//                     ? Color.fromARGB(255, 9, 9, 9)
//                     : Colors.white,
//                 Theme.of(context).brightness == Brightness.dark
//                     ? Color(0xFF082032)
//                     : Color.fromARGB(255, 188, 186, 186),
//               ],
//             ),
//           ),
//           child: Column(
//             children: [
//               // Fixed header section (non-scrollable)
//               SubHeader(context: context),
//               SubscribeAds(context: context),
//               SearchSection(onSearchChanged: _filterCreators),
//               SearchFilterSection(onFilterChanged: _filterCreators),

//               // Scrollable content area
//               Expanded(
//                 child: _isLoading
//                     ? Container(
//                         margin: EdgeInsets.all(40),
//                         child: Loading(),
//                       )
//                     : SingleChildScrollView(
//                         physics: const BouncingScrollPhysics(
//                             parent: AlwaysScrollableScrollPhysics()),
//                         child: Column(
//                           children: [
//                             CreatorsGridSection(
//                               creators: _filteredCreators,
//                               getStoryCount: _getStoryCount,
//                               getShortsCount: _getShortsCount,
//                               isCountLoading: _isCountLoading,
//                             ),
//                             SizedBox(height: 30),
//                           ],
//                         ),
//                       ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _refreshCreators() async {
//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       var auth = Provider.of<Auth>(context, listen: false);
//       await auth.fetchAllCreators();

//       setState(() {
//         _creators = auth.creators;
//         _filteredCreators = _creators;
//         _isLoading = false;
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Storytellers refreshed successfully'),
//           backgroundColor: Colors.green,
//           duration: Duration(seconds: 2),
//         ),
//       );
//     } catch (error) {
//       setState(() {
//         _isLoading = false;
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Failed to refresh storytellers'),
//           backgroundColor: Colors.red,
//           duration: Duration(seconds: 2),
//         ),
//       );
//     }
//   }

//   void navToCreatorStoryScreen(BuildContext context, item) {
//     Navigator.of(context).pushNamed(
//       CreatorStoryScreen.routeName,
//       arguments: [
//         item['id'],
//         item['name'],
//       ],
//     );
//   }

//   /// Load counts for first batch of creators (visible on screen)
//   Future<void> _loadInitialCounts() async {
//     if (_creators.isEmpty || _isLoadingCounts) return;

//     setState(() {
//       _isLoadingCounts = true;
//     });

//     try {
//       // Load counts for first 10 creators in parallel
//       final firstBatch = _creators.take(10).toList();
//       await Future.wait(
//         firstBatch.map((creator) => _fetchCreatorCounts(creator['id'] as int)),
//         eagerError: false,
//       );

//       if (mounted) {
//         setState(() {
//           _isLoadingCounts = false;
//         });
//       }

//       // Load remaining creators in background
//       _loadRemainingCounts();
//     } catch (error) {
//       DebugLogger.error('Failed to load initial counts: $error');
//       if (mounted) {
//         setState(() {
//           _isLoadingCounts = false;
//         });
//       }
//     }
//   }

//   /// Load remaining counts in background (batched to avoid overwhelming API)
//   Future<void> _loadRemainingCounts() async {
//     if (_creators.length <= 10) return;

//     final remainingCreators = _creators.skip(10).toList();

//     // Load in batches of 5 to avoid overwhelming the API
//     for (var i = 0; i < remainingCreators.length; i += 5) {
//       if (!mounted) break;

//       final batch = remainingCreators.skip(i).take(5).toList();
//       await Future.wait(
//         batch.map((creator) => _fetchCreatorCounts(creator['id'] as int)),
//         eagerError: false,
//       );

//       // Small delay between batches to be API-friendly
//       await Future.delayed(Duration(milliseconds: 200));
//     }
//   }

//   /// Fetch actual counts from API for a specific creator
//   Future<void> _fetchCreatorCounts(int creatorId) async {
//     if (_creatorCounts.containsKey(creatorId)) {
//       return; // Already fetched
//     }

//     try {
//       DebugLogger.info('🔍 Fetching counts for creator ID: $creatorId');

//       final storyProvider = Provider.of<Story>(context, listen: false);
//       final shortsProvider = Provider.of<Shorts>(context, listen: false);

//       // Fetch creator's content
//       await Future.wait([
//         storyProvider.fetchCreatorSeasons(creatorId),
//         shortsProvider.fetchCreatorShorts(creatorId),
//       ]);

//       final storyCount = storyProvider.creatorSeasonsCount;
//       final shortsCount = shortsProvider.creatorShortsCount;

//       DebugLogger.info('📊 Creator $creatorId counts:');
//       DebugLogger.info('   📖 Story count: $storyCount');
//       DebugLogger.info('   ▶️ Shorts count: $shortsCount');

//       // Cache the counts
//       _creatorCounts[creatorId] = {
//         'storyCount': storyCount,
//         'shortsCount': shortsCount,
//       };

//       DebugLogger.info('✅ Cached counts for creator $creatorId');

//       // Update UI
//       if (mounted) {
//         setState(() {});
//       }
//     } catch (error) {
//       DebugLogger.error(
//           'Failed to fetch counts for creator $creatorId: $error');
//       // Set to 0 on error
//       _creatorCounts[creatorId] = {
//         'storyCount': 0,
//         'shortsCount': 0,
//       };
//     }
//   }

//   /// Helper method to safely extract story count from creator data
//   int _getStoryCount(Map<String, dynamic> creator) {
//     final creatorId = creator['id'] as int?;

//     // Return cached count if available
//     if (creatorId != null && _creatorCounts.containsKey(creatorId)) {
//       return _creatorCounts[creatorId]!['storyCount'] ?? 0;
//     }

//     // Check if backend provides count fields (future compatibility)
//     final candidateKeys = [
//       'story_count',
//       'stories_count',
//       'seasons_count',
//       'total_stories',
//       'storyCount',
//       'storiesCount',
//       'seasonsCount',
//       'totalStories',
//     ];

//     for (final key in candidateKeys) {
//       final value = creator[key];
//       if (value != null) {
//         if (value is int && value > 0) {
//           return value;
//         }
//         if (value is String) {
//           final parsed = int.tryParse(value);
//           if (parsed != null && parsed > 0) {
//             return parsed;
//           }
//         }
//       }
//     }

//     return 0;
//   }

//   /// Check if counts are being loaded for a creator
//   bool _isCountLoading(Map<String, dynamic> creator) {
//     final creatorId = creator['id'] as int?;
//     return creatorId != null && !_creatorCounts.containsKey(creatorId);
//   }

//   /// Helper method to safely extract shorts count from creator data
//   int _getShortsCount(Map<String, dynamic> creator) {
//     final creatorId = creator['id'] as int?;

//     // Return cached count if available
//     if (creatorId != null && _creatorCounts.containsKey(creatorId)) {
//       return _creatorCounts[creatorId]!['shortsCount'] ?? 0;
//     }

//     // Check if backend provides count fields (future compatibility)
//     final candidateKeys = [
//       'shorts_count',
//       'total_shorts',
//       'short_count',
//       'shortsCount',
//       'totalShorts',
//       'shortCount',
//     ];

//     for (final key in candidateKeys) {
//       final value = creator[key];
//       if (value != null) {
//         if (value is int && value > 0) {
//           return value;
//         }
//         if (value is String) {
//           final parsed = int.tryParse(value);
//           if (parsed != null && parsed > 0) {
//             return parsed;
//           }
//         }
//       }
//     }

//     return 0;
//   }
// }

// // ==========================================
// // Sub Header
// // ==========================================

// class SubHeader extends StatelessWidget {
//   final BuildContext context;

//   const SubHeader({Key? key, required this.context}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: EdgeInsets.only(left: 16, right: 16),
//       child: Row(
//         children: [
//           Text(
//             "All Storytellers",
//             style: GoogleFonts.poppins(
//               fontSize: 18,
//               fontWeight: FontWeight.w800,
//               color: Theme.of(context).brightness == Brightness.dark
//                   ? Colors.white
//                   : Color(0xFF082032),
//               fontStyle: FontStyle.italic,
//             ),
//             // textAlign: TextAlign.center,
//           ),
//           const Spacer(),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
//             decoration: BoxDecoration(
//               gradient: const LinearGradient(
//                 colors: [
//                   Color(0xFFFFDB58),
//                   Color(0xFFFFB40E),
//                 ],
//                 begin: Alignment.centerLeft,
//                 end: Alignment.centerRight,
//               ),
//               borderRadius: BorderRadius.circular(15.5),
//             ),
//             child: Row(
//               children: [
//                 const Image(
//                     image: AssetImage('assets/images/coins.png'),
//                     width: 17.36,
//                     height: 17.36),
//                 const SizedBox(width: 5),
//                 Text(
//                   '${Provider.of<Auth>(context).userAvailableCoins.toString()}',
//                   style: GoogleFonts.poppins(
//                     fontSize: 14,
//                     fontWeight: FontWeight.bold,
//                     // letterSpacing: 0.5,
//                   ),
//                 ),
//                 const SizedBox(width: 4),
//                 Text(
//                   'Bpts',
//                   style: GoogleFonts.poppins(
//                     fontSize: 12,
//                     fontWeight: FontWeight.w400,
//                     // letterSpacing: 0.5,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
// // ==========================================
// // Ads
// // ==========================================

// class SubscribeAds extends StatelessWidget {
//   final BuildContext context;

//   const SubscribeAds({Key? key, required this.context}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: () {
//         Navigator.of(context).pushNamed('/subscription-screen');
//       },
//       child: Image.asset(
//         'assets/images/ads.png',
//         fit: BoxFit.cover,

//         // width: double.infinity,
//         // height: double.infinity,
//       ),
//     );
//   }
// }

// // ==========================================
// // SEARCH SECTION COMPONENT
// // ==========================================
// class SearchSection extends StatelessWidget {
//   final Function(String) onSearchChanged;

//   const SearchSection({
//     Key? key,
//     required this.onSearchChanged,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(0.0),
//       child: Container(
//         margin: EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 16),
//         decoration: BoxDecoration(
//           color: Theme.of(context).brightness == Brightness.dark
//               ? Color(0xFF1A1A1A)
//               : Colors.grey.shade50,
//           borderRadius: BorderRadius.circular(50),
//           // border: Border.all(
//           //     // color: Colors.grey.withValues(alpha: 0.2),
//           //     // width: 1,
//           //     ),
//         ),
//         child: TextField(
//           onChanged: onSearchChanged,
//           style: TextStyle(
//             color: Theme.of(context).brightness == Brightness.dark
//                 ? Colors.white
//                 : Colors.black87,
//           ),
//           decoration: InputDecoration(
//             hintText: '${context.l10n.search} ${context.l10n.storytellers}...',
//             hintStyle: TextStyle(
//               color: Colors.grey[500],
//             ),
//             prefixIcon: Icon(
//               Icons.search,
//               color: Colors.grey[500],
//             ),
//             border: InputBorder.none,
//             focusedBorder: InputBorder.none,
//             enabledBorder: InputBorder.none,
//             contentPadding: EdgeInsets.all(16),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ==========================================
// // SEARCH FILTER COMPONENT
// // ==========================================
// class SearchFilterSection extends StatefulWidget {
//   final Function(String) onFilterChanged;

//   const SearchFilterSection({
//     Key? key,
//     required this.onFilterChanged,
//   }) : super(key: key);

//   @override
//   _SearchFilterSectionState createState() => _SearchFilterSectionState();
// }

// class _SearchFilterSectionState extends State<SearchFilterSection> {
//   String selectedFilter = 'All';
//   final List<String> filterOptions = [
//     'All',
//     'Most Popular',
//     'Recent',
//     'Top Rated',
//     'Following',
//     'Trending'
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: EdgeInsets.only(left: 16, right: 16, bottom: 16),
//       height: 40,
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         child: Row(
//           children: filterOptions.map((filter) {
//             bool isSelected = selectedFilter == filter;
//             return Container(
//               margin: EdgeInsets.only(right: 8),
//               child: ElevatedButton(
//                 onPressed: () {
//                   setState(() {
//                     selectedFilter = filter;
//                   });
//                   widget.onFilterChanged(filter.toLowerCase());
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor:
//                       isSelected ? Colors.white : Colors.grey[800],
//                   foregroundColor: isSelected ? Colors.black : Colors.white,
//                   elevation: 2,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 ),
//                 child: Text(
//                   filter,
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//               ),
//             );
//           }).toList(),
//         ),
//       ),
//     );
//   }
// }

// // ==========================================
// // CREATORS GRID SECTION COMPONENT
// // ==========================================
// class CreatorsGridSection extends StatelessWidget {
//   final List<dynamic> creators;
//   final int Function(Map<String, dynamic>) getStoryCount;
//   final int Function(Map<String, dynamic>) getShortsCount;
//   final bool Function(Map<String, dynamic>) isCountLoading;

//   const CreatorsGridSection({
//     Key? key,
//     required this.creators,
//     required this.getStoryCount,
//     required this.getShortsCount,
//     required this.isCountLoading,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     if (creators.isEmpty) {
//       return EmptyCreatorsState();
//     }

//     return Container(
//       margin: EdgeInsets.symmetric(horizontal: 16),
//       child: GridView.builder(
//         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 2,
//           crossAxisSpacing: 16,
//           mainAxisSpacing: 16,
//           childAspectRatio: 0.8,
//         ),
//         shrinkWrap: true,
//         physics: NeverScrollableScrollPhysics(),
//         itemCount: creators.length,
//         itemBuilder: (context, index) {
//           final creator = creators[index];
//           return CreatorCard(
//             creator: creator,
//             getStoryCount: getStoryCount,
//             getShortsCount: getShortsCount,
//             isCountLoading: isCountLoading,
//           );
//         },
//       ),
//     );
//   }
// }

// // ==========================================
// // EMPTY STATE COMPONENT
// // ==========================================
// class EmptyCreatorsState extends StatelessWidget {
//   const EmptyCreatorsState({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: EdgeInsets.all(16),
//       padding: EdgeInsets.all(40),
//       decoration: BoxDecoration(
//         color: Theme.of(context).brightness == Brightness.dark
//             ? Color(0xFF2A2A2A)
//             : Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withValues(alpha: 0.1),
//             blurRadius: 8,
//             spreadRadius: 1,
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           Icon(
//             Icons.person_search,
//             size: 64,
//             color: Colors.grey[400],
//           ),
//           SizedBox(height: 16),
//           Text(
//             'No storytellers found',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.w600,
//               color: Colors.grey[600],
//             ),
//           ),
//           SizedBox(height: 8),
//           Text(
//             'Try adjusting your search terms',
//             style: TextStyle(
//               fontSize: 14,
//               color: Colors.grey[500],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ==========================================
// // CREATOR CARD COMPONENT
// // ==========================================
// class CreatorCard extends StatelessWidget {
//   final Map<String, dynamic> creator;
//   final int Function(Map<String, dynamic>) getStoryCount;
//   final int Function(Map<String, dynamic>) getShortsCount;
//   final bool Function(Map<String, dynamic>) isCountLoading;

//   const CreatorCard({
//     Key? key,
//     required this.creator,
//     required this.getStoryCount,
//     required this.getShortsCount,
//     required this.isCountLoading,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: () {
//         Navigator.of(context).pushNamed(
//           CreatorStoryScreen.routeName,
//           arguments: [
//             creator['id'],
//             creator['name'],
//           ],
//         );
//       },
//       child: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [
//               Theme.of(context).brightness == Brightness.dark
//                   ? Color.fromARGB(255, 0, 0, 0)
//                   : Colors.white,
//               Theme.of(context).brightness == Brightness.dark
//                   ? Color.fromARGB(255, 0, 0, 0)
//                   : Colors.grey.shade50,
//             ],
//           ),
//           borderRadius: BorderRadius.circular(20),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.grey.withValues(alpha: 0.15),
//               blurRadius: 12,
//               spreadRadius: 2,
//               offset: Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Stack(
//           children: [
//             // Full-size creator image
//             CreatorAvatar(creator: creator),

//             // Bottom overlay with username and points
//             Positioned(
//               bottom: 0,
//               left: 0,
//               right: 0,
//               child: Container(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                     colors: [
//                       Colors.transparent,
//                       Colors.black.withOpacity(0.8),
//                     ],
//                   ),
//                   borderRadius: BorderRadius.only(
//                     bottomLeft: Radius.circular(20),
//                     bottomRight: Radius.circular(20),
//                   ),
//                 ),
//                 padding: EdgeInsets.all(12),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     // Username
//                     CreatorUsername(username: creator['username']),
//                     SizedBox(height: 8),
//                     // Multiple colored badges row
//                     Row(
//                       children: [
//                         // Points badge (yellow)
//                         CreatorPointsBadge(points: creator['total_points']),
//                         Spacer(),
//                         // Purple badge - Stories count
//                         StoryCountBadge(
//                           count: getStoryCount(creator),
//                           isLoading: isCountLoading(creator),
//                         ),

//                         Spacer(),
//                         // Red badge - Shorts count
//                         ShortsCountBadge(
//                           count: getShortsCount(creator),
//                           isLoading: isCountLoading(creator),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ==========================================
// // CREATOR AVATAR COMPONENT
// // ==========================================
// class CreatorAvatar extends StatelessWidget {
//   final Map<String, dynamic> creator;

//   const CreatorAvatar({
//     Key? key,
//     required this.creator,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         // Full container image
//         Positioned.fill(
//           child: ClipRRect(
//             borderRadius: BorderRadius.circular(20),
//             child: CachedNetworkImage(
//               imageUrl: creator['images'] != null &&
//                       creator['images'].isNotEmpty
//                   ? creator['images'][0]['thumbnail']
//                   : 'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg',
//               fit: BoxFit.cover,
//               placeholder: (context, url) => Container(
//                 color: Colors.grey.shade300,
//                 child: Center(
//                   child: CircularProgressIndicator(
//                     valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
//                     strokeWidth: 2,
//                   ),
//                 ),
//               ),
//               errorWidget: (context, url, error) => Container(
//                 color: Colors.grey.shade800,
//                 child: Center(
//                   child: Icon(
//                     Icons.person,
//                     size: 40,
//                     color: Colors.white,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),

//         // Creator badge in top right corner
//         // Positioned(
//         //   top: 12,
//         //   right: 12,
//         //   child: Container(
//         //     padding: EdgeInsets.all(6),
//         //     decoration: BoxDecoration(
//         //       color: Colors.purple,
//         //       shape: BoxShape.circle,
//         //       boxShadow: [
//         //         BoxShadow(
//         //           color: Colors.black.withOpacity(0.3),
//         //           blurRadius: 4,
//         //           offset: Offset(0, 2),
//         //         ),
//         //       ],
//         //     ),
//         //     child: Icon(
//         //       Icons.video_camera_front,
//         //       color: Colors.white,
//         //       size: 14,
//         //     ),
//         //   ),
//         // ),
//       ],
//     );
//   }
// }

// // ==========================================
// // CREATOR USERNAME COMPONENT
// // ==========================================
// class CreatorUsername extends StatelessWidget {
//   final String username;

//   const CreatorUsername({
//     Key? key,
//     required this.username,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Flexible(
//           child: Text(
//             "$username",
//             style: GoogleFonts.poppins(
//               fontSize: 12,
//               fontWeight: FontWeight.w800,
//               color: Theme.of(context).brightness == Brightness.dark
//                   ? Colors.white
//                   : Color(0xFF082032),
//             ),
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//           ),
//         ),
//         const SizedBox(width: 6),
//         // Container(
//         //   padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//         //   decoration: BoxDecoration(
//         //     color: Colors.purple,
//         //     borderRadius: BorderRadius.circular(12),
//         //   ),
//         //   child: Text(
//         //     'Follow',
//         //     style: TextStyle(
//         //       color: Colors.white,
//         //       fontWeight: FontWeight.bold,
//         //       fontSize: 10,
//         //     ),
//         //   ),
//         // ),
//       ],
//     );
//   }
// }

// // ==========================================
// // CREATOR POINTS BADGE COMPONENT
// // ==========================================
// class CreatorPointsBadge extends StatelessWidget {
//   final dynamic points;

//   const CreatorPointsBadge({
//     Key? key,
//     required this.points,
//   }) : super(key: key);

//   String _formatPoints(dynamic points) {
//     if (points == null) return '0';

//     int pointValue = points is String ? int.tryParse(points) ?? 0 : points;

//     if (pointValue >= 100000) {
//       return '${(pointValue / 100000).toStringAsFixed(1)}M';
//     } else if (pointValue >= 1000) {
//       return '${(pointValue / 1000).toStringAsFixed(1)}K';
//     } else {
//       return pointValue.toString();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Color(0xFFFFDB58), Color(0xFFFFB40E)],
//           begin: Alignment.centerLeft,
//           end: Alignment.centerRight,
//         ),
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.2),
//             blurRadius: 3,
//             offset: Offset(0, 1),
//           ),
//         ],
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Image.asset(
//             'assets/images/coins.png',
//             width: 12,
//             height: 12,
//           ),
//           SizedBox(width: 3),
//           Text(
//             points == null ? '0' : _formatPoints(points),
//             style: TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//               fontSize: 12,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class StoryCountBadge extends StatelessWidget {
//   final dynamic count;
//   final bool isLoading;

//   const StoryCountBadge({
//     Key? key,
//     required this.count,
//     this.isLoading = false,
//   }) : super(key: key);

//   String _formatPoints(dynamic points) {
//     if (points == null) return '0';

//     int pointValue = points is String ? int.tryParse(points) ?? 0 : points;

//     if (pointValue >= 100000) {
//       return '${(pointValue / 100000).toStringAsFixed(1)}M';
//     } else if (pointValue >= 1000) {
//       return '${(pointValue / 1000).toStringAsFixed(1)}K';
//     } else {
//       return pointValue.toString();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Color(0xFFF9F5FF), Color(0xFF9191FD)],
//           begin: Alignment.centerLeft,
//           end: Alignment.centerRight,
//         ),
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.2),
//             blurRadius: 3,
//             offset: Offset(0, 1),
//           ),
//         ],
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Image.asset(
//             'assets/images/story-playlist.png',
//             width: 12,
//             height: 12,
//             fit: BoxFit.cover,
//           ),
//           SizedBox(width: 3),
//           isLoading
//               ? SizedBox(
//                   width: 12,
//                   height: 12,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                   ),
//                 )
//               : Text(
//                   count == null ? '0' : _formatPoints(count),
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 12,
//                   ),
//                 ),
//         ],
//       ),
//     );
//   }
// }

// class ShortsCountBadge extends StatelessWidget {
//   final dynamic count;
//   final bool isLoading;

//   const ShortsCountBadge({
//     Key? key,
//     required this.count,
//     this.isLoading = false,
//   }) : super(key: key);

//   String _formatPoints(dynamic points) {
//     if (points == null) return '0';

//     int pointValue = points is String ? int.tryParse(points) ?? 0 : points;

//     if (pointValue >= 100000) {
//       return '${(pointValue / 100000).toStringAsFixed(1)}M';
//     } else if (pointValue >= 1000) {
//       return '${(pointValue / 1000).toStringAsFixed(1)}K';
//     } else {
//       return pointValue.toString();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Color(0xFF990000), Color(0xFFFF0000)],
//           begin: Alignment.centerLeft,
//           end: Alignment.centerRight,
//         ),
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.2),
//             blurRadius: 3,
//             offset: Offset(0, 1),
//           ),
//         ],
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             child: const Icon(Icons.play_circle,
//                 color: Color.fromARGB(255, 255, 255, 255), size: 14),
//           ),
//           SizedBox(width: 3),
//           isLoading
//               ? SizedBox(
//                   width: 12,
//                   height: 12,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                   ),
//                 )
//               : Text(
//                   count == null ? '0' : _formatPoints(count),
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 12,
//                   ),
//                 ),
//         ],
//       ),
//     );
//   }
// }


// //////////////////////
// // OLD CODE
// ///////////////////////



// // import 'package:baakhapaa/widgets/tutorials.dart';
// // import 'package:baakhapaa/helpers/helpers.dart';
// // import 'package:cached_network_image/cached_network_image.dart';
// // import 'package:flutter/material.dart';
// // import 'package:provider/provider.dart';

// // import '../../widgets/header.dart';
// // import '../../providers/auth.dart';
// // import './creator_story_screen.dart';
// // import '../../widgets/loading.dart';
// // import '../../utils/puppet_screen_mapping.dart';

// // class CreatorsScreen extends StatefulWidget {
// //   static const routeName = '/creators-screen';

// //   const CreatorsScreen({Key? key}) : super(key: key);

// //   @override
// //   State<CreatorsScreen> createState() => _CreatorsScreenState();
// // }

// // class _CreatorsScreenState extends State<CreatorsScreen>
// //     with PuppetInteractionMixin {
// //   var _isInit = true;
// //   var _isLoading = false;
// //   late List<dynamic> _creators = [];
// //   late List<dynamic> _filteredCreators = [];
// //   GlobalKey keyNavigation = GlobalKey();

// //   @override
// //   void didChangeDependencies() {
// //     if (_isInit) {
// //       setState(() {
// //         _isLoading = true;
// //       });
// //       var auth = Provider.of<Auth>(context, listen: false);
// //       auth.fetchAllCreators().then((__) {
// //         setState(() {
// //           _creators = auth.creators;
// //           _filteredCreators = _creators;
// //           _isLoading = false;
// //         });
// //       }).catchError((error) {
// //         setState(() {
// //           _isLoading = false;
// //         });
// //         // Optionally show an error message
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(
// //               content: Text('Failed to load storytellers. Please try again.')),
// //         );
// //       });
// //     }
// //     _isInit = false;
// //     super.didChangeDependencies();
// //   }

// //   void _filterCreators(String query) {
// //     setState(() {
// //       _filteredCreators = _creators
// //           .where((creator) =>
// //               creator['username'].toLowerCase().contains(query.toLowerCase()))
// //           .toList();
// //     });
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: header(context: context, titleText: context.l10n.storytellers),
// //       body: RefreshIndicator(
// //         onRefresh: _refreshCreators,
// //         child: SingleChildScrollView(
// //           physics: const BouncingScrollPhysics(
// //               parent: AlwaysScrollableScrollPhysics()),
// //           child: Container(
// //             decoration: BoxDecoration(
// //               gradient: LinearGradient(
// //                 begin: Alignment.topCenter,
// //                 end: Alignment.bottomCenter,
// //                 colors: [
// //                   Theme.of(context).brightness == Brightness.dark
// //                       ? Color.fromARGB(255, 9, 9, 9)
// //                       : Colors.white,
// //                   Theme.of(context).brightness == Brightness.dark
// //                       ? Color(0xFF082032)
// //                       : Color.fromARGB(255, 188, 186, 186),
// //                 ],
// //               ),
// //             ),
// //             child: Column(
// //               children: [
// //                 SizedBox(height: 16),

// //                 // Search Section with modern design
// //                 _buildSearchSection(),

// //                 // Creators Grid Section
// //                 _isLoading
// //                     ? Container(
// //                         margin: EdgeInsets.all(40),
// //                         child: Loading(),
// //                       )
// //                     : _buildCreatorsGrid(),

// //                 SizedBox(height: 30),
// //               ],
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }

// //   Future<void> _refreshCreators() async {
// //     setState(() {
// //       _isLoading = true;
// //     });

// //     try {
// //       var auth = Provider.of<Auth>(context, listen: false);
// //       await auth.fetchAllCreators();

// //       setState(() {
// //         _creators = auth.creators;
// //         _filteredCreators = _creators;
// //         _isLoading = false;
// //       });

// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(
// //           content: Text('Storytellers refreshed successfully'),
// //           backgroundColor: Colors.green,
// //           duration: Duration(seconds: 2),
// //         ),
// //       );
// //     } catch (error) {
// //       setState(() {
// //         _isLoading = false;
// //       });

// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(
// //           content: Text('Failed to refresh storytellers'),
// //           backgroundColor: Colors.red,
// //           duration: Duration(seconds: 2),
// //         ),
// //       );
// //     }
// //   }

// //   Widget _buildSearchSection() {
// //     return Container(
// //       margin: EdgeInsets.all(16),
// //       padding: EdgeInsets.all(20),
// //       decoration: BoxDecoration(
// //         gradient: LinearGradient(
// //           begin: Alignment.topLeft,
// //           end: Alignment.bottomRight,
// //           colors: [
// //             Theme.of(context).brightness == Brightness.dark
// //                 ? Color(0xFF2A2A2A)
// //                 : Colors.white,
// //             Theme.of(context).brightness == Brightness.dark
// //                 ? Color(0xFF1E1E1E)
// //                 : Colors.grey.shade50,
// //           ],
// //         ),
// //         borderRadius: BorderRadius.circular(20),
// //         boxShadow: [
// //           BoxShadow(
// //             color: Colors.grey.withValues(alpha: 0.2),
// //             blurRadius: 10,
// //             spreadRadius: 2,
// //           ),
// //         ],
// //       ),
// //       child: Column(
// //         children: [
// //           Row(
// //             children: [
// //               Container(
// //                 padding: EdgeInsets.all(10),
// //                 decoration: BoxDecoration(
// //                   gradient: LinearGradient(
// //                     colors: [Colors.purple.shade400, Colors.purple.shade600],
// //                   ),
// //                   borderRadius: BorderRadius.circular(12),
// //                 ),
// //                 child: Icon(
// //                   Icons.search,
// //                   color: Colors.white,
// //                   size: 24,
// //                 ),
// //               ),
// //               SizedBox(width: 16),
// //               Expanded(
// //                 child: Column(
// //                   crossAxisAlignment: CrossAxisAlignment.start,
// //                   children: [
// //                     Text(
// //                       '${context.l10n.find} ${context.l10n.storytellers}',
// //                       style: TextStyle(
// //                         fontSize: 20,
// //                         fontWeight: FontWeight.bold,
// //                         color: Theme.of(context).brightness == Brightness.dark
// //                             ? Colors.white
// //                             : Color(0xFF082032),
// //                       ),
// //                     ),
// //                     Text(
// //                       context.l10n.findStorytellers,
// //                       style: TextStyle(
// //                         fontSize: 14,
// //                         fontWeight: FontWeight.w500,
// //                         color: Colors.grey[600],
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //             ],
// //           ),
// //           SizedBox(height: 20),
// //           Container(
// //             decoration: BoxDecoration(
// //               color: Theme.of(context).brightness == Brightness.dark
// //                   ? Color(0xFF1A1A1A)
// //                   : Colors.grey.shade50,
// //               borderRadius: BorderRadius.circular(16),
// //               border: Border.all(
// //                 color: Colors.grey.withValues(alpha: 0.2),
// //                 width: 1,
// //               ),
// //             ),
// //             child: TextField(
// //               onChanged: _filterCreators,
// //               style: TextStyle(
// //                 color: Theme.of(context).brightness == Brightness.dark
// //                     ? Colors.white
// //                     : Colors.black87,
// //               ),
// //               decoration: InputDecoration(
// //                 hintText:
// //                     '${context.l10n.search} ${context.l10n.storytellers}...',
// //                 hintStyle: TextStyle(
// //                   color: Colors.grey[500],
// //                 ),
// //                 prefixIcon: Icon(
// //                   Icons.search,
// //                   color: Colors.grey[500],
// //                 ),
// //                 border: InputBorder.none,
// //                 contentPadding: EdgeInsets.all(16),
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildCreatorsGrid() {
// //     if (_filteredCreators.isEmpty) {
// //       return Container(
// //         margin: EdgeInsets.all(16),
// //         padding: EdgeInsets.all(40),
// //         decoration: BoxDecoration(
// //           color: Theme.of(context).brightness == Brightness.dark
// //               ? Color(0xFF2A2A2A)
// //               : Colors.white,
// //           borderRadius: BorderRadius.circular(16),
// //           boxShadow: [
// //             BoxShadow(
// //               color: Colors.grey.withValues(alpha: 0.1),
// //               blurRadius: 8,
// //               spreadRadius: 1,
// //             ),
// //           ],
// //         ),
// //         child: Column(
// //           children: [
// //             Icon(
// //               Icons.person_search,
// //               size: 64,
// //               color: Colors.grey[400],
// //             ),
// //             SizedBox(height: 16),
// //             Text(
// //               'No storytellers found',
// //               style: TextStyle(
// //                 fontSize: 18,
// //                 fontWeight: FontWeight.w600,
// //                 color: Colors.grey[600],
// //               ),
// //             ),
// //             SizedBox(height: 8),
// //             Text(
// //               'Try adjusting your search terms',
// //               style: TextStyle(
// //                 fontSize: 14,
// //                 color: Colors.grey[500],
// //               ),
// //             ),
// //           ],
// //         ),
// //       );
// //     }

// //     return Container(
// //       margin: EdgeInsets.symmetric(horizontal: 16),
// //       child: GridView.builder(
// //         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
// //           crossAxisCount: 2,
// //           crossAxisSpacing: 16,
// //           mainAxisSpacing: 16,
// //           childAspectRatio: 0.8,
// //         ),
// //         shrinkWrap: true,
// //         physics: NeverScrollableScrollPhysics(),
// //         itemCount: _filteredCreators.length,
// //         itemBuilder: (context, index) {
// //           final item = _filteredCreators[index];
// //           return _buildCreatorCard(item);
// //         },
// //       ),
// //     );
// //   }

// //   Widget _buildCreatorCard(Map<String, dynamic> creator) {
// //     return GestureDetector(
// //       onTap: () {
// //         Navigator.of(context).pushNamed(
// //           CreatorStoryScreen.routeName,
// //           arguments: [
// //             creator['id'],
// //             creator['name'],
// //           ],
// //         );
// //       },
// //       child: Container(
// //         decoration: BoxDecoration(
// //           gradient: LinearGradient(
// //             begin: Alignment.topLeft,
// //             end: Alignment.bottomRight,
// //             colors: [
// //               Theme.of(context).brightness == Brightness.dark
// //                   ? Color(0xFF2A2A2A)
// //                   : Colors.white,
// //               Theme.of(context).brightness == Brightness.dark
// //                   ? Color(0xFF1E1E1E)
// //                   : Colors.grey.shade50,
// //             ],
// //           ),
// //           borderRadius: BorderRadius.circular(20),
// //           boxShadow: [
// //             BoxShadow(
// //               color: Colors.grey.withValues(alpha: 0.15),
// //               blurRadius: 12,
// //               spreadRadius: 2,
// //               offset: Offset(0, 4),
// //             ),
// //           ],
// //         ),
// //         child: Column(
// //           children: [
// //             SizedBox(height: 20),

// //             // Profile Picture with modern styling
// //             Stack(
// //               alignment: Alignment.bottomRight,
// //               children: [
// //                 Container(
// //                   width: 70,
// //                   height: 70,
// //                   decoration: BoxDecoration(
// //                     shape: BoxShape.circle,
// //                     gradient: LinearGradient(
// //                       begin: Alignment.topLeft,
// //                       end: Alignment.bottomRight,
// //                       colors: [Colors.amber, Colors.orange],
// //                     ),
// //                     boxShadow: [
// //                       BoxShadow(
// //                         color: Colors.amber.withValues(alpha: 0.3),
// //                         blurRadius: 10,
// //                         spreadRadius: 2,
// //                       ),
// //                     ],
// //                   ),
// //                   padding: EdgeInsets.all(3),
// //                   child: ClipOval(
// //                     child: CachedNetworkImage(
// //                       imageUrl: creator['images'] != null &&
// //                               creator['images'].isNotEmpty
// //                           ? creator['images'][0]['thumbnail']
// //                           : 'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg',
// //                       fit: BoxFit.cover,
// //                       placeholder: (context, url) => Container(
// //                         color: Colors.grey.shade300,
// //                         child: CircularProgressIndicator(
// //                           valueColor:
// //                               AlwaysStoppedAnimation<Color>(Colors.amber),
// //                           strokeWidth: 2,
// //                         ),
// //                       ),
// //                       errorWidget: (context, url, error) => Container(
// //                         color: Colors.amber.withValues(alpha: 0.1),
// //                         child: Icon(
// //                           Icons.person,
// //                           size: 30,
// //                           color: Colors.amber,
// //                         ),
// //                       ),
// //                     ),
// //                   ),
// //                 ),

// //                 // Creator badge
// //                 Container(
// //                   padding: EdgeInsets.all(4),
// //                   decoration: BoxDecoration(
// //                     color: Colors.purple,
// //                     shape: BoxShape.circle,
// //                     border: Border.all(
// //                       color: Theme.of(context).brightness == Brightness.dark
// //                           ? Color(0xFF2A2A2A)
// //                           : Colors.white,
// //                       width: 2,
// //                     ),
// //                   ),
// //                   child: Icon(
// //                     Icons.video_camera_front,
// //                     color: Colors.white,
// //                     size: 12,
// //                   ),
// //                 ),
// //               ],
// //             ),

// //             SizedBox(height: 16),

// //             // Username
// //             Padding(
// //               padding: EdgeInsets.symmetric(horizontal: 12),
// //               child: Text(
// //                 "@${creator['username']}",
// //                 style: TextStyle(
// //                   fontSize: 16,
// //                   fontWeight: FontWeight.bold,
// //                   color: Theme.of(context).brightness == Brightness.dark
// //                       ? Colors.white
// //                       : Color(0xFF082032),
// //                 ),
// //                 textAlign: TextAlign.center,
// //                 maxLines: 1,
// //                 overflow: TextOverflow.ellipsis,
// //               ),
// //             ),

// //             SizedBox(height: 8),

// //             // Points badge
// //             Container(
// //               padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
// //               margin: EdgeInsets.symmetric(horizontal: 12),
// //               decoration: BoxDecoration(
// //                 gradient: LinearGradient(
// //                   colors: [Colors.amber.shade300, Colors.amber.shade600],
// //                   begin: Alignment.topLeft,
// //                   end: Alignment.bottomRight,
// //                 ),
// //                 borderRadius: BorderRadius.circular(20),
// //                 boxShadow: [
// //                   BoxShadow(
// //                     color: Colors.amber.withValues(alpha: 0.3),
// //                     blurRadius: 5,
// //                     spreadRadius: 0,
// //                     offset: Offset(0, 2),
// //                   ),
// //                 ],
// //               ),
// //               child: Row(
// //                 mainAxisAlignment: MainAxisAlignment.center,
// //                 mainAxisSize: MainAxisSize.min,
// //                 children: [
// //                   Image.asset(
// //                     'assets/images/coins.png',
// //                     width: 14,
// //                     height: 14,
// //                   ),
// //                   SizedBox(width: 4),
// //                   Flexible(
// //                     child: Text(
// //                       creator['total_points'] == null
// //                           ? 'no points'
// //                           : '${creator['total_points']} pts',
// //                       style: TextStyle(
// //                         color: Colors.white,
// //                         fontWeight: FontWeight.bold,
// //                         fontSize: 12,
// //                       ),
// //                       overflow: TextOverflow.ellipsis,
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),

// //             SizedBox(height: 16),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   void navToCreatorStoryScreen(BuildContext context, item) {
// //     Navigator.of(context).pushNamed(
// //       CreatorStoryScreen.routeName,
// //       arguments: [
// //         item['id'],
// //         item['name'],
// //       ],
// //     );
// //   }
// // }
