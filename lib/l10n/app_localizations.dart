import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fil.dart';

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fil')
  ];

  /// App title
  ///
  /// In en, this message translates to:
  /// **'iSign'**
  String get appTitle;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get tabTranslate;

  /// No description provided for @tabSigns.
  ///
  /// In en, this message translates to:
  /// **'Signs'**
  String get tabSigns;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @signsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search signs...'**
  String get signsSearchHint;

  /// No description provided for @signsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get signsFilterAll;

  /// No description provided for @signsNoSigns.
  ///
  /// In en, this message translates to:
  /// **'No signs loaded'**
  String get signsNoSigns;

  /// No description provided for @signsSeedDb.
  ///
  /// In en, this message translates to:
  /// **'Run the app to seed the database'**
  String get signsSeedDb;

  /// No description provided for @signsNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No signs match your search'**
  String get signsNoMatch;

  /// No description provided for @signsAddNew.
  ///
  /// In en, this message translates to:
  /// **'Add New Sign'**
  String get signsAddNew;

  /// No description provided for @signName.
  ///
  /// In en, this message translates to:
  /// **'Sign Name'**
  String get signName;

  /// No description provided for @signDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get signDescription;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @detailVideoNotAvail.
  ///
  /// In en, this message translates to:
  /// **'Demo video not available'**
  String get detailVideoNotAvail;

  /// No description provided for @detailHowToSign.
  ///
  /// In en, this message translates to:
  /// **'How to sign'**
  String get detailHowToSign;

  /// No description provided for @detailPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice This Sign'**
  String get detailPractice;

  /// No description provided for @detailPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get detailPlaying;

  /// No description provided for @detailPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get detailPaused;

  /// No description provided for @detailPracticeHint.
  ///
  /// In en, this message translates to:
  /// **'Tap \'Practice\' to test this sign with your camera'**
  String get detailPracticeHint;

  /// No description provided for @detailUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get detailUncategorized;

  /// No description provided for @translateGesture.
  ///
  /// In en, this message translates to:
  /// **'Gesture'**
  String get translateGesture;

  /// No description provided for @translateSpeech.
  ///
  /// In en, this message translates to:
  /// **'Speech'**
  String get translateSpeech;

  /// No description provided for @translateShowHand.
  ///
  /// In en, this message translates to:
  /// **'Show your hand to the camera'**
  String get translateShowHand;

  /// No description provided for @translateNotRecognized.
  ///
  /// In en, this message translates to:
  /// **'Sign not recognized'**
  String get translateNotRecognized;

  /// No description provided for @translateSpeak.
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get translateSpeak;

  /// No description provided for @translateShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get translateShare;

  /// No description provided for @translateClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get translateClear;

  /// No description provided for @translateListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get translateListening;

  /// No description provided for @translateTapHold.
  ///
  /// In en, this message translates to:
  /// **'Tap & Hold'**
  String get translateTapHold;

  /// No description provided for @translateToSpeak.
  ///
  /// In en, this message translates to:
  /// **'to Speak'**
  String get translateToSpeak;

  /// No description provided for @translateCameraNotAvail.
  ///
  /// In en, this message translates to:
  /// **'Camera not available'**
  String get translateCameraNotAvail;

  /// No description provided for @translateNoSpeech.
  ///
  /// In en, this message translates to:
  /// **'No speech detected'**
  String get translateNoSpeech;

  /// No description provided for @translateHoldMic.
  ///
  /// In en, this message translates to:
  /// **'Hold the mic button below to speak'**
  String get translateHoldMic;

  /// No description provided for @translateOnlyOneCamera.
  ///
  /// In en, this message translates to:
  /// **'Only one camera available on this device'**
  String get translateOnlyOneCamera;

  /// No description provided for @translateSwitchCamera.
  ///
  /// In en, this message translates to:
  /// **'Switch Camera'**
  String get translateSwitchCamera;

  /// No description provided for @settingsPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsPreferences;

  /// No description provided for @settingsProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfile;

  /// No description provided for @settingsTraining.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get settingsTraining;

  /// No description provided for @settingsDataMgmt.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get settingsDataMgmt;

  /// No description provided for @settingsCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get settingsCloudSync;

  /// No description provided for @settingsEvalFeedback.
  ///
  /// In en, this message translates to:
  /// **'Evaluation & Feedback'**
  String get settingsEvalFeedback;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsOutputLang.
  ///
  /// In en, this message translates to:
  /// **'Output Language'**
  String get settingsOutputLang;

  /// No description provided for @settingsTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text Size'**
  String get settingsTextSize;

  /// No description provided for @settingsTtsSpeed.
  ///
  /// In en, this message translates to:
  /// **'TTS Speed'**
  String get settingsTtsSpeed;

  /// No description provided for @settingsDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get settingsDarkMode;

  /// No description provided for @settingsThemeColor.
  ///
  /// In en, this message translates to:
  /// **'Theme Color'**
  String get settingsThemeColor;

  /// No description provided for @settingsSyncToCloud.
  ///
  /// In en, this message translates to:
  /// **'Sync to Cloud'**
  String get settingsSyncToCloud;

  /// No description provided for @homeOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get homeOffline;

  /// No description provided for @homeHowToUse.
  ///
  /// In en, this message translates to:
  /// **'How to Use'**
  String get homeHowToUse;

  /// No description provided for @homePointCamera.
  ///
  /// In en, this message translates to:
  /// **'Point Camera'**
  String get homePointCamera;

  /// No description provided for @homeShowSign.
  ///
  /// In en, this message translates to:
  /// **'Show Sign'**
  String get homeShowSign;

  /// No description provided for @homeReadTranslation.
  ///
  /// In en, this message translates to:
  /// **'Read Translation'**
  String get homeReadTranslation;

  /// No description provided for @homeStartTranslate.
  ///
  /// In en, this message translates to:
  /// **'Start Translate'**
  String get homeStartTranslate;

  /// No description provided for @homeRecentTranslations.
  ///
  /// In en, this message translates to:
  /// **'Recent Translations'**
  String get homeRecentTranslations;

  /// No description provided for @onboardingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to iSign'**
  String get onboardingWelcome;

  /// No description provided for @onboardingHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'How It Works'**
  String get onboardingHowItWorks;

  /// No description provided for @onboardingFullyOffline.
  ///
  /// In en, this message translates to:
  /// **'Fully Offline'**
  String get onboardingFullyOffline;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Up Your Profile'**
  String get profileTitle;

  /// No description provided for @profileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself'**
  String get profileSubtitle;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Your Name'**
  String get profileName;

  /// No description provided for @profileIAm.
  ///
  /// In en, this message translates to:
  /// **'I am a...'**
  String get profileIAm;

  /// No description provided for @profilePreferredLang.
  ///
  /// In en, this message translates to:
  /// **'Preferred Language'**
  String get profilePreferredLang;

  /// No description provided for @profileDeafUser.
  ///
  /// In en, this message translates to:
  /// **'Deaf User'**
  String get profileDeafUser;

  /// No description provided for @profileHearingUser.
  ///
  /// In en, this message translates to:
  /// **'Hearing User'**
  String get profileHearingUser;

  /// No description provided for @evalTitle.
  ///
  /// In en, this message translates to:
  /// **'Evaluation Report'**
  String get evalTitle;

  /// No description provided for @evalSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get evalSessions;

  /// No description provided for @evalAttempted.
  ///
  /// In en, this message translates to:
  /// **'Attempted'**
  String get evalAttempted;

  /// No description provided for @evalRecognized.
  ///
  /// In en, this message translates to:
  /// **'Recognized'**
  String get evalRecognized;

  /// No description provided for @evalAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get evalAccuracy;

  /// No description provided for @evalExportReport.
  ///
  /// In en, this message translates to:
  /// **'Export Report'**
  String get evalExportReport;

  /// No description provided for @evalExportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get evalExportPdf;

  /// No description provided for @evalExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get evalExportCsv;

  /// No description provided for @feedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit Feedback'**
  String get feedbackTitle;

  /// No description provided for @feedbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We value your input!'**
  String get feedbackSubtitle;

  /// No description provided for @feedbackSelectSign.
  ///
  /// In en, this message translates to:
  /// **'Select a Sign'**
  String get feedbackSelectSign;

  /// No description provided for @feedbackRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get feedbackRating;

  /// No description provided for @feedbackComment.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get feedbackComment;

  /// No description provided for @feedbackPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get feedbackPoor;

  /// No description provided for @feedbackFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get feedbackFair;

  /// No description provided for @feedbackGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get feedbackGood;

  /// No description provided for @feedbackVeryGood.
  ///
  /// In en, this message translates to:
  /// **'Very Good'**
  String get feedbackVeryGood;

  /// No description provided for @feedbackExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get feedbackExcellent;

  /// No description provided for @recorderSelectSign.
  ///
  /// In en, this message translates to:
  /// **'Select FSL Sign'**
  String get recorderSelectSign;

  /// No description provided for @recorderBurst.
  ///
  /// In en, this message translates to:
  /// **'Burst'**
  String get recorderBurst;

  /// No description provided for @recorderContinuous.
  ///
  /// In en, this message translates to:
  /// **'Continuous'**
  String get recorderContinuous;

  /// No description provided for @recorderBurstHint.
  ///
  /// In en, this message translates to:
  /// **'Record 30 frames'**
  String get recorderBurstHint;

  /// No description provided for @recorderStart.
  ///
  /// In en, this message translates to:
  /// **'Start Recording'**
  String get recorderStart;

  /// No description provided for @recorderStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get recorderStop;

  /// No description provided for @recorderSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get recorderSaving;

  /// No description provided for @recorderNoDesc.
  ///
  /// In en, this message translates to:
  /// **'No description available for this sign.'**
  String get recorderNoDesc;

  /// No description provided for @recorderSamples.
  ///
  /// In en, this message translates to:
  /// **'Samples for this sign:'**
  String get recorderSamples;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @textSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get textSizeSmall;

  /// No description provided for @textSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get textSizeMedium;

  /// No description provided for @textSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get textSizeLarge;

  /// No description provided for @backToExit.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get backToExit;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'fil'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'fil': return AppLocalizationsFil();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
