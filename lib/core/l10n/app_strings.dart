import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

/// User-facing text, in the language picked in Settings.
///
/// The Language setting used to be saved and then ignored — nothing in the app
/// read it. Widgets now take their labels from here via [appStringsProvider].
///
/// Incident *category* names are deliberately not translated: those exact
/// strings are the values stored in the database and matched by the feed
/// filter, so translating them would break filtering.
abstract class AppStrings {
  const AppStrings();

  static const supportedCodes = ['en', 'bn'];

  static AppStrings of(String languageCode) =>
      languageCode == 'bn' ? const BanglaStrings() : const EnglishStrings();

  /// Name of a language in its own script, for the Settings dropdown.
  static String languageName(String code) =>
      code == 'bn' ? 'বাংলা (Bangla)' : 'English';

  // --- chrome ---------------------------------------------------------------
  String get appTitle;
  String get drawerHeadline;
  String get navHome;
  String get navMap;
  String get navProfile;
  String get notifications;
  String get settings;

  // --- shared actions -------------------------------------------------------
  String get logIn;
  String get signUp;
  String get signOut;
  String get logOut;
  String get logOutQuestion;
  String get logOutWarning;
  String get signedOut;
  String get cancel;
  String get save;
  String get refresh;
  String get retry;

  // --- drawer ---------------------------------------------------------------
  String get myReports;
  String get savedPosts;
  String get mapSection;
  String get alertRadius;
  String get unknownLocation;

  // --- home feed ------------------------------------------------------------
  String get whatsHappeningNearby;
  String get categoryAll;
  String get waitingForGps;
  String get logInToReport;
  String get logInToVote;
  String get logInToSave;
  String noIncidentsWithin(int km);
  String noCategoryIncidentsWithin(String category, int km);

  // --- feed filter & sort ---------------------------------------------------
  String get filterAndSort;
  String get sortBy;
  String get showOnly;
  String get showResults;
  String get resetAll;
  String get sortNearest;
  String get sortNewest;
  String get sortOldest;
  String get sortTop;
  String get sortDiscussed;
  String get sortConfirmed;
  String get verificationLabel;
  String get statusAny;
  String get statusVerified;
  String get statusUnverified;
  String get statusDisputed;
  String get evidenceLabel;
  String get evidenceAny;
  String get evidenceSeen;
  String get evidenceHeard;
  String get evidenceGuessed;
  String get postedLabel;
  String get postedAnytime;
  String get postedLastHour;
  String get postedLast6Hours;
  String get postedLastDay;
  String get postedLastWeek;
  String get withPhotoOnly;
  String get noMatchingReports;

  /// Shown when the feed on screen came off the device, not the backend.
  String get showingSavedReports;

  // --- reports --------------------------------------------------------------
  String get reportDetails;
  String get reportNewIncident;
  String get addToThisIncident;
  String get submitReport;
  String get titleLabel;
  String get categoryLabel;
  String get descriptionLabel;
  String get required;
  String get comments;
  String get addComment;
  String get noReportsYet;
  String get noSavedPosts;
  String get savePost;
  String get removeFromSaved;

  // --- settings -------------------------------------------------------------
  String get accountAndSecurity;
  String get editProfile;
  String get changePassword;
  String get appPreferences;
  String get theme;
  String get themeSystem;
  String get themeLight;
  String get themeDark;
  String get language;
  String get mapAndLocation;
  String get reportRadius;
  String get nearbyAlerts;
  String nearbyAlertsSubtitle(int km);
  String get viewNotifications;
  String get aboutAndSupport;
  String get helpCenter;
  String get privacyPolicy;
  String get appVersion;

  // --- profile --------------------------------------------------------------
  String get profileInfo;
  String get name;
  String get email;
  String get address;
  String get noAddressSpecified;
  String get signInToViewProfile;

  // --- auth -----------------------------------------------------------------
  String get welcomeBack;
  String get signInToYourAccount;
  String get password;
  String get forgotPassword;
  String get dontHaveAnAccount;
  String get alreadyHaveAnAccount;
  String get createAccount;

