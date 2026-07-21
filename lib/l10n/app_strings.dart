import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../store.dart';

/// Lightweight, incremental localization: a key→string map per language.
/// Keys not yet translated for a language fall back to English, so the app
/// is always usable while translation coverage grows. Material widgets
/// (date pickers, etc.) are localized via flutter_localizations in main.dart.
class AppStrings {
  static const supported = ['en', 'hi'];

  static const languageNames = {
    'en': 'English',
    'hi': 'हिन्दी',
  };

  static String get(String lang, String key) {
    final table = lang == 'hi' ? _hi : _en;
    return table[key] ?? _en[key] ?? key;
  }

  static const Map<String, String> _en = {
    // Navigation
    'nav_home': 'Home',
    'nav_timeline': 'Timeline',
    'nav_journal': 'Journal',
    'nav_ask': 'Ask',
    'nav_more': 'More',
    // Dashboard
    'your_baby': 'Your baby',
    'your_twins': 'Your twins',
    'trimester': 'Trimester',
    'days_to_edd': 'days to EDD',
    'days_to_window': 'days to arrival window',
    'in_window': 'In the typical arrival window',
    'typical_arrival': 'Typical arrival',
    'this_week': 'This week',
    'no_appointment': 'No upcoming appointment',
    'add_from_more': 'Add one from the More tab',
    'todays_medicines': "Today's medicines",
    'water': 'Water',
    'weight': 'Weight',
    'glasses': 'glasses',
    'not_logged_yet': 'Not logged yet',
    'tap_to_log': 'Tap to log',
    'kick_counter': 'Kick counter',
    'growth': 'Growth',
    'read_a_scan': 'Read a scan report',
    'read_a_scan_sub': 'Photograph the pages — AI fills in the measurements',
    'ask_bumpbuddy': 'Ask',
    'ask_sub': 'Questions answered from YOUR data',
    'edu_only':
        "Educational information only — always follow your doctor's advice.",
    // Onboarding
    'welcome_title': 'Welcome to My Pregnancy',
    'welcome_sub':
        'One place for your pregnancy — weeks, scans, symptoms and reminders. Built for singletons and twins.',
    'welcome_disclaimer':
        'My Pregnancy is for education and organization only. It never replaces your doctor — always follow your care team\'s advice.',
    'continue': 'Continue',
    'how_many': 'How many little ones?',
    'how_many_sub': 'The whole app adapts to your answer.',
    'one_baby': 'One baby',
    'singleton': 'Singleton pregnancy',
    'twins': 'Twins',
    'start_tracking': 'Start tracking',
    // Baby view
    'your_babies': 'Your babies',
    'week': 'Week',
    'about_size_of': 'About the size of a',
    'skin_tone': 'Skin tone',
    'baby_illustration_note':
        'A friendly illustration that grows with your weeks — not a medical image of your baby.',
    // More / settings
    'language': 'Language',
    'choose_language': 'Choose language',
    // Common
    'save': 'Save',
    'cancel': 'Cancel',
    'add': 'Add',
  };

  // Hindi (Devanagari). Loanwords kept where they read naturally in everyday
  // Indian usage (scan, report). Medical phrasing kept simple and non-alarming;
  // a native/clinical review is recommended before wide release.
  static const Map<String, String> _hi = {
    'nav_home': 'होम',
    'nav_timeline': 'टाइमलाइन',
    'nav_journal': 'डायरी',
    'nav_ask': 'पूछें',
    'nav_more': 'और',
    'your_baby': 'आपका शिशु',
    'your_twins': 'आपके जुड़वाँ',
    'trimester': 'तिमाही',
    'days_to_edd': 'दिन EDD में शेष',
    'days_to_window': 'दिन जन्म-अवधि में शेष',
    'in_window': 'सामान्य जन्म-अवधि में',
    'typical_arrival': 'सामान्य जन्म',
    'this_week': 'इस सप्ताह',
    'no_appointment': 'कोई आगामी अपॉइंटमेंट नहीं',
    'add_from_more': "'और' टैब से जोड़ें",
    'todays_medicines': 'आज की दवाइयाँ',
    'water': 'पानी',
    'weight': 'वज़न',
    'glasses': 'गिलास',
    'not_logged_yet': 'अभी दर्ज नहीं',
    'tap_to_log': 'दर्ज करने के लिए टैप करें',
    'kick_counter': 'किक काउंटर',
    'growth': 'वृद्धि',
    'read_a_scan': 'स्कैन रिपोर्ट पढ़ें',
    'read_a_scan_sub': 'पन्नों की फ़ोटो लें — AI माप भर देगा',
    'ask_bumpbuddy': 'पूछें',
    'ask_sub': 'आपके अपने डेटा से उत्तर',
    'edu_only':
        'केवल जानकारी के लिए — हमेशा अपने डॉक्टर की सलाह मानें।',
    'welcome_title': 'My Pregnancy में आपका स्वागत है',
    'welcome_sub':
        'आपकी प्रेग्नेंसी सब एक जगह — सप्ताह, स्कैन, लक्षण और रिमाइंडर। एक और जुड़वाँ शिशुओं दोनों के लिए।',
    'welcome_disclaimer':
        'My Pregnancy केवल जानकारी और व्यवस्था के लिए है। यह आपके डॉक्टर का विकल्प नहीं है — हमेशा अपनी देखभाल टीम की सलाह मानें।',
    'continue': 'आगे बढ़ें',
    'how_many': 'कितने नन्हे मेहमान?',
    'how_many_sub': 'पूरा ऐप आपके उत्तर के अनुसार ढल जाता है।',
    'one_baby': 'एक शिशु',
    'singleton': 'एकल गर्भ',
    'twins': 'जुड़वाँ',
    'start_tracking': 'ट्रैकिंग शुरू करें',
    'your_babies': 'आपके शिशु',
    'week': 'सप्ताह',
    'about_size_of': 'लगभग इतने आकार का:',
    'skin_tone': 'त्वचा का रंग',
    'baby_illustration_note':
        'एक स्नेहपूर्ण चित्र जो आपके सप्ताहों के साथ बढ़ता है — यह आपके शिशु की मेडिकल छवि नहीं है।',
    'language': 'भाषा',
    'choose_language': 'भाषा चुनें',
    'save': 'सहेजें',
    'cancel': 'रद्द करें',
    'add': 'जोड़ें',
  };
}

extension L10nContext on BuildContext {
  /// Localized string for [key] in the currently selected language.
  String tr(String key) =>
      AppStrings.get(Provider.of<AppStore>(this).languageCode, key);
}
