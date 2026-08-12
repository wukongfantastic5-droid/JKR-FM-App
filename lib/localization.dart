import 'package:flutter/material.dart';

class AppLocalizations {
  static const Map<String, Map<String, String>> _strings = {
    'appTitle': {'en': 'JKR FM Guide', 'bm': 'Panduan FM JKR'},

    'homeSubtitle': {'en': 'Interview Prep & Mechanical Maintenance', 'bm': 'Persediaan Temuduga & Penyelenggaraan Mekanikal'},
    'btnInterview': {'en': 'Interview (IV)', 'bm': 'Temuduga (IV)'},
    'btnIVSub': {'en': 'JKR FM interview questions & answers by topic', 'bm': 'Soalan & jawapan temuduga FM JKR mengikut topik'},
    'btnGerakKerja': {'en': 'Job Scope (Gerak Kerja)', 'bm': 'Skop Kerja (Gerak Kerja)'},
    'btnGKSub': {'en': 'Mechanical systems maintenance & HVAC flow', 'bm': 'Penyelenggaraan sistem mekanikal & aliran HVAC'},
    'btnBaikpulih': {'en': 'Repair Guide (Panduan Baikpulih)', 'bm': 'Panduan Baikpulih'},
    'btnBPSub': {'en': 'Workflow: complaint → scope check → docs → approval → permit → repair', 'bm': 'Aliran kerja: aduan → semak skop → dokumen → kelulusan → permit → baikpulih'},

    'ivTitle': {'en': 'Interview Preparation', 'bm': 'Persediaan Temuduga'},
    'ivSubtitle': {'en': 'topics', 'bm': 'topik'},
    'ivMethod': {'en': 'SAAR method', 'bm': 'Kaedah SAAR'},

    'gkTitle': {'en': 'Job Scope (Gerak Kerja)', 'bm': 'Skop Kerja (Gerak Kerja)'},
    'gkSubtitle': {'en': 'Select a system to view flow diagram, JKR PM/CM schedule & troubleshooting', 'bm': 'Pilih sistem untuk lihat gambar rajah aliran, jadual PM/CM JKR & penyelesaian masalah'},

    'tabFlow': {'en': 'Flow', 'bm': 'Aliran'},
    'tabPMCM': {'en': 'PM/CM JKR', 'bm': 'PM/CM JKR'},
    'tabTroubleshoot': {'en': 'Troubleshoot', 'bm': 'Penyelesaian'},

    'tapToZoom': {'en': 'Tap to enlarge • Scroll to zoom', 'bm': 'Tekan untuk besarkan • Skrol zum'},
    'sysInfo': {'en': 'Tap the image to view full size with zoom. This system image shows the complete flow and components.', 'bm': 'Tekan imej untuk paparan penuh dengan zum. Imej sistem ini menunjukkan aliran dan komponen lengkap.'},

    'jkrSchedule': {'en': 'JKR PPM Schedule', 'bm': 'Jadual PPM JKR'},
    'refExcel': {'en': 'Refer to PPM Bangunan JKR.xlsx for full details', 'bm': 'Rujuk PPM Bangunan JKR.xlsx untuk butiran penuh'},

    'selectProblem': {'en': 'Select a problem to see causes & solutions:', 'bm': 'Pilih masalah untuk lihat punca & penyelesaian:'},
    'possibleCauses': {'en': 'Possible Causes:', 'bm': 'Punca Mungkin:'},
    'solutions': {'en': 'Solutions:', 'bm': 'Penyelesaian:'},

    'freqDaily': {'en': 'Daily', 'bm': 'Harian'},
    'freqWeekly': {'en': 'Weekly', 'bm': 'Mingguan'},
    'freqMonthly': {'en': 'Monthly', 'bm': 'Bulanan'},
    'freq3M': {'en': '3 Monthly', 'bm': '3 Bulanan'},
    'freq6M': {'en': '6 Monthly', 'bm': '6 Bulanan'},
    'freqYearly': {'en': 'Yearly', 'bm': 'Tahunan'},
    'freq5Y': {'en': '5 Yearly', 'bm': '5 Tahunan'},

    'langEN': {'en': 'EN', 'bm': 'English'},
    'langBM': {'en': 'BM', 'bm': 'Bahasa'},
    'darkMode': {'en': 'Dark', 'bm': 'Gelap'},
    'lightMode': {'en': 'Light', 'bm': 'Terang'},

    'footerDev': {'en': 'Developed by Zainal', 'bm': 'Dibangunkan oleh Zainal'},
    'footerVersion': {'en': 'Version V1.0', 'bm': 'Versi V1.0'},

    'searchHint': {'en': 'Search systems...', 'bm': 'Cari sistem...'},
    'searchHintIV': {'en': 'Search questions...', 'bm': 'Cari soalan...'},
    'noResults': {'en': 'No results found', 'bm': 'Tiada hasil'},

    'expAll': {'en': 'Expand All', 'bm': 'Kembang Semua'},
    'collAll': {'en': 'Collapse All', 'bm': 'Runtuh Semua'},
    'sysCounter': {'en': 'System', 'bm': 'Sistem'},

    'prayerFajr': {'en': 'Subuh', 'bm': 'Subuh'},
    'prayerSunrise': {'en': 'Syuruk', 'bm': 'Syuruk'},
    'prayerDhuhr': {'en': 'Zohor', 'bm': 'Zohor'},
    'prayerAsr': {'en': 'Asar', 'bm': 'Asar'},
    'prayerMaghrib': {'en': 'Maghrib', 'bm': 'Maghrib'},
    'prayerIsha': {'en': 'Isyak', 'bm': 'Isyak'},

    'nextPrayer': {'en': 'Next prayer:', 'bm': 'Solat seterusnya:'},
    'prayerToday': {'en': "Today's Prayer Times", 'bm': 'Waktu Solat Hari Ini'},
    'prayerNotifyTitle': {'en': 'Prayer Reminder', 'bm': 'Peringatan Solat'},
    'prayerSoon': {'en': '{prayer} in 15 minutes', 'bm': '{prayer} dalam 15 minit lagi'},

    'mon': {'en': 'Monday', 'bm': 'Isnin'},
    'tue': {'en': 'Tuesday', 'bm': 'Selasa'},
    'wed': {'en': 'Wednesday', 'bm': 'Rabu'},
    'thu': {'en': 'Thursday', 'bm': 'Khamis'},
    'fri': {'en': 'Friday', 'bm': 'Jumaat'},
    'sat': {'en': 'Saturday', 'bm': 'Sabtu'},
    'sun': {'en': 'Sunday', 'bm': 'Ahad'},

    'jan': {'en': 'January', 'bm': 'Januari'},
    'feb': {'en': 'February', 'bm': 'Februari'},
    'mar': {'en': 'March', 'bm': 'Mac'},
    'apr': {'en': 'April', 'bm': 'April'},
    'may': {'en': 'May', 'bm': 'Mei'},
    'jun': {'en': 'June', 'bm': 'Jun'},
    'jul': {'en': 'July', 'bm': 'Julai'},
    'aug': {'en': 'August', 'bm': 'Ogos'},
    'sep': {'en': 'September', 'bm': 'September'},
    'oct': {'en': 'October', 'bm': 'Oktober'},
    'nov': {'en': 'November', 'bm': 'November'},
    'dec': {'en': 'December', 'bm': 'Disember'},

    'bpTitle': {'en': 'Repair Guide (Panduan Baikpulih)', 'bm': 'Panduan Baikpulih'},
    'bpSubtitle': {'en': 'Complete workflow from complaint to repair completion', 'bm': 'Aliran kerja lengkap dari aduan hingga siap baikpulih'},

    'bpStep1Title': {'en': '1. Receive Complaint', 'bm': '1. Terima Aduan'},
    'bpStep1Desc': {'en': 'Receive complaint from KKR, JKR, or FMI (Facilities Management Integrated). Record all details for reference.', 'bm': 'Terima aduan dari KKR, JKR, atau FMI (Facilities Management Integrated). Rekod semua butiran untuk rujukan.'},
    'bpSourceKKR': {'en': 'KKR (Ministry of Works)', 'bm': 'KKR (Kementerian Kerja Raya)'},
    'bpSourceJKR': {'en': 'JKR (Public Works Department)', 'bm': 'JKR (Jabatan Kerja Raya)'},
    'bpSourceFMI': {'en': 'FMI (Facilities Management Integrated)', 'bm': 'FMI (Facilities Management Integrated)'},

    'bpStep2Title': {'en': '2. Verify Scope', 'bm': '2. Semak Skop'},
    'bpStep2Desc': {'en': 'Check if this problem is within our contract scope. Refer to PPM Bangunan JKR.xlsx as the reference for JKR coverage.', 'bm': 'Semak sama ada masalah ini dalam skop kontrak kita. Rujuk PPM Bangunan JKR.xlsx sebagai rujukan liputan JKR.'},
    'bpInScope': {'en': 'Within Scope — Proceed', 'bm': 'Dalam Skop — Teruskan'},
    'bpOutScope': {'en': 'Out of Scope — Inform KKR/JKR', 'bm': 'Luar Skop — Maklumkan KKR/JKR'},

    'bpStep3Title': {'en': '3. Prepare Documents', 'bm': '3. Sedia Dokumen'},
    'bpStep3Desc': {'en': 'Prepare formal documents to submit to JKR/KKR including incident report, formal letter, and cost proposal.', 'bm': 'Sedia dokumen rasmi untuk dihantar ke JKR/KKR termasuk laporan insiden, surat rasmi, dan cadangan kos.'},
    'bpDocIncident': {'en': 'Incident / Complaint Report', 'bm': 'Laporan Insiden / Aduan'},
    'bpDocLetter': {'en': 'Formal Letter to JKR/KKR', 'bm': 'Surat Rasmi kepada JKR/KKR'},
    'bpDocBudget': {'en': 'Budget / Cost Proposal', 'bm': 'Cadangan Kos / Belanjawan'},

    'bpStep4Title': {'en': '4. Submit for Approval', 'bm': '4. Hantar untuk Kelulusan'},
    'bpStep4Desc': {'en': 'Submit all documents to JKR/KKR for budget approval. Wait for official approval before proceeding.', 'bm': 'Hantar semua dokumen ke JKR/KKR untuk kelulusan belanjawan. Tunggu kelulusan rasmi sebelum meneruskan.'},
    'bpApproved': {'en': 'Approved — Proceed to Permit', 'bm': 'Lulus — Terus ke Permit'},
    'bpRejected': {'en': 'Rejected — Archive Documents', 'bm': 'Ditolak — Arkib Dokumen'},

    'bpStep5Title': {'en': '5. Prepare Permit to Work', 'bm': '5. Sedia Permit Kerja'},
    'bpStep5Desc': {'en': 'Prepare work permit documentation including risk assessment, safety checklist, and method statement.', 'bm': 'Sedia dokumentasi permit kerja termasuk penilaian risiko, senarai semak keselamatan, dan penyata kaedah.'},
    'bpDocPermit': {'en': 'Permit to Work', 'bm': 'Permit Kerja'},
    'bpDocRisk': {'en': 'Risk Assessment', 'bm': 'Penilaian Risiko'},
    'bpDocChecklist': {'en': 'Safety Checklist', 'bm': 'Senarai Semak Keselamatan'},

    'bpStep6Title': {'en': '6. Execute Repair', 'bm': '6. Laksana Baikpulih'},
    'bpStep6Desc': {'en': 'Start the repair work, monitor progress, and complete with a handover report.', 'bm': 'Mulakan kerja baikpulih, pantau kemajuan, dan siapkan dengan laporan serahan.'},

    'bpViewDoc': {'en': 'View Template', 'bm': 'Lihat Templat'},
    'bpStep': {'en': 'Step', 'bm': 'Langkah'},
    'bpOf': {'en': 'of', 'bm': 'daripada'},

    'notFound': {'en': 'Image not found', 'bm': 'Imej tidak dijumpai'},
    'closeBtn': {'en': 'Close', 'bm': 'Tutup'},
  };

  static String t(String key, bool isEnglish) {
    return _strings[key]?[isEnglish ? 'en' : 'bm'] ?? key;
  }

  static String translateSectionTitle(String bmTitle, bool isEnglish) {
    if (isEnglish) {
      return _strings[bmTitle]?['en'] ?? bmTitle;
    }
    return bmTitle;
  }

  static String weekday(int weekday, bool eng) {
    const keys = ['', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return t(keys[weekday], eng);
  }

  static String month(int month, bool eng) {
    const keys = ['', 'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    return t(keys[month], eng);
  }
}

class LanguageProvider extends InheritedNotifier<ValueNotifier<bool>> {
  const LanguageProvider({
    super.key,
    required ValueNotifier<bool> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static bool isEnglish(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<LanguageProvider>()
            ?.notifier
            ?.value ??
        true;
  }

  static LanguageProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LanguageProvider>();
  }

  static ValueNotifier<bool> langNotifier(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<LanguageProvider>()!
        .notifier!;
  }
}