  // --- notifications --------------------------------------------------------
  String get markAllRead;
  String get clearAll;
  String get noNotificationsYet;
}

class EnglishStrings extends AppStrings {
  const EnglishStrings();

  @override
  String get appTitle => 'CTRC System';
  @override
  String get drawerHeadline => 'Crowdsourced Traffic\n& Road Condition';
  @override
  String get navHome => 'Home';
  @override
  String get navMap => 'Map';
  @override
  String get navProfile => 'Profile';
  @override
  String get notifications => 'Notifications';
  @override
  String get settings => 'Settings';

  @override
  String get logIn => 'Log In';
  @override
  String get signUp => 'Sign Up';
  @override
  String get signOut => 'Sign Out';
  @override
  String get logOut => 'Log Out';
  @override
  String get logOutQuestion => 'Log Out?';
  @override
  String get logOutWarning =>
      'You will need to sign in again to report, vote or comment.';
  @override
  String get signedOut => 'You are now browsing as a guest.';
  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get refresh => 'Refresh';
  @override
  String get retry => 'Retry';

  @override
  String get myReports => 'My Reports';
  @override
  String get savedPosts => 'Saved Posts';
  @override
  String get mapSection => 'MAP';
  @override
  String get alertRadius => 'Alert radius';
  @override
  String get unknownLocation => 'Unknown Location';

  @override
  String get whatsHappeningNearby => "What's happening nearby?";
  @override
  String get categoryAll => 'All';
  @override
  String get waitingForGps => 'Waiting for GPS location...';
  @override
  String get logInToReport => 'Please log in to report an incident';
  @override
  String get logInToVote => 'Please log in to vote';
  @override
  String get logInToSave => 'Please log in to save posts';
  @override
  String noIncidentsWithin(int km) => 'No incidents reported within $km km.';
  @override
  String noCategoryIncidentsWithin(String category, int km) =>
      'No "$category" reports within $km km.';

  @override
  String get filterAndSort => 'Filter & sort';
  @override
  String get sortBy => 'Sort by';
  @override
  String get showOnly => 'Show only';
  @override
  String get showResults => 'Show results';
  @override
  String get resetAll => 'Reset';
  @override
  String get sortNearest => 'Nearest first';
  @override
  String get sortNewest => 'Newest first';
  @override
  String get sortOldest => 'Oldest first';
  @override
  String get sortTop => 'Most upvoted';
  @override
  String get sortDiscussed => 'Most discussed';
  @override
  String get sortConfirmed => 'Most confirmed';
  @override
  String get verificationLabel => 'Verification';
  @override
  String get statusAny => 'Any';
  @override
  String get statusVerified => 'Verified';
  @override
  String get statusUnverified => 'Not verified yet';
  @override
  String get statusDisputed => 'Disputed';
  @override
  String get evidenceLabel => 'How it was known';
  @override
  String get evidenceAny => 'Any';
  @override
  String get evidenceSeen => 'Seen first hand';
  @override
  String get evidenceHeard => 'Heard from others';
  @override
  String get evidenceGuessed => 'A guess';
  @override
  String get postedLabel => 'Posted';
  @override
  String get postedAnytime => 'Any time';
  @override
  String get postedLastHour => 'Last hour';
  @override
  String get postedLast6Hours => 'Last 6 hours';
  @override
  String get postedLastDay => 'Last 24 hours';
  @override
  String get postedLastWeek => 'Last 7 days';
  @override
  String get withPhotoOnly => 'With a photo only';
  @override
  String get noMatchingReports => 'No reports match these filters.';
  @override
  String get showingSavedReports => 'Showing reports saved from your last visit.';

