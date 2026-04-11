import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_ne.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('ja'),
    Locale('ko'),
    Locale('ne'),
    Locale('zh')
  ];

  /// The title of the application.
  ///
  /// In en, this message translates to:
  /// **'BAAKHAPAA'**
  String get appTitle;

  /// Text for a button to select a language.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// Label for language selection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Label for currency selection.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// Button to pause playback.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// Button to start playback.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// Message displayed while content is loading.
  ///
  /// In en, this message translates to:
  /// **'loading'**
  String get loading;

  /// A generic error message.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get error;

  /// A label for the application.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get app;

  /// A category for short-form videos.
  ///
  /// In en, this message translates to:
  /// **'Shorts'**
  String get shorts;

  /// A menu item to navigate to the shop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shop;

  /// A menu item to navigate to the settings page.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// A menu item to navigate to the messages or chat page.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// A menu item to navigate to the user profile page.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// A label for a single story.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get story;

  /// A category for multiple stories.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get stories;

  /// A menu item for the application's store.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get store;

  /// A category for content creators.
  ///
  /// In en, this message translates to:
  /// **'Creators'**
  String get creators;

  /// A specific type of content, possibly a blend of 'shorts' and 'chats'.
  ///
  /// In en, this message translates to:
  /// **'Stat\'s'**
  String get shats;

  /// Label related to the referral program.
  ///
  /// In en, this message translates to:
  /// **'Referral'**
  String get referral;

  /// Label for a code, such as a referral code.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// A menu item to view notifications.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notification;

  /// A menu item for the user's digital wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// Indicates something is currently in use or happening.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// A category for user challenges or quests.
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get challenges;

  /// A button or label to view an item.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// Used to show all items in a category.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// A category for user accomplishments.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievements;

  /// A label indicating a user's current level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// A label to show progress towards a goal.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// A button to go to the next item or step.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// A label for a user's role or title.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// A button to share content.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// A button or label for contact information.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// Part of 'Contact Us' or 'About Us'.
  ///
  /// In en, this message translates to:
  /// **'Us'**
  String get us;

  /// A button or label for a user review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// A menu item to view the leaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboard;

  /// A label for a sum or total amount.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// A label for the count of users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// A label for the number of referrals.
  ///
  /// In en, this message translates to:
  /// **'Referrals'**
  String get referrals;

  /// Used to denote a top list or ranking.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get top;

  /// A possessive pronoun, e.g., 'Your Cart'.
  ///
  /// In en, this message translates to:
  /// **'Your'**
  String get your;

  /// A menu item or page for the shopping cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// Indicates that a list or container is empty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get empty;

  /// A negative word, e.g., 'No items found'.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// Indicates an item was located, e.g., 'No items found'.
  ///
  /// In en, this message translates to:
  /// **'Found'**
  String get found;

  /// A button or label to update something.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// Label for an image.
  ///
  /// In en, this message translates to:
  /// **'Picture'**
  String get picture;

  /// A label for a gift or reward.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get gift;

  /// A category for user rewards.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get rewards;

  /// An adjective to describe something as amazing.
  ///
  /// In en, this message translates to:
  /// **'Amazing'**
  String get amazing;

  /// A preposition to join two phrases, e.g., 'Redeem with points'.
  ///
  /// In en, this message translates to:
  /// **'With'**
  String get withString;

  /// A label for a currency or point system.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// A preposition to indicate source.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// The name of the app or brand.
  ///
  /// In en, this message translates to:
  /// **'Baakhapa'**
  String get baakhapa;

  /// A button to discover new content.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// A label to indicate there are more items.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// Indicates a message or item has not been read yet.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unread;

  /// Indicates a message or item has been read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// A category for products in a store.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// Indicates something is ready for use or purchase.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// A possessive pronoun, e.g., 'My Profile'.
  ///
  /// In en, this message translates to:
  /// **'My'**
  String get my;

  /// A prompt to make a selection.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// A label for user-generated content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get content;

  /// A button to select an option.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// A label for a video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// A label for a photo/video gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// A button or action to record something.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get record;

  /// Indicates an item is new.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newString;

  /// The number one, often used for singular items.
  ///
  /// In en, this message translates to:
  /// **'One'**
  String get one;

  /// A label for a single content creator.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get creator;

  /// A menu item for a specific portal, e.g., 'Creator Portal'.
  ///
  /// In en, this message translates to:
  /// **'Portal'**
  String get portal;

  /// A button or label to gain access to something.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get access;

  /// An adjective to describe a feature as advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// A label for a set of tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// A conjunction to connect words.
  ///
  /// In en, this message translates to:
  /// **'And'**
  String get and;

  /// A label for a data analytics section.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// A button or action to open something.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// A button or action to close something.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// An adjective for a theme, e.g., 'Dark Mode'.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// A label for a theme or state, e.g., 'Dark Mode'.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get mode;

  /// An adjective, e.g., 'Assistive Touch'.
  ///
  /// In en, this message translates to:
  /// **'Assistive'**
  String get assistive;

  /// A noun, e.g., 'Assistive Touch'.
  ///
  /// In en, this message translates to:
  /// **'Touch'**
  String get touch;

  /// A button or action to edit something.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// A label for a section of information.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get information;

  /// A label for a single transaction.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get transaction;

  /// A label for a history or log.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get log;

  /// An adjective to indicate something happens every day.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// A label for a single reward.
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get reward;

  /// A preposition.
  ///
  /// In en, this message translates to:
  /// **'For'**
  String get forString;

  /// A label for a day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// A label for a single point.
  ///
  /// In en, this message translates to:
  /// **'Point'**
  String get point;

  /// A label for an order.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get order;

  /// A label for a history or log.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// A label for a date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// A label for the time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// Indicates a credit was applied to an account.
  ///
  /// In en, this message translates to:
  /// **'Credited'**
  String get credited;

  /// Indicates a debit was applied to an account.
  ///
  /// In en, this message translates to:
  /// **'Debited'**
  String get debited;

  /// An adjective to indicate something happens every week.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// A label for a single badge.
  ///
  /// In en, this message translates to:
  /// **'Badge'**
  String get badge;

  /// A label for a collection of badges.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get badges;

  /// A label for an overview or summary.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// A button or label to show more details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// A button or label to withdraw funds or points.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// Indicates when an item will expire.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get expires;

  /// A button or action to watch something.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get watch;

  /// A label for advertisements.
  ///
  /// In en, this message translates to:
  /// **'Ads'**
  String get ads;

  /// Indicates something is mandatory.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// A label for a withdrawal process.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal'**
  String get withdrawal;

  /// A label for a conversion process, e.g., points to cash.
  ///
  /// In en, this message translates to:
  /// **'Conversion'**
  String get conversion;

  /// A label for a rate of something.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rate;

  /// A preposition to indicate a rate, e.g., 'per point'.
  ///
  /// In en, this message translates to:
  /// **'Per'**
  String get per;

  /// A button to submit a form.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// A label for a request.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get request;

  /// A button to cancel an action.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// A label for a payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// A label for a bank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get bank;

  /// A label for a transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// A mobile payment service name.
  ///
  /// In en, this message translates to:
  /// **'Esewa'**
  String get esewa;

  /// A mobile payment service name.
  ///
  /// In en, this message translates to:
  /// **'Khalti'**
  String get khalti;

  /// An adjective, e.g., 'Mobile Banking'.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get mobile;

  /// A label for a banking service.
  ///
  /// In en, this message translates to:
  /// **'Banking'**
  String get banking;

  /// A button or label to earn rewards.
  ///
  /// In en, this message translates to:
  /// **'Earn'**
  String get earn;

  /// Indicates a reward has been claimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get claimed;

  /// A label for a single challenge.
  ///
  /// In en, this message translates to:
  /// **'Challenge'**
  String get challenge;

  /// An action prompt to tap on the screen.
  ///
  /// In en, this message translates to:
  /// **'Tap'**
  String get tap;

  /// A preposition.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get to;

  /// A button or action to claim a reward.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get claim;

  /// A label for a single attempt.
  ///
  /// In en, this message translates to:
  /// **'Attempt'**
  String get attempt;

  /// Indicates a remaining number.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get left;

  /// A button or label to complete a task.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// A button or label to convert something.
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get convert;

  /// A label for money or cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// An adverb of time.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// A label for a number of attempts.
  ///
  /// In en, this message translates to:
  /// **'Attempts'**
  String get attempts;

  /// Indicates something was successfully moved.
  ///
  /// In en, this message translates to:
  /// **'Transferred'**
  String get transferred;

  /// An adverb to indicate a successful action.
  ///
  /// In en, this message translates to:
  /// **'Successfully'**
  String get successfully;

  /// An adjective, e.g., 'matching results'.
  ///
  /// In en, this message translates to:
  /// **'Matching'**
  String get matching;

  /// A button or field to search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// A label for search results.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get results;

  /// A shortened form of 'Stories'.
  ///
  /// In en, this message translates to:
  /// **'S.Stories'**
  String get sStories;

  /// A category for 'stats' from creators.
  ///
  /// In en, this message translates to:
  /// **'Creator\'s Stats'**
  String get creatorsShats;

  /// A label for a user's referral code.
  ///
  /// In en, this message translates to:
  /// **'Referral Code'**
  String get referralCode;

  /// A section title for challenges that are currently active.
  ///
  /// In en, this message translates to:
  /// **'Active Challenges'**
  String get activeChallenges;

  /// A button to view all items in a list.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// A label showing the user's progress towards the next level.
  ///
  /// In en, this message translates to:
  /// **'Level Progress'**
  String get levelProgress;

  /// A menu item or button to contact support.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// A button or prompt to ask the user to review the app.
  ///
  /// In en, this message translates to:
  /// **'Review Us'**
  String get reviewUs;

  /// A label showing the total number of users.
  ///
  /// In en, this message translates to:
  /// **'Total Users'**
  String get totalUsers;

  /// A section title for the top 10 users who have referred others.
  ///
  /// In en, this message translates to:
  /// **'Top 10 Referrers'**
  String get top10Referrers;

  /// A section title for the user's shopping cart.
  ///
  /// In en, this message translates to:
  /// **'Your Cart'**
  String get yourCart;

  /// A message shown when no shorts are available.
  ///
  /// In en, this message translates to:
  /// **'No Shorts Found'**
  String get noShortsFound;

  /// A message shown when no stories are available.
  ///
  /// In en, this message translates to:
  /// **'No Stories Found'**
  String get noStoriesFound;

  /// A message shown when no creators are found.
  ///
  /// In en, this message translates to:
  /// **'No Creators Found'**
  String get noCreatorsFound;

  /// A message shown when the message inbox is empty.
  ///
  /// In en, this message translates to:
  /// **'No Messages Found'**
  String get noMessagesFound;

  /// A message shown when the notification list is empty.
  ///
  /// In en, this message translates to:
  /// **'No Notifications Found'**
  String get noNotificationsFound;

  /// A button to update user profile information.
  ///
  /// In en, this message translates to:
  /// **'Update Profile'**
  String get updateProfile;

  /// A button to change the user's profile picture.
  ///
  /// In en, this message translates to:
  /// **'Update Profile Picture'**
  String get updateProfilePicture;

  /// A section title for gift rewards.
  ///
  /// In en, this message translates to:
  /// **'Gift Rewards'**
  String get giftRewards;

  /// A descriptive message for the gift rewards section.
  ///
  /// In en, this message translates to:
  /// **'Redeem amazing rewards with your points'**
  String get giftRewardsInfo;

  /// A section title for stories from the app.
  ///
  /// In en, this message translates to:
  /// **'Stories from Baakhapaa'**
  String get storiesFromBaakhapa;

  /// A button or section title to explore more content.
  ///
  /// In en, this message translates to:
  /// **'Discover More'**
  String get discoverMore;

  /// A message shown when there are no active challenges.
  ///
  /// In en, this message translates to:
  /// **'No Active Challenges Found'**
  String get noActiveChallengesFound;

  /// A message shown when the user has no achievements yet.
  ///
  /// In en, this message translates to:
  /// **'No Achievements Found'**
  String get noAchievementsFound;

  /// A message shown when level progress data is unavailable.
  ///
  /// In en, this message translates to:
  /// **'No Level Progress Found'**
  String get noLevelProgressFound;

  /// A section title for gifts that are available to the user.
  ///
  /// In en, this message translates to:
  /// **'Available Gifts'**
  String get availableGifts;

  /// A section title for the user's personal achievements.
  ///
  /// In en, this message translates to:
  /// **'My Achievements'**
  String get myAchievements;

  /// A prompt to select content.
  ///
  /// In en, this message translates to:
  /// **'Choose your content'**
  String get chooseYourContent;

  /// Instructions for choosing content.
  ///
  /// In en, this message translates to:
  /// **'Select a video from your gallery or record a new one'**
  String get chooseYourContentInfo;

  /// A menu item for a portal for content creators.
  ///
  /// In en, this message translates to:
  /// **'Creator Portal'**
  String get creatorPortal;

  /// A descriptive message for the Creator Portal.
  ///
  /// In en, this message translates to:
  /// **'Access advanced creator tools and analytics'**
  String get creatorPortalInfo;

  /// Instructions for creating a new video.
  ///
  /// In en, this message translates to:
  /// **'Create new video'**
  String get recordInfo;

  /// A setting to switch to a dark theme.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// A setting to switch to a light theme.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// A setting for an accessibility feature.
  ///
  /// In en, this message translates to:
  /// **'Assistive Touch'**
  String get assistiveTouch;

  /// A button to edit the user's profile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// A descriptive message for the update profile section.
  ///
  /// In en, this message translates to:
  /// **'Update your profile information'**
  String get updateProfileInfo;

  /// A section title for a log of transactions.
  ///
  /// In en, this message translates to:
  /// **'Transaction Log'**
  String get transactionLog;

  /// A section title for the daily reward.
  ///
  /// In en, this message translates to:
  /// **'Daily Reward for Day'**
  String get dailyRewardForDay;

  /// A section title for a log of points.
  ///
  /// In en, this message translates to:
  /// **'Point Log'**
  String get pointLog;

  /// A section title for the user's order history.
  ///
  /// In en, this message translates to:
  /// **'Order History'**
  String get orderHistory;

  /// A label for date and time.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get dateTime;

  /// A section title for the user's transaction history.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistory;

  /// A section title for the weekly reward.
  ///
  /// In en, this message translates to:
  /// **'Weekly Reward'**
  String get weeklyReward;

  /// A section title for badges and achievements.
  ///
  /// In en, this message translates to:
  /// **'Badges / Achievements'**
  String get badgesAchievement;

  /// A section title for an overview of the user's points.
  ///
  /// In en, this message translates to:
  /// **'Points Overview'**
  String get pointsOverview;

  /// A button to view more details about an item.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// A button to initiate a points withdrawal.
  ///
  /// In en, this message translates to:
  /// **'Withdraw Points'**
  String get withdrawPoints;

  /// A label showing the number of available points.
  ///
  /// In en, this message translates to:
  /// **'Available Points'**
  String get availablePoints;

  /// A section title for daily rewards.
  ///
  /// In en, this message translates to:
  /// **'Daily Rewards'**
  String get dailyRewards;

  /// A button or prompt to watch an advertisement.
  ///
  /// In en, this message translates to:
  /// **'Watch Ads'**
  String get watchAds;

  /// A label indicating a required amount for withdrawal.
  ///
  /// In en, this message translates to:
  /// **'Required Withdrawal'**
  String get requiredWithdrawal;

  /// A label for the conversion rate of a currency or points.
  ///
  /// In en, this message translates to:
  /// **'Conversion Rate'**
  String get conversionRate;

  /// A label indicating a rate per point.
  ///
  /// In en, this message translates to:
  /// **'Per Point'**
  String get perPoint;

  /// A button to submit a request.
  ///
  /// In en, this message translates to:
  /// **'Submit Request'**
  String get submitRequest;

  /// A section title for payment details.
  ///
  /// In en, this message translates to:
  /// **'Payment Details'**
  String get paymentDetails;

  /// A payment method option.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get bankTransfer;

  /// A payment method option.
  ///
  /// In en, this message translates to:
  /// **'Mobile Banking'**
  String get mobileBanking;

  /// A section title for details of a challenge.
  ///
  /// In en, this message translates to:
  /// **'Challenge Details'**
  String get challengeDetails;

  /// An instruction to tap on the screen to claim a reward.
  ///
  /// In en, this message translates to:
  /// **'Tap to claim'**
  String get tapToClaim;

  /// A message explaining how to earn points by watching ads.
  ///
  /// In en, this message translates to:
  /// **'Watch ads to earn 1 Point.'**
  String get watchAdsEarnPoints;

  /// A label showing the number of attempts remaining.
  ///
  /// In en, this message translates to:
  /// **'Attempt left'**
  String get attemptLeft;

  /// A prompt to complete the user's profile.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get completeYourProfile;

  /// A button or label to convert points to cash.
  ///
  /// In en, this message translates to:
  /// **'Convert points to cash'**
  String get convertPointsToCash;

  /// A section title for an overview of the user's points.
  ///
  /// In en, this message translates to:
  /// **'Point Overview'**
  String get pointOverview;

  /// A success message for a completed transfer.
  ///
  /// In en, this message translates to:
  /// **'Transferred successfully'**
  String get transferredSuccessfully;

  /// A prepositional phrase, e.g., 'transferred with your mobile banking'.
  ///
  /// In en, this message translates to:
  /// **'With your'**
  String get withYour;

  /// A section title for search results.
  ///
  /// In en, this message translates to:
  /// **'Search Results'**
  String get searchResults;

  /// A button to confirm an action.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// A descriptive message for the Creators' Shats section.
  ///
  /// In en, this message translates to:
  /// **'See your content preferences'**
  String get creatorsShatsDescription;

  /// A descriptive message for the referral code section.
  ///
  /// In en, this message translates to:
  /// **'Share and earn rewards'**
  String get referralCodeDescription;

  /// A descriptive message for the gift rewards section.
  ///
  /// In en, this message translates to:
  /// **'Get amazing rewards with your points'**
  String get giftRewardsDescription;

  /// A descriptive message for the stories section.
  ///
  /// In en, this message translates to:
  /// **'Discover amazing stories and adventures'**
  String get storiesFromBaakhapaDescription;

  /// A descriptive message for the discover more section.
  ///
  /// In en, this message translates to:
  /// **'Explore more storytellers, challenges & more'**
  String get discoverMoreDescription;

  /// A message shown when no creators' shats are found.
  ///
  /// In en, this message translates to:
  /// **'No Creators\' Shats found'**
  String get noCreatorsShatsFound;

  /// A prompt to the user to select their language.
  ///
  /// In en, this message translates to:
  /// **'Please select your preferred language.'**
  String get selectLanguagePrompt;

  /// A prompt to the user to update their profile.
  ///
  /// In en, this message translates to:
  /// **'Update your profile information and picture.'**
  String get updateProfilePrompt;

  /// A descriptive message for the transaction history section.
  ///
  /// In en, this message translates to:
  /// **'View your transaction history to see all credits and debits.'**
  String get viewTransactionHistory;

  /// A prompt to watch ads for points.
  ///
  /// In en, this message translates to:
  /// **'Watch ads to earn more points!'**
  String get rewardsForWatchingAds;

  /// A message indicating a points expiration date.
  ///
  /// In en, this message translates to:
  /// **'Your available Points will expire on '**
  String get viewYourAvailablePoints;

  /// A success message for claiming a daily reward.
  ///
  /// In en, this message translates to:
  /// **'You have claimed the daily reward for Day '**
  String get dailyRewardClaimed;

  /// A prompt to the user to select a withdrawal method.
  ///
  /// In en, this message translates to:
  /// **'Please select a withdrawal method from the options below.'**
  String get selectWithdrawalMethod;

  /// A tagline for the application.
  ///
  /// In en, this message translates to:
  /// **'Play, Learn, Earn'**
  String get playLearnEarn;

  /// A positive confirmation.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// An acknowledgement.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// A button to save changes.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// A button to permanently remove an item.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// A greeting.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// A greeting.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get hello;

  /// A farewell.
  ///
  /// In en, this message translates to:
  /// **'Goodbye'**
  String get goodbye;

  /// A success message.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// A warning message.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// A conjunction.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// A preposition.
  ///
  /// In en, this message translates to:
  /// **'by'**
  String get by;

  /// A preposition.
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get on;

  /// A preposition or state.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get off;

  /// A prompt to input text.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get enter;

  /// A label for a name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// A label for an email field.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// A label for a password field.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// A label for a password confirmation field.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// A label for a description field.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// A label for a message field.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// A label for the home screen.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// A label for a store run by a vendor.
  ///
  /// In en, this message translates to:
  /// **'Vendor Store'**
  String get vendorStore;

  /// A button to browse items.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browse;

  /// A possessive pronoun, e.g., 'our collection'.
  ///
  /// In en, this message translates to:
  /// **'Our'**
  String get our;

  /// A label for a collection of items.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get collection;

  /// A button to clear all notifications.
  ///
  /// In en, this message translates to:
  /// **'Clear All Notifications'**
  String get clearAllNotifications;

  /// A button to continue shopping.
  ///
  /// In en, this message translates to:
  /// **'Continue Shopping'**
  String get continueShopping;

  /// A message to encourage the user to add products to their cart.
  ///
  /// In en, this message translates to:
  /// **'Add some amazing product to your cart and start shopping!'**
  String get yourCartDescription;

  /// A message indicating the user's cart is empty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get yourCartIsEmpty;

  /// A button to continue an action.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueString;

  /// A label related to the shopping activity.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get shopping;

  /// A button text to continue shopping.
  ///
  /// In en, this message translates to:
  /// **'Continue Shopping'**
  String get continueShoppingButton;

  /// A Redeem for gift text
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get redeemLabel;

  /// Success message!
  ///
  /// In en, this message translates to:
  /// **'Success!'**
  String get successMessage;

  /// An error occurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred.'**
  String get errorMessage;

  /// Send
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendButton;

  /// Delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// Edit
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editButton;

  /// Add
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addButton;

  /// Update
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateButton;

  /// Remove
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeButton;

  /// Confirm
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmButton;

  /// Yes
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yesButton;

  /// No
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get noButton;

  /// Continue
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// Login
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// Logout
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutButton;

  /// Register
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerButton;

  /// Sign In
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInTitle;

  /// Sign Up
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUpTitle;

  /// Create an Account
  ///
  /// In en, this message translates to:
  /// **'Create an Account'**
  String get createAccountButton;

  /// Email Address
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailLabel;

  /// Password
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// Forgot Password?
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordLink;

  /// Username
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// Confirm Password
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordLabel;

  /// Already have an account?
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// Don't have an account?
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// 'Are you sure you want to logout?
  ///
  /// In en, this message translates to:
  /// **'\'Are you sure you want to logout?'**
  String get logoutConfirmation;

  /// Button to navigate to the item collection screen.
  ///
  /// In en, this message translates to:
  /// **'Browse our collection'**
  String get browseCollection;

  /// Button to add an item to the shopping cart.
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get addToCart;

  /// Status label for a product that is currently unavailable.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get outOfStock;

  /// Label for the number of times an episode has been viewed.
  ///
  /// In en, this message translates to:
  /// **'Episode Views'**
  String get episodeViews;

  /// Label for the number of times a short-form video has been viewed.
  ///
  /// In en, this message translates to:
  /// **'S.Shorts Views'**
  String get shortsViews;

  /// A heading or label for different seasons of a story.
  ///
  /// In en, this message translates to:
  /// **'Story Seasons'**
  String get storySeasons;

  /// A label indicating the number of likes an item has received.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get likes;

  /// A heading for a list of gifts that match a user's search query.
  ///
  /// In en, this message translates to:
  /// **'Gifts matching your search'**
  String get giftsMatchingSearch;

  /// Instructional text telling the user how to use their points.
  ///
  /// In en, this message translates to:
  /// **'Redeem gifts with your points'**
  String get redeemGiftsWithPoints;

  /// Placeholder text for a search bar for finding redeemable gifts.
  ///
  /// In en, this message translates to:
  /// **'Search gifts to redeem...'**
  String get searchGiftsToRedeem;

  /// A heading or link to the account management section.
  ///
  /// In en, this message translates to:
  /// **'Manage your account'**
  String get manageAccount;

  /// A button or title for filtering a list of challenges.
  ///
  /// In en, this message translates to:
  /// **'Filter Challenges'**
  String get filterChallenges;

  /// Information about the theme toggle switch.
  ///
  /// In en, this message translates to:
  /// **'Toggle between light and dark themes'**
  String get toggleSwitchInfo;

  /// Information about enabling the assistive touch feature.
  ///
  /// In en, this message translates to:
  /// **'Enable floating action button'**
  String get assistiveTouchInfo;

  /// Information about contacting support.
  ///
  /// In en, this message translates to:
  /// **'Get help and support'**
  String get contactUsInfo;

  /// Information about signing out of the user's account.
  ///
  /// In en, this message translates to:
  /// **'Sign out of your account'**
  String get logoutInfo;

  /// Information about changing the application language.
  ///
  /// In en, this message translates to:
  /// **'Change app language'**
  String get languageInfo;

  /// A label for an unlock action.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// A title for a section featuring storytellers.
  ///
  /// In en, this message translates to:
  /// **'Storytellers'**
  String get storytellers;

  /// Information encouraging discovery of storytellers.
  ///
  /// In en, this message translates to:
  /// **'Discover amazing storytellers'**
  String get storyTellersInfo;

  /// Description of challenges and rewards.
  ///
  /// In en, this message translates to:
  /// **'Join exciting challenges and win rewards'**
  String get challengesDescription;

  /// Text encouraging discovery of content creators.
  ///
  /// In en, this message translates to:
  /// **'Discover amazing content creators'**
  String get findStorytellers;

  /// A general label for a search or discovery action.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get find;

  /// A placeholder or label for searching by username.
  ///
  /// In en, this message translates to:
  /// **'Search by username'**
  String get searchByUsername;

  /// A section title for personalized content.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get forYou;

  /// A button or action to enter full screen mode.
  ///
  /// In en, this message translates to:
  /// **'Enter Full Screen'**
  String get enterFullScreen;

  /// A button or title for filtering short stories.
  ///
  /// In en, this message translates to:
  /// **'Filter Short Stories'**
  String get filterShortStories;

  /// A title for topics related to short stories.
  ///
  /// In en, this message translates to:
  /// **'Short Stories Topics'**
  String get shortStoriesTopics;

  /// A label for sorting options.
  ///
  /// In en, this message translates to:
  /// **'Sort By'**
  String get sortBy;

  /// A sorting option for content by most likes.
  ///
  /// In en, this message translates to:
  /// **'Most Liked'**
  String get mostLiked;

  /// A sorting option for content by most points.
  ///
  /// In en, this message translates to:
  /// **'Most Points'**
  String get mostPoints;

  /// A sorting option for random order.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get random;

  /// A sorting option for the latest content.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latest;

  /// A sorting option for the oldest content.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get oldest;

  /// Heading for the company information section.
  ///
  /// In en, this message translates to:
  /// **'About Our Company'**
  String get aboutOurCompany;

  /// Mission statement of the company.
  ///
  /// In en, this message translates to:
  /// **'A multi-purpose content sharing app that monetizes engagement according to the knowledge of storytelling.'**
  String get companyMissionStatement;

  /// First paragraph describing Baakhapaa IT and Marketing Solutions LLC.
  ///
  /// In en, this message translates to:
  /// **'Baakhapaa IT and Marketing Solutions LLC is a software development and marketing company that strives to create stories of success for its clients. We focus on providing informative multimedia platforms for organizations that strive to be a successful brand and propel the business to new heights.'**
  String get companyDescription1;

  /// Second paragraph describing the impact of company services.
  ///
  /// In en, this message translates to:
  /// **'With our services, organizations can create a brand that works on uniting people, promoting culture, and moving towards spiritual consciousness through the power of storytelling.'**
  String get companyDescription2;

  /// Call to action for contacting the company.
  ///
  /// In en, this message translates to:
  /// **'Get in Touch'**
  String get getInTouch;

  /// Label for Instagram social media link.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get instagram;

  /// Label for Facebook social media link.
  ///
  /// In en, this message translates to:
  /// **'Facebook'**
  String get facebook;

  /// Label for YouTube social media link.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get youTube;

  /// Label for Messenger social media link.
  ///
  /// In en, this message translates to:
  /// **'Messenger'**
  String get messenger;

  /// Label for Viber social media link.
  ///
  /// In en, this message translates to:
  /// **'Viber'**
  String get viber;

  /// Heading for general user information.
  ///
  /// In en, this message translates to:
  /// **'General Information'**
  String get generalInformation;

  /// Label for full name input field.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// Label for username input field.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// Label for date of birth input field.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get dateOfBirth;

  /// Heading for address details section.
  ///
  /// In en, this message translates to:
  /// **'Address Information'**
  String get addressInformation;

  /// Label for country input field.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// Label for state/province input field.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// Label for address input field.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// Label for postal code input field.
  ///
  /// In en, this message translates to:
  /// **'Postal Code'**
  String get postalCode;

  /// Heading for security settings section.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// Button or link to change password.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// Label for the number of lives in a game or challenge.
  ///
  /// In en, this message translates to:
  /// **'Lives'**
  String get lives;

  /// Label for the duration of an item or event.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// Abbreviation for Multiple Choice Question.
  ///
  /// In en, this message translates to:
  /// **'Mcq'**
  String get mcq;

  /// Label for minimum number of plays required.
  ///
  /// In en, this message translates to:
  /// **'Min Plays'**
  String get minPlays;

  /// Label for points needed to access something.
  ///
  /// In en, this message translates to:
  /// **'Points Required'**
  String get pointsRequired;

  /// Label indicating how a winner is determined or displayed.
  ///
  /// In en, this message translates to:
  /// **'Winner As'**
  String get winnerAs;

  /// Message indicating all tasks or notifications are viewed.
  ///
  /// In en, this message translates to:
  /// **'All Caught up'**
  String get allCaughtUp;

  /// Generic action to display something.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// Message when all notifications have been read.
  ///
  /// In en, this message translates to:
  /// **'You\'ve read all your notifications. Great job staying organized!'**
  String get notificationsReadMessage;

  /// Message when there are no notifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// Hint text for where notifications will appear.
  ///
  /// In en, this message translates to:
  /// **'When you receive notifications, they\'ll appear here'**
  String get notificationsAppearHere;

  /// Button or action to refresh content.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Label for number of episodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get episodes;

  /// Label for total accumulated points.
  ///
  /// In en, this message translates to:
  /// **'Total Points'**
  String get totalPoints;

  /// Title for the creators' management screen.
  ///
  /// In en, this message translates to:
  /// **'Creators Screen'**
  String get creatorsScreen;

  /// Generic action to create something.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Instruction for choosing videos from gallery.
  ///
  /// In en, this message translates to:
  /// **'Choose your videos'**
  String get galleryInfo;

  /// Prompt for user to describe their video.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your video'**
  String get tellUsAboutYourVideo;

  /// Label for video title input field.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// Placeholder or prompt for video description.
  ///
  /// In en, this message translates to:
  /// **'What\'s your video about?'**
  String get whatsYourVideoAbout;

  /// Placeholder for content description input.
  ///
  /// In en, this message translates to:
  /// **'Describe your content...'**
  String get describeYourContent;

  /// Button to go back to the previous screen.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Heading for challenge setup section.
  ///
  /// In en, this message translates to:
  /// **'Setup your challenge'**
  String get setupYourChallenge;

  /// Label for category selection.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// Instruction for choosing a category.
  ///
  /// In en, this message translates to:
  /// **'Choose category'**
  String get chooseCategory;

  /// Loading message for categories.
  ///
  /// In en, this message translates to:
  /// **'Loading categories …'**
  String get loadingCategories;

  /// Label for points awarded as a reward.
  ///
  /// In en, this message translates to:
  /// **'Points Reward'**
  String get pointsReward;

  /// Button or action to post short videos.
  ///
  /// In en, this message translates to:
  /// **'Post Shorts'**
  String get postShorts;

  /// Message indicating a wait state before proceeding.
  ///
  /// In en, this message translates to:
  /// **'Wait to continue...'**
  String get waitToContinue;

  /// Button to navigate to a question.
  ///
  /// In en, this message translates to:
  /// **'Start Quiz'**
  String get goToQuestion;

  /// Heading for comments section.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// Button or action to support a creator.
  ///
  /// In en, this message translates to:
  /// **'Vote Creator'**
  String get supportCreator;

  /// Heading for episode navigation controls.
  ///
  /// In en, this message translates to:
  /// **'Episode Navigation'**
  String get episodeNavigation;

  /// Button to go to the previous item/episode.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// Generic action to post content.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// Prompt for user to share their opinion.
  ///
  /// In en, this message translates to:
  /// **'Add a comments..'**
  String get shareYourThoughts;

  /// Heading for a list of top referral users.
  ///
  /// In en, this message translates to:
  /// **'Leading referral users'**
  String get leadingReferralUsers;

  /// Button to share user's ranking.
  ///
  /// In en, this message translates to:
  /// **'Share my ranking'**
  String get shareMyRanking;

  /// Title for the 'Become a Creator' page or section.
  ///
  /// In en, this message translates to:
  /// **'Become a Creator'**
  String get becomeACreator;

  /// A heading or title encouraging users to earn rewards.
  ///
  /// In en, this message translates to:
  /// **'Unlock badges and earn rewards'**
  String get unlockBadgesAndEarnRewards;

  /// Descriptive text explaining how the badge system works.
  ///
  /// In en, this message translates to:
  /// **'Earn badges to redeem rewards inside baakhapaa app. Achievements are categorized by type to help you track your progress'**
  String get earnBadgesForRewards;

  /// Status text indicating something has been completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// Call to action for users to share a referral code.
  ///
  /// In en, this message translates to:
  /// **'Share this code with friends and earn rewards when they join!'**
  String get shareCodeWithFriends;

  /// Button text to copy a referral code.
  ///
  /// In en, this message translates to:
  /// **'Copy Code'**
  String get copyCode;

  /// Message displayed when no referral code exists for the user.
  ///
  /// In en, this message translates to:
  /// **'No referral code available'**
  String get noReferralCodeAvailable;

  /// A welcome message or call to action for joining the creator community.
  ///
  /// In en, this message translates to:
  /// **'Join the community of content creators and share your unique voice with the world'**
  String get joinCreatorCommunity;

  /// Heading for a section outlining the benefits of being a creator.
  ///
  /// In en, this message translates to:
  /// **'Creator Benefits'**
  String get creatorBenefits;

  /// Subheading or descriptive text for the creator benefits section.
  ///
  /// In en, this message translates to:
  /// **'What you can achieve as a creator'**
  String get whatYouCanAchieve;

  /// A benefit item related to creating content.
  ///
  /// In en, this message translates to:
  /// **'Content Creation'**
  String get contentCreation;

  /// Description of the content creation benefit.
  ///
  /// In en, this message translates to:
  /// **'Create and share engaging Shorts and Stories'**
  String get createAndShareContent;

  /// A benefit item related to building an audience.
  ///
  /// In en, this message translates to:
  /// **'Build Following'**
  String get buildFollowing;

  /// Description of the audience-building benefit.
  ///
  /// In en, this message translates to:
  /// **'Grow your audience with engaged fans'**
  String get growYourAudience;

  /// A benefit item related to earning money.
  ///
  /// In en, this message translates to:
  /// **'Monetization'**
  String get monetization;

  /// Description of the monetization benefit.
  ///
  /// In en, this message translates to:
  /// **'Earn through various monetization channels'**
  String get earnThroughMonetization;

  /// A benefit item related to getting recognized for contributions.
  ///
  /// In en, this message translates to:
  /// **'Recognition'**
  String get recognition;

  /// Description of the recognition benefit.
  ///
  /// In en, this message translates to:
  /// **'Get rewards for your contributions'**
  String get getRewardsForContributions;

  /// Heading for a section outlining the requirements to become a creator.
  ///
  /// In en, this message translates to:
  /// **'Requirements'**
  String get requirements;

  /// Descriptive text for the requirements section.
  ///
  /// In en, this message translates to:
  /// **'Meet these criteria to become a creator'**
  String get meetCreatorCriteria;

  /// Prefix for a minimum value or requirement.
  ///
  /// In en, this message translates to:
  /// **'Minimum'**
  String get minimum;

  /// Introductory word for a list of requirements.
  ///
  /// In en, this message translates to:
  /// **'Need'**
  String get need;

  /// Descriptive text for a specific requirement to complete episodes.
  ///
  /// In en, this message translates to:
  /// **'Complete these episodes to qualify'**
  String get completeEpisodesToQualify;

  /// A message to the user that their request has been submitted and is being reviewed.
  ///
  /// In en, this message translates to:
  /// **'Your request is under review. You will receive an email notification once a decision has been made.'**
  String get requestUnderReview;

  /// An error message or prompt to the user to fulfill all requirements before submitting.
  ///
  /// In en, this message translates to:
  /// **'Please meet all requirements before submitting your request.'**
  String get meetAllRequirements;

  /// Confirmation message that a request has been submitted.
  ///
  /// In en, this message translates to:
  /// **'Request Submitted'**
  String get requestSubmitted;

  /// Button text to submit a creator request.
  ///
  /// In en, this message translates to:
  /// **'Submit Creator Request'**
  String get submitCreatorRequest;

  /// Heading for a section about earning rewards.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get learn;

  /// Descriptive text detailing the actions required to earn rewards.
  ///
  /// In en, this message translates to:
  /// **'Watch stories • Upload Videos • Complete Challenges to earn rewards'**
  String get learnDescription;

  /// Monetize Your SCREEN TIME
  ///
  /// In en, this message translates to:
  /// **'Monetize Your SCREEN TIME'**
  String get monetizeYourSCREENTIME;

  /// Stories Are Power. Stories Are Rewards.
  ///
  /// In en, this message translates to:
  /// **'Stories Are Power. Stories Are Rewards.'**
  String get storiesArePowerStoriesAreRewards;

  /// Stories Are Power.
  ///
  /// In en, this message translates to:
  /// **'Stories Are Power.'**
  String get storiesArePower;

  /// Stories Are Rewards.
  ///
  /// In en, this message translates to:
  /// **'Stories Are Rewards.'**
  String get storiesAreRewards;

  /// Browse by vendors and collections
  ///
  /// In en, this message translates to:
  /// **'Browse by vendors and collections'**
  String get browseByVendorsAndCollections;

  /// Start your journey of watching shorts, playing games and earning rewards!
  ///
  /// In en, this message translates to:
  /// **'Start your journey of watching shorts, playing games and earning rewards!'**
  String get startJourney;

  /// I agree to the
  ///
  /// In en, this message translates to:
  /// **'I agree to the'**
  String get iAgreeToThe;

  /// and
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get andKeyword;

  /// Apply to become a content creator
  ///
  /// In en, this message translates to:
  /// **'Apply to become a content creator'**
  String get applyToBecomeCreator;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'en',
        'es',
        'fr',
        'hi',
        'ja',
        'ko',
        'ne',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'ne':
      return AppLocalizationsNe();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
