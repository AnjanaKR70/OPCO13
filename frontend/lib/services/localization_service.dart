import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  bool _isEnglish = true;

  bool get isEnglish => _isEnglish;

  LocalizationService() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnglish = prefs.getBool('isEnglish') ?? true;
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    _isEnglish = !_isEnglish;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isEnglish', _isEnglish);
    notifyListeners();
  }

  String translate(String key) {
    if (_isEnglish) return key;
    return _malayalamDictionary[key] ?? key;
  }

  static const Map<String, String> _malayalamDictionary = {
    // ── Bottom Nav ──
    'Home': 'ഹോം',
    'Alert': 'അലർട്ട്',
    'Connect': 'കണക്ട്',
    'Settings': 'സെറ്റിംഗ്സ്',

    // ── Home Tab ──
    "You're protected": "നിങ്ങൾ സുരക്ഷിതരാണ്",
    "Scanning active": "സ്കാനിംഗ് സജീവമാണ്",
    "Checked today": "ഇന്ന് പരിശോധിച്ചത്",
    "This week": "ഈ ആഴ്ച",
    "Safety tip": "സുരക്ഷാ ടിപ്പ്",
    "Recent activity": "സമീപകാല പ്രവർത്തനം",
    "View all": "എല്ലാം കാണുക",

    // ── Safety Tips (Home rotating) ──
    "We scan every file shared to you on WhatsApp before you open it.": "നിങ്ങൾ തുറക്കുന്നതിന് മുമ്പ് WhatsApp-ൽ ഷെയർ ചെയ്ത എല്ലാ ഫയലുകളും ഞങ്ങൾ സ്കാൻ ചെയ്യുന്നു.",
    "AI-generated images are checked automatically.": "AI-ജനറേറ്റ് ചെയ്ത ചിത്രങ്ങൾ സ്വയമേവ പരിശോധിക്കപ്പെടുന്നു.",
    "Suspicious links are flagged before you tap them.": "സംശയാസ്പദമായ ലിങ്കുകൾ ടാപ്പ് ചെയ്യുന്നതിന് മുമ്പ് ഫ്ലാഗ് ചെയ്യപ്പെടുന്നു.",
    "Your SMS messages are filtered for known phishing attempts.": "അറിയപ്പെടുന്ന ഫിഷിംഗ് ശ്രമങ്ങൾക്കായി നിങ്ങളുടെ SMS സന്ദേശങ്ങൾ ഫിൽറ്റർ ചെയ്യപ്പെടുന്നു.",

    // ── Alerts Tab ──
    "Search by date or keyword": "തീയതിയോ കീവേർഡോ ഉപയോഗിച്ച് തിരയുക",
    "All": "എല്ലാം",
    "High risk": "ഉയർന്ന അപകടസാധ്യത",
    "Medium risk": "ഇടത്തരം അപകടസാധ്യത",
    "Safe": "സുരക്ഷിതം",
    "Filter": "ഫിൽറ്റർ",
    "No alerts found.": "അലർട്ടുകളൊന്നും കണ്ടെത്തിയില്ല.",
    "Today": "ഇന്ന്",
    "Yesterday": "ഇന്നലെ",

    // ── Connect Tab ──
    "Family Circle": "കുടുംബം",
    "SOS Contacts": "അടിയന്തര കോൺടാക്റ്റുകൾ",
    "Community": "കമ്മ്യൂണിറ്റി",
    "If you've received something suspicious, you're not alone.\nHere's who can help.":
        "സംശയാസ്പദമായ എന്തെങ്കിലും ലഭിച്ചോ?\nനിങ്ങൾ ഒറ്റയ്ക്കല്ല. ഇവർ സഹായിക്കും.",
    "Report a scam": "ഒരു തട്ടിപ്പ് റിപ്പോർട്ട് ചെയ്യുക",
    "File an online complaint on the national portal": "ദേശീയ പോർട്ടലിൽ ഓൺലൈൻ പരാതി ഫയൽ ചെയ്യുക",
    "Cyberdome Kerala": "സൈബർഡോം കേരള",
    "Email the Kerala Cyberdome team directly": "കേരള സൈബർഡോം ടീമിന് നേരിട്ട് ഇമെയിൽ ചെയ്യുക",
    "Reporting a suspected scam": "സംശയാസ്പദമായ തട്ടിപ്പ് റിപ്പോർട്ട് ചെയ്യുന്നു",
    "Nearest cyber cell": "ഏറ്റവും അടുത്തുള്ള സൈബർ സെൽ",
    "Cyber Cell, Thiruvananthapuram": "സൈബർ സെൽ, തിരുവനന്തപുരം",
    "~3.2 km away": "~3.2 km ദൂരത്തിൽ",
    "Directions": "ദിശകൾ",
    "National cyber fraud helpline": "ദേശീയ സൈബർ തട്ടിപ്പ് ഹെൽപ്‌ലൈൻ",
    "Contact details sourced from official Government of Kerala Cyberdome channels.":
        "കേരള സർക്കാർ സൈബർഡോം ചാനലുകളിൽ നിന്ന് ശേഖരിച്ച ബന്ധപ്പെടാനുള്ള വിശദാംശങ്ങൾ.",

    // ── Settings Tab ──
    "Permissions": "അനുമതികൾ",
    "Storage access": "സ്റ്റോറേജ് ആക്സസ്",
    "Phone access": "ഫോൺ ആക്സസ്",
    "Location access": "ലൊക്കേഷൻ ആക്സസ്",
    "SMS access": "SMS ആക്സസ്",
    "Google account": "ഗൂഗിൾ അക്കൗണ്ട്",
    "App protection": "ആപ്പ് സംരക്ഷണം",
    "Choose which apps are scanned for scam content": "ഏത് ആപ്പുകളാണ് തട്ടിപ്പ് ഉള്ളടക്കത്തിനായി സ്കാൻ ചെയ്യേണ്ടതെന്ന് തിരഞ്ഞെടുക്കുക",
    "Protect all apps": "എല്ലാ ആപ്പുകളും സംരക്ഷിക്കുക",
    "All apps are being monitored": "എല്ലാ ആപ്പുകളും നിരീക്ഷിക്കപ്പെടുന്നു",
    "Customize per app below": "ഓരോ ആപ്പിനും ചുവടെ ക്രമീകരിക്കുക",

    // ── SOS Alert Screen ──
    "CRITICAL THREAT DETECTED!": "ഗുരുതരമായ ഭീഷണി കണ്ടെത്തി!",
    "CRITICAL THREAT DETECTED": "ഗുരുതരമായ ഭീഷണി കണ്ടെത്തി",
    "The malicious file has been blocked and safely quarantined.": "ക്ഷുദ്രകരമായ ഫയൽ തടയുകയും സുരക്ഷിതമായി ക്വാറന്റൈൻ ചെയ്യുകയും ചെയ്തു.",
    "SUSPICIOUS FILE DETECTED": "സംശയാസ്പദമായ ഫയൽ കണ്ടെത്തി",
    "This file has suspicious indicators. Proceed with extreme caution.": "ഈ ഫയലിൽ സംശയാസ്പദമായ സൂചകങ്ങളുണ്ട്. അതീവ ജാഗ്രതയോടെ തുടരുക.",
    "FILE IS SAFE": "ഫയൽ സുരക്ഷിതമാണ്",
    "No threats detected. The file is safe to open.": "ഭീഷണികളൊന്നും കണ്ടെത്തിയില്ല. ഫയൽ തുറക്കാൻ സുരക്ഷിതമാണ്.",
    "DISMISS": "ഡിസ്മിസ്",
    "VIEW": "കാണുക",
    "Received from: ": "ഇതിൽ നിന്നും ലഭിച്ചത്: ",
    "Received from": "ഇതിൽ നിന്നും ലഭിച്ചത്",
    "Device: ": "ഉപകരണം: ",
    "Phone": "ഫോൺ",
    "Unknown Device": "അജ്ഞാതമായ ഉപകരണം",

    // ── Auth & Login ──
    "Welcome to SCAMundo": "SCAMundo-ലേക്ക് സ്വാഗതം",
    "Enter your phone number to continue.": "തുടരാൻ നിങ്ങളുടെ ഫോൺ നമ്പർ നൽകുക.",
    "Full Name": "മുഴുവൻ പേര്",
    "Phone Number": "ഫോൺ നമ്പർ",
    "Please enter your name": "ദയവായി നിങ്ങളുടെ പേര് നൽകുക",
    "Please enter phone number": "ദയവായി ഫോൺ നമ്പർ നൽകുക",
    "Enter a valid 10-digit phone number": "സാധുവായ 10-അക്ക ഫോൺ നമ്പർ നൽകുക",
    "Enter OTP": "ഒടിപി നൽകുക",
    "Get OTP": "ഒടിപി നേടുക",
    "Resend OTP": "ഒടിപി വീണ്ടും അയക്കുക",
    "OTP generated and auto-filled!": "ഒടിപി ജനറേറ്റ് ചെയ്തു ഓട്ടോ-ഫിൽ ചെയ്തു!",
    "Failed to generate OTP. Check backend.": "ഒടിപി ജനറേറ്റ് ചെയ്യുന്നതിൽ പരാജയപ്പെട്ടു.",
    "Login": "ലോഗിൻ",
    "Create Account": "അക്കൗണ്ട് സൃഷ്ടിക്കുക",
    "Don't have an account? Sign up": "അക്കൗണ്ട് ഇല്ലേ? സൈൻ അപ്പ് ചെയ്യുക",
    "Already have an account? Sign in": "നേരത്തെ അക്കൗണ്ട് ഉണ്ടോ? ലോഗിൻ ചെയ്യുക",

    // ── Permissions Onboarding ──
    "Storage Access": "സ്റ്റോറേജ് ആക്സസ്",
    "We need access to your local files to securely store verification data.": "സ്ഥിരീകരണ ഡാറ്റ സുരക്ഷിതമായി സൂക്ഷിക്കാൻ നിങ്ങളുടെ ലോക്കൽ ഫയലുകളിലേക്ക് ആക്സസ് ആവശ്യമാണ്.",
    "Phone Access": "ഫോൺ ആക്സസ്",
    "Allows you to make emergency SOS calls directly from the app.": "ആപ്പിൽ നിന്ന് നേരിട്ട് എമർജൻസി SOS കോളുകൾ ചെയ്യാൻ നിങ്ങളെ അനുവദിക്കുന്നു.",
    "Location Access": "ലൊക്കേഷൻ ആക്സസ്",
    "Helps locate the nearest cyber cell and provide location-aware safety alerts.": "ഏറ്റവും അടുത്തുള്ള സൈബർ സെൽ കണ്ടെത്താനും ലൊക്കേഷൻ അടിസ്ഥാനമാക്കിയുള്ള സുരക്ഷാ അലർട്ടുകൾ നൽകാനും സഹായിക്കുന്നു.",
    "SMS Access": "SMS ആക്സസ്",
    "Helps us scan incoming messages for potential phishing links.": "സാധ്യതയുള്ള ഫിഷിംഗ് ലിങ്കുകൾക്കായി ഇൻകമിംഗ് സന്ദേശങ്ങൾ സ്കാൻ ചെയ്യാൻ സഹായിക്കുന്നു.",
    "Google Sign-In": "ഗൂഗിൾ സൈൻ-ഇൻ",
    "Connect your Gmail to detect fraudulent emails and alerts.": "വ്യാജ ഇമെയിലുകളും അലർട്ടുകളും കണ്ടെത്താൻ നിങ്ങളുടെ Gmail കണക്റ്റുചെയ്യുക.",
    "Display Over Apps": "മറ്റ് ആപ്പുകൾക്ക് മുകളിൽ കാണിക്കുക",
    "Required to instantly show the SOS screen when a threat is detected.": "ഒരു ഭീഷണി കണ്ടെത്തുമ്പോൾ തന്നെ SOS സ്‌ക്രീൻ കാണിക്കാൻ ആവശ്യമാണ്.",
    "Permission blocked by OS. Please enable in Settings.": "അനുമതി OS തടഞ്ഞു. ദയവായി ക്രമീകരണങ്ങളിൽ പ്രവർത്തനക്ഷമമാക്കുക.",
    "Permission denied. You can enable it later.": "അനുമതി നിഷേധിച്ചു. നിങ്ങൾക്ക് ഇത് പിന്നീട് പ്രവർത്തനക്ഷമമാക്കാം.",
    "Allow": "അനുവദിക്കുക",
    "Not now": "ഇപ്പോൾ വേണ്ട",
    "To protect you from digital threats, SCAMundo needs a few permissions to scan files and messages securely.": "ഡിജിറ്റൽ ഭീഷണികളിൽ നിന്ന് നിങ്ങളെ സംരക്ഷിക്കാൻ, ഫയലുകളും സന്ദേശങ്ങളും സുരക്ഷിതമായി സ്കാൻ ചെയ്യാൻ SCAMundo-ക്ക് ചില അനുമതികൾ ആവശ്യമാണ്.",
    "Get Started": "തുടങ്ങുക",

    // ── Scan Overlay & Results ──
    "View details": "വിശദാംശങ്ങൾ കാണുക",
    "Dismiss": "ഡിസ്മിസ്",
    "High risk detected!": "ഉയർന്ന അപകടസാധ്യത കണ്ടെത്തി!",
    "Possible risk detected.": "സാധ്യമായ അപകടസാധ്യത കണ്ടെത്തി.",
    "We found something suspicious:": "ഞങ്ങൾ സംശയാസ്പമായ ഒന്ന് കണ്ടെത്തി:",
    "Invalid OTP format": "അസാധുവായ ഒടിപി ഫോർമാറ്റ്",
    "Please enter OTP sent sequentially to device": "ദയവായി ഉപകരണത്തിലേക്ക് അയച്ച ഒടിപി നൽകുക",

    // ── Profile ──
    "Edit Profile": "പ്രൊഫൈൽ തിരുത്തുക",
    "Log out": "ലോഗ് ഔട്ട്",
    "Save Changes": "മാറ്റങ്ങൾ സംരക്ഷിക്കുക",
    "Cancel": "റദ്ദാക്കുക",
    "Account": "അക്കൗണ്ട്",
    "Privacy": "സ്വകാര്യത",
    "App Version": "ആപ്പ് പതിപ്പ്",
    "John Doe": "ജോൺ ഡോ",

    // ── Empty/Error States ──
    "No alerts yet": "ഇതുവരെ അലർട്ടുകളൊന്നുമില്ല",
    "Not logged in": "ലോഗിൻ ചെയ്തിട്ടില്ല",
    "Could not reach the server": "സെർവറുമായി ബന്ധപ്പെടാൻ കഴിഞ്ഞില്ല",
    "Failed to load alerts": "അലർട്ടുകൾ ലോഡ് ചെയ്യുന്നതിൽ പരാജയപ്പെട്ടു",
    "Retry": "വീണ്ടും ശ്രമിക്കുക",
    "Loading...": "ലോഡ് ചെയ്യുന്നു...",

    // ── Overlay / Threat Details ──
    "Threat Level": "ഭീഷണി നില",
    "Confidence": "കോൺഫിഡൻസ്",
    "File": "ഫയൽ",
    "Reason": "കാരണം",
    "Risk Level": "റിസ്ക് ലെവൽ",

    // ── Months ──
    "January": "ജനുവരി",
    "February": "ഫെബ്രുവരി",
    "March": "മാർച്ച്",
    "April": "ഏപ്രിൽ",
    "May": "മെയ്",
    "June": "ജൂൺ",
    "July": "ജൂലൈ",
    "August": "ആഗസ്റ്റ്",
    "September": "സെപ്റ്റംബർ",
    "October": "ഒക്ടോബർ",
    "November": "നവംബർ",
    "December": "ഡിസംബർ",
  };
}