  @override
  String get reportDetails => 'Report details';
  @override
  String get reportNewIncident => 'Report new incident';
  @override
  String get addToThisIncident => 'Add to this incident';
  @override
  String get submitReport => 'Submit report';
  @override
  String get titleLabel => 'Title';
  @override
  String get categoryLabel => 'Category';
  @override
  String get descriptionLabel => 'Description';
  @override
  String get required => 'Required';
  @override
  String get comments => 'Comments';
  @override
  String get addComment => 'Add a comment...';
  @override
  String get noReportsYet => "You haven't posted any reports yet.";
  @override
  String get noSavedPosts => 'You have no saved posts.';
  @override
  String get savePost => 'Save post';
  @override
  String get removeFromSaved => 'Remove from saved';

  @override
  String get accountAndSecurity => 'Account & Security';
  @override
  String get editProfile => 'Edit Profile';
  @override
  String get changePassword => 'Change Password';
  @override
  String get appPreferences => 'App Preferences';
  @override
  String get theme => 'Theme';
  @override
  String get themeSystem => 'System';
  @override
  String get themeLight => 'Light';
  @override
  String get themeDark => 'Dark';
  @override
  String get language => 'Language';
  @override
  String get mapAndLocation => 'Map & Location';
  @override
  String get reportRadius => 'Report Radius';
  @override
  String get nearbyAlerts => 'Nearby Incident Alerts';
  @override
  String nearbyAlertsSubtitle(int km) =>
      'Collect an alert whenever a new incident is reported within $km km';
  @override
  String get viewNotifications => 'View notifications';
  @override
  String get aboutAndSupport => 'About & Support';
  @override
  String get helpCenter => 'Help Center / FAQ';
  @override
  String get privacyPolicy => 'Privacy Policy';
  @override
  String get appVersion => 'App Version';

  @override
  String get profileInfo => 'Profile Info';
  @override
  String get name => 'Name';
  @override
  String get email => 'Email';
  @override
  String get address => 'Address';
  @override
  String get noAddressSpecified => 'No address specified';
  @override
  String get signInToViewProfile =>
      'Sign in to view your profile and manage your reports.';

  @override
  String get welcomeBack => 'Welcome Back';
  @override
  String get signInToYourAccount => 'Sign in to your account';
  @override
  String get password => 'Password';
  @override
  String get forgotPassword => 'Forgot Password?';
  @override
  String get dontHaveAnAccount => "Don't have an account? ";
  @override
  String get alreadyHaveAnAccount => 'Already have an account? ';
  @override
  String get createAccount => 'Create Account';

  @override
  String get markAllRead => 'Mark all as read';
  @override
  String get clearAll => 'Clear all';
  @override
  String get noNotificationsYet =>
      'No alerts yet.\nYou will be notified when a new incident is reported '
      'near you.';
}

class BanglaStrings extends AppStrings {
  const BanglaStrings();

  @override
  String get appTitle => 'সিটিআরসি সিস্টেম';
  @override
  String get drawerHeadline => 'জনসাধারণের ট্রাফিক\nও সড়ক অবস্থা';
  @override
  String get navHome => 'হোম';
  @override
  String get navMap => 'মানচিত্র';
  @override
  String get navProfile => 'প্রোফাইল';
  @override
  String get notifications => 'বিজ্ঞপ্তি';
  @override
  String get settings => 'সেটিংস';

  @override
  String get logIn => 'লগ ইন';
  @override
  String get signUp => 'সাইন আপ';
  @override
  String get signOut => 'সাইন আউট';
  @override
  String get logOut => 'লগ আউট';
  @override
  String get logOutQuestion => 'লগ আউট করবেন?';
  @override
  String get logOutWarning =>
      'রিপোর্ট, ভোট বা মন্তব্য করতে আবার সাইন ইন করতে হবে।';
  @override
  String get signedOut => 'আপনি এখন অতিথি হিসেবে ব্রাউজ করছেন।';
  @override
  String get cancel => 'বাতিল';
  @override
  String get save => 'সংরক্ষণ';
  @override
  String get refresh => 'রিফ্রেশ';
  @override
  String get retry => 'আবার চেষ্টা করুন';

  @override
  String get myReports => 'আমার রিপোর্ট';
  @override
  String get savedPosts => 'সংরক্ষিত পোস্ট';
  @override
  String get mapSection => 'মানচিত্র';
  @override
  String get alertRadius => 'সতর্কতার পরিধি';
  @override
  String get unknownLocation => 'অজানা অবস্থান';

  @override
  String get whatsHappeningNearby => 'আশেপাশে কী ঘটছে?';
  @override
  String get categoryAll => 'সব';
  @override
  String get waitingForGps => 'জিপিএস অবস্থানের জন্য অপেক্ষা করা হচ্ছে...';
  @override
  String get logInToReport => 'রিপোর্ট করতে লগ ইন করুন';
  @override
  String get logInToVote => 'ভোট দিতে লগ ইন করুন';
  @override
  String get logInToSave => 'পোস্ট সংরক্ষণ করতে লগ ইন করুন';
  @override
  String noIncidentsWithin(int km) =>
      '$km কিমির মধ্যে কোনো ঘটনা রিপোর্ট করা হয়নি।';
  @override
  String noCategoryIncidentsWithin(String category, int km) =>
      '$km কিমির মধ্যে "$category" ধরনের কোনো রিপোর্ট নেই।';

  @override
  String get filterAndSort => 'ফিল্টার ও সাজানো';
  @override
  String get sortBy => 'যেভাবে সাজানো হবে';
  @override
  String get showOnly => 'শুধু দেখাও';
  @override
  String get showResults => 'ফলাফল দেখুন';
  @override
  String get resetAll => 'রিসেট';
  @override
  String get sortNearest => 'নিকটতম আগে';
  @override
  String get sortNewest => 'নতুন আগে';
  @override
  String get sortOldest => 'পুরনো আগে';
  @override
  String get sortTop => 'সবচেয়ে বেশি আপভোট';
  @override
  String get sortDiscussed => 'সবচেয়ে বেশি আলোচিত';
  @override
  String get sortConfirmed => 'সবচেয়ে বেশি নিশ্চিত';
  @override
  String get verificationLabel => 'যাচাই';
  @override
  String get statusAny => 'যেকোনো';
  @override
  String get statusVerified => 'যাচাইকৃত';
  @override
  String get statusUnverified => 'এখনো যাচাই হয়নি';
  @override
  String get statusDisputed => 'বিতর্কিত';
  @override
  String get evidenceLabel => 'কীভাবে জানা গেছে';
  @override
  String get evidenceAny => 'যেকোনো';
  @override
  String get evidenceSeen => 'নিজে দেখেছি';
  @override
  String get evidenceHeard => 'অন্যদের থেকে শোনা';
  @override
  String get evidenceGuessed => 'অনুমান';
  @override
  String get postedLabel => 'কখন পোস্ট হয়েছে';
  @override
  String get postedAnytime => 'যেকোনো সময়';
  @override
  String get postedLastHour => 'গত ১ ঘণ্টা';
  @override
  String get postedLast6Hours => 'গত ৬ ঘণ্টা';
  @override
  String get postedLastDay => 'গত ২৪ ঘণ্টা';
  @override
  String get postedLastWeek => 'গত ৭ দিন';
  @override
  String get withPhotoOnly => 'শুধু ছবিসহ রিপোর্ট';
  @override
  String get noMatchingReports => 'এই ফিল্টারে কোনো রিপোর্ট পাওয়া যায়নি।';
  @override
  String get showingSavedReports =>
      'গতবারের সংরক্ষিত রিপোর্ট দেখানো হচ্ছে।';

  @override
  String get reportDetails => 'রিপোর্টের বিবরণ';
  @override
  String get reportNewIncident => 'নতুন ঘটনা রিপোর্ট করুন';
  @override
  String get addToThisIncident => 'এই ঘটনায় যুক্ত করুন';
  @override
  String get submitReport => 'রিপোর্ট জমা দিন';
  @override
  String get titleLabel => 'শিরোনাম';
  @override
  String get categoryLabel => 'ধরন';
  @override
  String get descriptionLabel => 'বিবরণ';
  @override
  String get required => 'আবশ্যক';
  @override
  String get comments => 'মন্তব্য';
  @override
  String get addComment => 'একটি মন্তব্য লিখুন...';
  @override
  String get noReportsYet => 'আপনি এখনো কোনো রিপোর্ট করেননি।';
  @override
  String get noSavedPosts => 'আপনার কোনো সংরক্ষিত পোস্ট নেই।';
  @override
  String get savePost => 'পোস্ট সংরক্ষণ করুন';
  @override
  String get removeFromSaved => 'সংরক্ষণ থেকে সরান';

  @override
  String get accountAndSecurity => 'অ্যাকাউন্ট ও নিরাপত্তা';
  @override
  String get editProfile => 'প্রোফাইল সম্পাদনা';
  @override
  String get changePassword => 'পাসওয়ার্ড পরিবর্তন';
  @override
  String get appPreferences => 'অ্যাপ পছন্দসমূহ';
  @override
  String get theme => 'থিম';
  @override
  String get themeSystem => 'সিস্টেম';
  @override
  String get themeLight => 'লাইট';
  @override
  String get themeDark => 'ডার্ক';
  @override
  String get language => 'ভাষা';
  @override
  String get mapAndLocation => 'মানচিত্র ও অবস্থান';
  @override
  String get reportRadius => 'রিপোর্টের পরিধি';
  @override
  String get nearbyAlerts => 'কাছাকাছি ঘটনার সতর্কতা';
  @override
  String nearbyAlertsSubtitle(int km) =>
      '$km কিমির মধ্যে নতুন ঘটনা রিপোর্ট হলে সতর্কতা সংগ্রহ করুন';
  @override
  String get viewNotifications => 'বিজ্ঞপ্তি দেখুন';
  @override
  String get aboutAndSupport => 'সম্পর্কে ও সহায়তা';
  @override
  String get helpCenter => 'সহায়তা কেন্দ্র / প্রশ্নোত্তর';
  @override
  String get privacyPolicy => 'গোপনীয়তা নীতি';
  @override
  String get appVersion => 'অ্যাপ সংস্করণ';

  @override
  String get profileInfo => 'প্রোফাইল তথ্য';
  @override
  String get name => 'নাম';
  @override
  String get email => 'ইমেইল';
  @override
  String get address => 'ঠিকানা';
  @override
  String get noAddressSpecified => 'কোনো ঠিকানা দেওয়া হয়নি';
  @override
  String get signInToViewProfile =>
      'আপনার প্রোফাইল দেখতে এবং রিপোর্ট পরিচালনা করতে সাইন ইন করুন।';

  @override
  String get welcomeBack => 'স্বাগতম';
  @override
  String get signInToYourAccount => 'আপনার অ্যাকাউন্টে সাইন ইন করুন';
  @override
  String get password => 'পাসওয়ার্ড';
  @override
  String get forgotPassword => 'পাসওয়ার্ড ভুলে গেছেন?';
  @override
  String get dontHaveAnAccount => 'অ্যাকাউন্ট নেই? ';
  @override
  String get alreadyHaveAnAccount => 'ইতিমধ্যে অ্যাকাউন্ট আছে? ';
  @override
  String get createAccount => 'অ্যাকাউন্ট তৈরি করুন';

  @override
  String get markAllRead => 'সব পঠিত হিসেবে চিহ্নিত করুন';
  @override
  String get clearAll => 'সব মুছুন';
  @override
  String get noNotificationsYet =>
      'এখনো কোনো সতর্কতা নেই।\nআপনার কাছাকাছি নতুন ঘটনা রিপোর্ট হলে জানানো হবে।';
}

/// Strings for the currently selected language.
final appStringsProvider = Provider<AppStrings>((ref) {
  final code = ref.watch(settingsProvider.select((s) => s.languageCode));
  return AppStrings.of(code);
});
