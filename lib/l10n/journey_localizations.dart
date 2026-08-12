import 'package:flutter/widgets.dart';

import '../models/newcomer_journey.dart';

/// Focused translations for the settlement journey's JSON-backed guidance.
/// Official organisation and place names remain unchanged.
class JourneyLocalizations {
  const JourneyLocalizations._(this.languageCode);

  factory JourneyLocalizations.of(BuildContext context) =>
      JourneyLocalizations._(Localizations.localeOf(context).languageCode);

  /// Creates journey copy without a widget tree, primarily for validation and
  /// any future non-visual surfaces that need the same translated guidance.
  factory JourneyLocalizations.forLocale(Locale locale) =>
      JourneyLocalizations._(locale.languageCode);

  final String languageCode;

  static Iterable<String> get requiredUiKeys => {
    ..._ui['en']!.keys,
    ..._tutorialUi['en']!.keys,
    ..._screenUi['en']!.keys,
    ..._runtimeUi['en']!.keys,
  };

  String ui(String key) =>
      _ui[languageCode]?[key] ??
      _tutorialUi[languageCode]?[key] ??
      _screenUi[languageCode]?[key] ??
      _runtimeUi[languageCode]?[key] ??
      _ui['en']?[key] ??
      _tutorialUi['en']?[key] ??
      _screenUi['en']?[key] ??
      _runtimeUi['en']?[key] ??
      key;

  String message(String key, Map<String, Object> values) {
    var result = ui(key);
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return result;
  }

  String weekday(int weekday) => ui('weekday$weekday');

  String transportMode(String source) => switch (source) {
    'Train' => ui('modeTrain'),
    'Bus' => ui('modeBus'),
    'Ferry' => ui('modeFerry'),
    'Light rail' => ui('modeLightRail'),
    'Bike' => ui('modeBike'),
    'Walk' => ui('modeWalk'),
    _ => source,
  };

  String title(NewcomerJourneyTask task) =>
      _tasks[languageCode]?[task.id]?.title ??
      _additionalTitles[languageCode]?[task.id] ??
      task.title;

  String summary(NewcomerJourneyTask task) =>
      _tasks[languageCode]?[task.id]?.summary ??
      (_additionalTitles[languageCode]?[task.id] == null
          ? task.summary
          : _additionalSummary(languageCode, title(task)));

  bool hasTask(String taskId) => _taskSections.containsKey(taskId);

  String? titleForTaskId(String taskId) =>
      _tasks[languageCode]?[taskId]?.title ??
      _additionalTitles[languageCode]?[taskId];

  String? summaryForTaskId(String taskId) {
    final translated = _tasks[languageCode]?[taskId]?.summary;
    if (translated != null) return translated;
    final title = _additionalTitles[languageCode]?[taskId];
    return title == null ? null : _additionalSummary(languageCode, title);
  }

  String? sectionForTaskId(String taskId) {
    final source = _taskSections[taskId];
    return source == null ? null : section(source);
  }

  String action(NewcomerJourneyTask task) =>
      _tasks[languageCode]?[task.id]?.action ??
      (_additionalTitles[languageCode]?[task.id] == null
          ? task.actionLabel
          : _additionalAction(languageCode));

  static String _additionalSummary(String code, String title) => switch (code) {
    'zh' => '今天了解“$title”，并在需要时使用应用中的本地地图、服务和社区信息。',
    'ko' => '오늘 “$title” 단계를 알아보고 필요할 때 앱의 지역 지도, 서비스 및 커뮤니티 정보를 활용하세요.',
    'it' =>
      'Oggi completa “$title” e usa la mappa, i servizi e le informazioni della comunità disponibili nell’app.',
    'hi' =>
      'आज “$title” चरण को समझें और ज़रूरत पड़ने पर ऐप के स्थानीय मानचित्र, सेवाओं और सामुदायिक जानकारी का उपयोग करें।',
    _ => title,
  };

  static String _additionalAction(String code) => switch (code) {
    'zh' => '打开相关本地信息',
    'ko' => '관련 지역 정보 열기',
    'it' => 'Apri le informazioni locali',
    'hi' => 'संबंधित स्थानीय जानकारी खोलें',
    _ => 'Open local information',
  };

  String section(String source) => _sections[languageCode]?[source] ?? source;

  String progress(int completed, int total) {
    final template =
        _progressTemplates[languageCode] ?? _progressTemplates['en']!;
    return template
        .replaceAll('{completed}', '$completed')
        .replaceAll('{total}', '$total');
  }

  String verification(NewcomerJourneyTask task) =>
      (_verificationLabels[languageCode] ??
      _verificationLabels['en']!)[task.verification]!;

  String? contextNote(String taskId) =>
      _contextNotes[languageCode]?[taskId] ?? _contextNotes['en']?[taskId];

  static const _progressTemplates = <String, String>{
    'en': '{completed} of {total} steps saved to your Passport',
    'zh': '已将 {completed}/{total} 个步骤保存到社区护照',
    'ko': '패스포트에 {total}개 중 {completed}개 단계 저장됨',
    'it': '{completed} passaggi su {total} salvati nel Passaporto',
    'hi': 'पासपोर्ट में {total} में से {completed} चरण सहेजे गए',
  };

  static const _verificationLabels = <String, Map<JourneyVerification, String>>{
    'en': {
      JourneyVerification.self: 'Confirm after reading this guidance',
      JourneyVerification.qr: 'Verified by a place or event QR code',
      JourneyVerification.route: 'Verified when a mapped route is completed',
    },
    'zh': {
      JourneyVerification.self: '阅读指南后自行确认',
      JourneyVerification.qr: '通过地点或活动二维码验证',
      JourneyVerification.route: '完成地图路线后验证',
    },
    'ko': {
      JourneyVerification.self: '안내를 읽은 후 직접 확인',
      JourneyVerification.qr: '장소 또는 행사 QR 코드로 인증',
      JourneyVerification.route: '지도 경로를 완료하면 인증',
    },
    'it': {
      JourneyVerification.self: 'Conferma dopo aver letto queste indicazioni',
      JourneyVerification.qr:
          'Verificato tramite il codice QR del luogo o dell’evento',
      JourneyVerification.route:
          'Verificato al completamento di un percorso sulla mappa',
    },
    'hi': {
      JourneyVerification.self: 'यह मार्गदर्शन पढ़ने के बाद पुष्टि करें',
      JourneyVerification.qr: 'स्थान या कार्यक्रम के QR कोड से सत्यापित',
      JourneyVerification.route: 'मानचित्र वाला मार्ग पूरा होने पर सत्यापित',
    },
  };

  static const _runtimeUi = <String, Map<String, String>>{
    'en': {
      'councilIssue': 'Council issue',
      'developerTools': 'Developer tools',
    },
    'zh': {
      'councilIssue': '\u5e02\u653f\u95ee\u9898',
      'developerTools': '\u5f00\u53d1\u8005\u5de5\u5177',
    },
    'ko': {
      'councilIssue': '\uc2dc\uccad \ubbfc\uc6d0',
      'developerTools': '\uac1c\ubc1c\uc790 \ub3c4\uad6c',
    },
    'it': {
      'councilIssue': 'Problema comunale',
      'developerTools': 'Strumenti per sviluppatori',
    },
    'hi': {
      'councilIssue':
          '\u092a\u0930\u093f\u0937\u0926 \u0938\u0902\u092c\u0902\u0927\u0940 \u0938\u092e\u0938\u094d\u092f\u093e',
      'developerTools':
          '\u0921\u0947\u0935\u0932\u092a\u0930 \u091f\u0942\u0932',
    },
  };

  static const _tutorialUi = <String, Map<String, String>>{
    'en': {
      'tutorialTitle': 'Your first 30 days',
      'tutorialPage': 'Page {current} of {total}',
      'tutorialOverview': 'Open journey dashboard',
      'tutorialPages': 'Back to tutorial pages',
      'tutorialEyebrow': 'YOUR FIRST 30 DAYS',
      'tutorialIntroTitle': 'One month. One clear step at a time.',
      'tutorialIntroBody':
          'Cycle through practical little pages that introduce every part of Explore Canada Bay. Do the tasks when they suit you—your progress and useful details stay ready when you return.',
      'tutorialAppTour': 'You will learn every part of the app',
      'tutorialProgressBody':
          'Completed guidance, activities and rewards remain available in the Journey and Community Passport.',
      'tutorialDay': 'DAY {day}',
      'tutorialInApp': 'Find it in',
      'tutorialSavedIn': 'Saved in',
      'tutorialHowComplete': 'How it is completed',
      'tutorialFinishBody':
          'Return to Home for recommendations, review your story in Passport, and adjust language or account settings in Profile.',
      'tutorialBack': 'Previous page',
      'tutorialStart': 'Start',
      'tutorialNext': 'Next',
      'tutorialFinish': 'Finish',
      'tutorialSwipeHint': 'Swipe between pages',
      'nextDay': 'Next day',
      'callItADay': 'Call it a day — continue tomorrow',
      'dailyJourneyReminders': 'A gentle prompt each day',
      'dailyJourneyRemindersBody':
          'Optional notifications at 9:00 am for the next 30 days.',
      'dailyReminderPrompt': 'Day {day}: {goal}',
      'journeyNotificationTitle': 'Your Canada Bay step for today',
      'journeyNotificationChannel': 'First 30 Days',
      'journeyNotificationChannelDescription':
          'Optional daily prompts for the newcomer journey.',
      'journeyRemindersOn': 'Daily prompts are ready for the next 30 days.',
      'journeyRemindersOff': 'Daily prompts have been turned off.',
      'journeyRemindersUnavailable':
          'Notifications are unavailable or permission was not granted.',
      'addGoalToCalendar': 'Add this goal to my calendar',
      'calendarOpened': 'Calendar opened with this goal ready to add.',
      'calendarUnavailable': 'The calendar could not be opened.',
      'featureHome': 'Home',
      'featureExplore': 'Explore map and routes',
      'featureCommunity': 'Community events and groups',
      'featureServices': 'Local services',
      'featurePassport': 'Community Passport',
      'featureScan': 'Scan',
      'featureProfile': 'Profile and language',
      'featureJourney': 'First 30 Days Journey',
      'featureCommunityScan': 'Community, then Scan',
      'storedEssentials': 'Journey → Local essentials and Passport',
      'storedRoutePassport': 'Explore completion → Community Passport',
      'storedScanPassport': 'QR scan → Community Passport',
      'storedJourneyPassport': 'Journey progress → Community Passport',
    },
    'zh': {
      'tutorialTitle': '您的前30天',
      'tutorialPage': '第 {current} 页，共 {total} 页',
      'tutorialOverview': '打开旅程概览',
      'tutorialPages': '返回教程页面',
      'tutorialEyebrow': '您的前30天',
      'tutorialIntroTitle': '一个月，每次完成一个清晰步骤。',
      'tutorialIntroBody':
          '逐页了解“探索加拿大湾”的每个功能，并在适合自己的时间完成实用小任务。再次回来时，进度和已保存的信息仍会保留。',
      'tutorialAppTour': '您将了解应用的所有功能',
      'tutorialProgressBody': '已完成的指南、活动和奖励会保存在旅程和社区护照中。',
      'tutorialDay': '第 {day} 天',
      'tutorialInApp': '在此功能中查找',
      'tutorialSavedIn': '保存位置',
      'tutorialHowComplete': '完成方式',
      'tutorialFinishBody': '返回首页查看推荐，在社区护照中回顾您的经历，并在个人资料中调整语言或账户设置。',
      'tutorialBack': '上一页',
      'tutorialStart': '开始',
      'tutorialNext': '下一页',
      'tutorialFinish': '完成',
      'tutorialSwipeHint': '左右滑动切换页面',
      'nextDay': '下一天',
      'callItADay': '今天到这里——明天继续',
      'dailyJourneyReminders': '每天温馨提醒',
      'dailyJourneyRemindersBody': '可选择在接下来的30天每天上午9点接收通知。',
      'dailyReminderPrompt': '第 {day} 天：{goal}',
      'journeyNotificationTitle': '您今天的加拿大湾步骤',
      'journeyNotificationChannel': '最初30天',
      'journeyNotificationChannelDescription': '新居民旅程的可选每日提醒。',
      'journeyRemindersOn': '接下来30天的每日提醒已准备好。',
      'journeyRemindersOff': '每日提醒已关闭。',
      'journeyRemindersUnavailable': '通知不可用或未获得权限。',
      'addGoalToCalendar': '将此目标添加到日历',
      'calendarOpened': '日历已打开，此目标可供添加。',
      'calendarUnavailable': '无法打开日历。',
      'featureHome': '首页',
      'featureExplore': '探索地图和路线',
      'featureCommunity': '社区活动和团体',
      'featureServices': '本地服务',
      'featurePassport': '社区护照',
      'featureScan': '扫描',
      'featureProfile': '个人资料和语言',
      'featureJourney': '前30天旅程',
      'featureCommunityScan': '先查看社区，再扫描',
      'storedEssentials': '旅程 → 本地生活必备信息和社区护照',
      'storedRoutePassport': '探索路线完成记录 → 社区护照',
      'storedScanPassport': '二维码扫描记录 → 社区护照',
      'storedJourneyPassport': '旅程进度 → 社区护照',
    },
    'ko': {
      'tutorialTitle': '첫 30일 안내',
      'tutorialPage': '{total}페이지 중 {current}페이지',
      'tutorialOverview': '여정 대시보드 열기',
      'tutorialPages': '안내 페이지로 돌아가기',
      'tutorialEyebrow': '나의 첫 30일',
      'tutorialIntroTitle': '한 달 동안, 한 번에 하나씩.',
      'tutorialIntroBody':
          '작은 페이지를 넘기며 Explore Canada Bay의 모든 기능을 익히고 실용적인 일을 편한 때에 해 보세요. 다시 돌아와도 진행 상황과 저장한 정보는 그대로 있습니다.',
      'tutorialAppTour': '앱의 모든 기능을 익혀 보세요',
      'tutorialProgressBody': '완료한 안내, 활동과 보상은 여정과 커뮤니티 패스포트에서 다시 볼 수 있습니다.',
      'tutorialDay': '{day}일차',
      'tutorialInApp': '찾을 수 있는 곳',
      'tutorialSavedIn': '저장되는 곳',
      'tutorialHowComplete': '완료 방법',
      'tutorialFinishBody':
          '홈에서 추천을 보고, 패스포트에서 나의 기록을 확인하며, 프로필에서 언어나 계정 설정을 조정하세요.',
      'tutorialBack': '이전 페이지',
      'tutorialStart': '시작',
      'tutorialNext': '다음',
      'tutorialFinish': '완료',
      'tutorialSwipeHint': '밀어서 페이지 이동',
      'nextDay': '다음 날',
      'callItADay': '오늘은 여기까지 — 내일 계속하기',
      'dailyJourneyReminders': '매일 받는 가벼운 알림',
      'dailyJourneyRemindersBody': '선택 사항: 앞으로 30일 동안 오전 9시에 알림을 받습니다.',
      'dailyReminderPrompt': '{day}일차: {goal}',
      'journeyNotificationTitle': '오늘의 Canada Bay 한 걸음',
      'journeyNotificationChannel': '첫 30일',
      'journeyNotificationChannelDescription': '새 정착 여정을 위한 선택적 일일 알림입니다.',
      'journeyRemindersOn': '앞으로 30일간의 알림이 준비되었습니다.',
      'journeyRemindersOff': '일일 알림을 껐습니다.',
      'journeyRemindersUnavailable': '알림을 사용할 수 없거나 권한이 허용되지 않았습니다.',
      'addGoalToCalendar': '이 목표를 캘린더에 추가',
      'calendarOpened': '목표를 추가할 수 있도록 캘린더를 열었습니다.',
      'calendarUnavailable': '캘린더를 열 수 없습니다.',
      'featureHome': '홈',
      'featureExplore': '탐색 지도와 경로',
      'featureCommunity': '커뮤니티 행사와 모임',
      'featureServices': '지역 서비스',
      'featurePassport': '커뮤니티 패스포트',
      'featureScan': '스캔',
      'featureProfile': '프로필과 언어',
      'featureJourney': '첫 30일 여정',
      'featureCommunityScan': '커뮤니티 확인 후 스캔',
      'storedEssentials': '여정 → 지역 생활 필수 정보와 패스포트',
      'storedRoutePassport': '탐색 경로 완료 기록 → 커뮤니티 패스포트',
      'storedScanPassport': 'QR 스캔 기록 → 커뮤니티 패스포트',
      'storedJourneyPassport': '여정 진행 상황 → 커뮤니티 패스포트',
    },
    'it': {
      'tutorialTitle': 'I tuoi primi 30 giorni',
      'tutorialPage': 'Pagina {current} di {total}',
      'tutorialOverview': 'Apri il pannello del percorso',
      'tutorialPages': 'Torna alle pagine della guida',
      'tutorialEyebrow': 'I TUOI PRIMI 30 GIORNI',
      'tutorialIntroTitle': 'Un mese. Un passo chiaro alla volta.',
      'tutorialIntroBody':
          'Scorri piccole pagine pratiche che presentano ogni parte di Explore Canada Bay. Completa le attività quando preferisci: progressi e informazioni utili resteranno disponibili al tuo ritorno.',
      'tutorialAppTour': 'Imparerai a usare ogni parte dell’app',
      'tutorialProgressBody':
          'Indicazioni, attività e premi completati restano disponibili nel Percorso e nel Passaporto della comunità.',
      'tutorialDay': 'GIORNO {day}',
      'tutorialInApp': 'Dove trovarlo',
      'tutorialSavedIn': 'Dove viene salvato',
      'tutorialHowComplete': 'Come si completa',
      'tutorialFinishBody':
          'Torna alla Home per i suggerimenti, rivedi la tua storia nel Passaporto e modifica lingua o account nel Profilo.',
      'tutorialBack': 'Pagina precedente',
      'tutorialStart': 'Inizia',
      'tutorialNext': 'Avanti',
      'tutorialFinish': 'Fine',
      'tutorialSwipeHint': 'Scorri tra le pagine',
      'nextDay': 'Giorno successivo',
      'callItADay': 'Per oggi basta — continua domani',
      'dailyJourneyReminders': 'Un promemoria gentile ogni giorno',
      'dailyJourneyRemindersBody':
          'Notifiche facoltative alle 9:00 per i prossimi 30 giorni.',
      'dailyReminderPrompt': 'Giorno {day}: {goal}',
      'journeyNotificationTitle': 'Il tuo passo di oggi a Canada Bay',
      'journeyNotificationChannel': 'Primi 30 giorni',
      'journeyNotificationChannelDescription':
          'Promemoria giornalieri facoltativi per il percorso dei nuovi residenti.',
      'journeyRemindersOn':
          'I promemoria per i prossimi 30 giorni sono pronti.',
      'journeyRemindersOff': 'I promemoria giornalieri sono stati disattivati.',
      'journeyRemindersUnavailable':
          'Le notifiche non sono disponibili o il permesso non è stato concesso.',
      'addGoalToCalendar': 'Aggiungi questo obiettivo al calendario',
      'calendarOpened':
          'Calendario aperto con l’obiettivo pronto da aggiungere.',
      'calendarUnavailable': 'Impossibile aprire il calendario.',
      'featureHome': 'Pagina iniziale',
      'featureExplore': 'Mappa e percorsi Esplora',
      'featureCommunity': 'Eventi e gruppi della comunità',
      'featureServices': 'Servizi locali',
      'featurePassport': 'Passaporto della comunità',
      'featureScan': 'Scansiona',
      'featureProfile': 'Profilo e lingua',
      'featureJourney': 'Percorso dei primi 30 giorni',
      'featureCommunityScan': 'Comunità, poi Scansiona',
      'storedEssentials': 'Percorso → servizi essenziali e Passaporto',
      'storedRoutePassport': 'Percorso Esplora completato → Passaporto',
      'storedScanPassport': 'Scansione QR → Passaporto',
      'storedJourneyPassport': 'Progressi del Percorso → Passaporto',
    },
    'hi': {
      'tutorialTitle': 'आपके पहले 30 दिन',
      'tutorialPage': 'पृष्ठ {current}, कुल {total}',
      'tutorialOverview': 'यात्रा डैशबोर्ड खोलें',
      'tutorialPages': 'ट्यूटोरियल पृष्ठों पर लौटें',
      'tutorialEyebrow': 'आपके पहले 30 दिन',
      'tutorialIntroTitle': 'एक महीना। एक बार में एक साफ़ कदम।',
      'tutorialIntroBody':
          'छोटे उपयोगी पृष्ठों से Explore Canada Bay के हर हिस्से को समझें और अपनी सुविधा से काम पूरे करें। लौटने पर आपकी प्रगति और सेव की गई जानकारी तैयार मिलेगी।',
      'tutorialAppTour': 'आप ऐप के हर हिस्से का उपयोग सीखेंगे',
      'tutorialProgressBody':
          'पूरी की गई जानकारी, गतिविधियाँ और पुरस्कार यात्रा व सामुदायिक पासपोर्ट में उपलब्ध रहेंगे।',
      'tutorialDay': 'दिन {day}',
      'tutorialInApp': 'यहाँ मिलेगा',
      'tutorialSavedIn': 'यहाँ सेव होगा',
      'tutorialHowComplete': 'पूरा होने का तरीका',
      'tutorialFinishBody':
          'सुझावों के लिए होम पर जाएँ, पासपोर्ट में अपनी कहानी देखें और प्रोफ़ाइल में भाषा या खाता सेटिंग बदलें।',
      'tutorialBack': 'पिछला पृष्ठ',
      'tutorialStart': 'शुरू करें',
      'tutorialNext': 'अगला',
      'tutorialFinish': 'समाप्त',
      'tutorialSwipeHint': 'पृष्ठ बदलने के लिए स्वाइप करें',
      'nextDay': 'अगला दिन',
      'callItADay': 'आज के लिए इतना ही — कल जारी रखें',
      'dailyJourneyReminders': 'हर दिन एक हल्का रिमाइंडर',
      'dailyJourneyRemindersBody':
          'वैकल्पिक: अगले 30 दिनों तक सुबह 9 बजे सूचना पाएँ।',
      'dailyReminderPrompt': 'दिन {day}: {goal}',
      'journeyNotificationTitle': 'आज का कनाडा बे कदम',
      'journeyNotificationChannel': 'पहले 30 दिन',
      'journeyNotificationChannelDescription':
          'नए निवासी की यात्रा के वैकल्पिक दैनिक रिमाइंडर।',
      'journeyRemindersOn': 'अगले 30 दिनों के दैनिक रिमाइंडर तैयार हैं।',
      'journeyRemindersOff': 'दैनिक रिमाइंडर बंद कर दिए गए हैं।',
      'journeyRemindersUnavailable':
          'सूचनाएँ उपलब्ध नहीं हैं या अनुमति नहीं मिली।',
      'addGoalToCalendar': 'यह लक्ष्य कैलेंडर में जोड़ें',
      'calendarOpened': 'लक्ष्य जोड़ने के लिए कैलेंडर खोला गया।',
      'calendarUnavailable': 'कैलेंडर नहीं खोला जा सका।',
      'featureHome': 'होम',
      'featureExplore': 'एक्सप्लोर मानचित्र और मार्ग',
      'featureCommunity': 'सामुदायिक कार्यक्रम और समूह',
      'featureServices': 'स्थानीय सेवाएँ',
      'featurePassport': 'सामुदायिक पासपोर्ट',
      'featureScan': 'स्कैन',
      'featureProfile': 'प्रोफ़ाइल और भाषा',
      'featureJourney': 'पहले 30 दिनों की यात्रा',
      'featureCommunityScan': 'समुदाय देखें, फिर स्कैन करें',
      'storedEssentials': 'यात्रा → स्थानीय ज़रूरी जानकारी और पासपोर्ट',
      'storedRoutePassport': 'एक्सप्लोर मार्ग पूरा → सामुदायिक पासपोर्ट',
      'storedScanPassport': 'QR स्कैन → सामुदायिक पासपोर्ट',
      'storedJourneyPassport': 'यात्रा की प्रगति → सामुदायिक पासपोर्ट',
    },
  };

  static const _ui = <String, Map<String, String>>{
    'en': {
      'journeyTitle': 'My Canada Bay companion',
      'journeyEyebrow': 'SETTLE IN · CONNECT · BELONG',
      'heroTitle': 'Make Canada Bay\nfeel familiar.',
      'introTitle': 'One useful step at a time',
      'introBody':
          'Start with essential Australian systems, then build confidence through local places and people. Every link comes from an official or trusted source.',
      'nextTitle': 'Recommended next step',
      'completed': 'completed',
      'openStep': 'Open step',
      'savedPassport': 'Saved in your Community Passport',
    },
    'zh': {
      'journeyTitle': '我的加拿大湾生活伙伴',
      'journeyEyebrow': '安顿 · 连接 · 融入',
      'heroTitle': '让加拿大湾\n逐渐变得熟悉。',
      'introTitle': '每次完成一个实用步骤',
      'introBody': '先了解澳大利亚的重要生活系统，再通过本地地点和社区活动建立信心。所有链接均来自政府或可信来源。',
      'nextTitle': '建议的下一步',
      'completed': '已完成',
      'openStep': '打开此步骤',
      'savedPassport': '已保存到您的社区护照',
    },
    'ko': {
      'journeyTitle': '나의 Canada Bay 생활 동반자',
      'journeyEyebrow': '정착 · 연결 · 소속',
      'heroTitle': '캐나다 베이를\n익숙한 동네로 만들어 보세요.',
      'introTitle': '한 번에 하나씩, 꼭 필요한 일부터',
      'introBody':
          '호주의 필수 생활 제도부터 시작해 지역 장소와 사람들을 알아가며 자신감을 키워 보세요. 모든 링크는 정부 또는 신뢰할 수 있는 출처로 연결됩니다.',
      'nextTitle': '추천하는 다음 단계',
      'completed': '완료',
      'openStep': '단계 열기',
      'savedPassport': '커뮤니티 패스포트에 저장됨',
    },
    'it': {
      'journeyTitle': 'La mia guida a Canada Bay',
      'journeyEyebrow': 'AMBIENTATI · CONNETTITI · SENTITI A CASA',
      'heroTitle': 'Rendi Canada Bay\nun luogo familiare.',
      'introTitle': 'Un passo utile alla volta',
      'introBody':
          'Inizia dai servizi essenziali australiani, poi acquisisci sicurezza conoscendo luoghi e persone della zona. Ogni link proviene da una fonte ufficiale o affidabile.',
      'nextTitle': 'Prossimo passo consigliato',
      'completed': 'completato',
      'openStep': 'Apri il passaggio',
      'savedPassport': 'Salvato nel Passaporto della comunità',
    },
    'hi': {
      'journeyTitle': 'मेरा Canada Bay साथी',
      'journeyEyebrow': 'बसें · जुड़ें · अपनापन पाएँ',
      'heroTitle': 'कनाडा बे को\nअपना-सा बनाएँ।',
      'introTitle': 'एक बार में एक उपयोगी कदम',
      'introBody':
          'ऑस्ट्रेलिया की ज़रूरी व्यवस्थाओं से शुरुआत करें, फिर स्थानीय जगहों और लोगों से जुड़कर आत्मविश्वास बढ़ाएँ। हर लिंक किसी आधिकारिक या विश्वसनीय स्रोत से है।',
      'nextTitle': 'अगला सुझाया गया कदम',
      'completed': 'पूरा',
      'openStep': 'चरण खोलें',
      'savedPassport': 'आपके सामुदायिक पासपोर्ट में सहेजा गया',
    },
  };

  static const _screenUi = <String, Map<String, String>>{
    'en': {
      'continueExplore': 'Continue into Explore Canada Bay',
      'guidanceReviewed':
          'Guidance reviewed {date} · Always follow current signs and official advice.',
      'binActivityTitle': 'Bin collection confirmed',
      'binActivityBody': '{day} collection saved to your Passport.',
      'binReminderSaved':
          'Bin night saved. You will be reminded the evening before.',
      'binDaySaved': 'Bin collection day saved to your Passport.',
      'binNotificationTitle': 'Bins go out tonight',
      'binNotificationBody':
          'Your collection is tomorrow. Check which bins are due and put them out this evening.',
      'binNotificationChannel': 'Bin night reminders',
      'binNotificationChannelDescription':
          'Weekly reminders for household bin collection',
      'libraryActivityTitle': 'Library membership added',
      'libraryActivityBody':
          'Your library card reference is saved in local essentials.',
      'librarySaved': 'Library card reference saved to Passport.',
      'transportActivityTitle': 'Usual transport stop saved',
      'transportActivityBody': '{stop} is saved as your {mode} starting point.',
      'transportSaved': 'Transport shortcut saved to Passport.',
      'councilSaved': 'Council report reference saved.',
      'petSaved': '{name} added to your local Passport.',
      'localEssentials': 'Local essentials',
      'linkCopied': 'Official link copied to clipboard.',
      'badgeCompleted': '{badge} badge completed.',
      'journeySavedMessage': 'Saved to your newcomer journey.',
      'saveError': 'This step could not be saved.',
      'setupTitle': 'Set up your local essentials',
      'setupBody':
          'These details become useful cards in your Passport—not another disconnected checklist.',
      'binCollection': 'Bin collection',
      'reminderOn': 'reminder on',
      'reminderOff': 'reminder off',
      'confirmCollectionDay': 'Confirm your collection day',
      'libraryMembership': 'Library membership',
      'joinSaveCard': 'Join and save a card reference',
      'personalShortcuts': 'Personal shortcuts',
      'optionalToolsSaved': '{count}/3 optional tools saved',
      'usualStop': 'My usual stop',
      'saveStop': 'Save a station, wharf or bus stop',
      'councilTracker': 'Council report tracker',
      'keepReport': 'Keep a report reference easy to find',
      'petGuide': 'Pet-friendly local guide',
      'petStatus': '{name} · explore off-leash areas',
      'addPet': 'Add a pet and find suitable places',
      'binSheetTitle': 'Confirm your bin night',
      'binSheetBody':
          'Use Council’s address lookup first, then save the collection day shown for your home.',
      'binLookup': 'Check my address on Council website',
      'collectionDay': 'Collection day',
      'weekday1': 'Monday',
      'weekday2': 'Tuesday',
      'weekday3': 'Wednesday',
      'weekday4': 'Thursday',
      'weekday5': 'Friday',
      'weekday6': 'Saturday',
      'weekday7': 'Sunday',
      'remindNightBefore': 'Remind me the night before',
      'weeklyAtSix': 'Weekly at 6:00 pm',
      'savePassport': 'Save to my Passport',
      'librarySheetTitle': 'Join your local library',
      'librarySheetBody':
          'Membership gives you borrowing, digital resources, study spaces and local programs.',
      'openLibrary': 'Open library membership',
      'cardLabel': 'Card nickname or last 4 digits',
      'cardHint': 'For example: My card · 4821',
      'libraryPrivacy':
          'For privacy, do not save your PIN or full barcode here. This reference stays on this device.',
      'transportSheetTitle': 'Save your usual stop',
      'transportSheetBody':
          'A familiar starting point makes the map and Trip Planner feel less overwhelming in a new area.',
      'openTransport': 'Explore Transport for NSW',
      'travelMode': 'How I usually travel',
      'modeTrain': 'Train',
      'modeBus': 'Bus',
      'modeFerry': 'Ferry',
      'modeLightRail': 'Light rail',
      'modeBike': 'Bike',
      'modeWalk': 'Walk',
      'stopLabel': 'Station, wharf or stop',
      'stopHint': 'For example: Concord West Station',
      'saveTransport': 'Save transport shortcut',
      'councilSheetTitle': 'Track a Council report',
      'councilSheetBody':
          'Report dumping, damaged paths or other local issues, then keep the confirmation reference where you can find it.',
      'openReport': 'Open official report form',
      'reportTypeLabel': 'What did you report?',
      'reportTypeHint': 'For example: damaged footpath',
      'reportReferenceLabel': 'Confirmation reference',
      'reportReferenceHint': 'Paste the reference from Council',
      'reportPrivacy':
          'Do not store photos, addresses or personal correspondence here—only the report label and reference.',
      'saveReport': 'Save report reference',
      'petSheetTitle': 'Explore with your pet',
      'petSheetBody':
          'Save a pet name, then use Council guidance to find declared off-leash areas and understand local restrictions.',
      'viewOffLeash': 'View off-leash areas',
      'petNameLabel': 'Pet name',
      'petNameHint': 'For example: Milo',
      'addPetPassport': 'Add pet to Passport',
      'waterEyebrow': 'WATER SAFETY, AT A GLANCE',
      'waterTitle': 'Flags guide you.\nSupervision protects children.',
      'waterBody':
          'At a patrolled beach, swim between the red and yellow flags. Around pools, actively supervise young children and keep gates closed.',
      'flagSwimBetween': 'Swim between these flags',
      'flagRed': 'Red: no swimming',
      'flagYellow': 'Yellow: caution required',
      'contextHeading': 'Why this matters in Australia',
      'understandGuidance': 'I understand this guidance',
      'journeyUnavailable': 'Your newcomer journey is unavailable',
      'tryAgain': 'Try again',
      'companionCheckInEyebrow': 'START WHERE YOU ARE',
      'companionCheckInTitle': 'What would make today easier?',
      'companionCheckInBody':
          'Choose what you need and the app will surface one practical next step. You can open the full plan at any time.',
      'needSettle': 'Settle at home',
      'needFindWay': 'Find my way',
      'needMeetPeople': 'Meet people',
      'needCareTogether': 'Care for my community',
      'needSettleReason':
          'Start with services that make everyday life safer and easier.',
      'needFindWayReason':
          'Build confidence getting around your new neighbourhood.',
      'needMeetPeopleReason':
          'Find welcoming, low-pressure ways to make local connections.',
      'needCareTogetherReason':
          'Learn local safety and contribute to places shared by everyone.',
      'rightNow': 'Right now',
      'revisitStep': 'Revisit step',
      'chooseAnother': 'Choose another',
      'essentialsSaved': '{count} local essentials saved',
      'connectionPulseTitle': 'Your connection pulse',
      'connectionPulseBody':
          '{completed}/{total} journey steps · {setup} essentials · {moments} community moments',
      'latestMoment': 'Latest: {name}',
      'viewWholeJourney': 'View the whole journey',
      'journeyCompleteTitle': 'Canada Bay is becoming yours',
      'journeyCompleteBody':
          'You have completed the starter journey. Keep exploring, meeting people and adding local moments to your Passport.',
      'belongingPathEyebrow': 'YOUR PATH TO BELONGING',
      'belongingPathTitle': 'Four parts of feeling at home',
      'belongingPathBody':
          'The steps connect essential services, confidence, people and care for your neighbourhood.',
      'chapterSettleTitle': 'Feel secure',
      'chapterSettleBody': 'Understand the systems that support daily life.',
      'chapterRhythmTitle': 'Find your rhythm',
      'chapterRhythmBody': 'Move around confidently and learn the area.',
      'chapterPeopleTitle': 'Meet your people',
      'chapterPeopleBody': 'Use welcoming places and activities to connect.',
      'chapterCareTitle': 'Care together',
      'chapterCareBody': 'Stay safe and help care for shared local places.',
      'chapterProgress': '{completed}/{total} complete',
      'wholeJourneyTitle': 'Your whole settlement journey',
      'wholeJourneyBody':
          'Browse every experience or revisit something already familiar.',
      'connectionPulse': 'Your connection pulse',
      'pulseStart': 'Your first local connection starts with one useful step.',
      'pulseGrowing':
          'You are turning unfamiliar systems into familiar routines.',
      'pulseBelonging':
          'You are building a local rhythm and stronger connections.',
      'pulseComplete':
          'The starter journey is complete—your local story keeps growing.',
      'familiarMoments': 'parts familiar',
      'localTools': 'local tools',
      'passportStories': 'Passport stories',
      'recentMoment': 'Recent local moment',
      'seeWholeJourney': 'See the whole journey',
      'completeCompanionTitle': 'You have built a strong local foundation',
      'completeCompanionBody':
          'Keep exploring, meeting people and adding meaningful local moments to your Passport.',
      'belongingEyebrow': 'FROM ARRIVAL TO BELONGING',
      'belongingTitle': 'A path that connects the pieces',
      'belongingBody':
          'Move through essential systems, local confidence, people and care at your own pace.',
      'rooted': 'Rooted',
      'growing': 'Growing',
      'readyWhenYouAre': 'Ready when you are',
      'toolkitEyebrow': 'YOUR LOCAL TOOLKIT',
      'toolkitTitle': 'Useful details, ready when needed',
      'toolkitBody':
          'Keep the small pieces of local life together so they are easy to find.',
      'anchorsReady': 'ready',
      'companionHeroLabel': 'Your settlement companion',
      'heroCompanionStart': 'Start making Canada Bay feel familiar',
      'heroCompanionGrowing': 'Your new neighbourhood is taking shape',
      'heroCompanionBelonging': 'You are building a life that feels connected',
      'heroCompanionComplete': 'Canada Bay is becoming your community',
      'heroCompanionStartBody':
          'One practical step can make a new place feel much easier.',
      'heroCompanionGrowingBody':
          'Every saved detail and local experience builds confidence.',
      'heroCompanionCompleteBody':
          'The starter plan is complete, but your local story keeps growing.',
      'heroFamiliarCount': '{count} local moments familiar',
      'wholeJourneyProgress':
          '{completed} of {total} steps familiar · Browse every step',
      'scanWhenThere': 'Scan when you are there',
    },
    'zh': {
      'continueExplore': '继续探索加拿大湾',
      'guidanceReviewed': '指南审核日期：{date} · 请始终遵循最新标识和官方建议。',
      'binActivityTitle': '已确认垃圾桶收集日',
      'binActivityBody': '已将{day}收集信息保存到您的社区护照。',
      'binReminderSaved': '已保存垃圾桶收集前一晚提醒。届时您会收到通知。',
      'binDaySaved': '垃圾桶收集日已保存到您的社区护照。',
      'binNotificationTitle': '今晚请把垃圾桶推出去',
      'binNotificationBody': '明天收集垃圾。请确认需要收集哪些垃圾桶，并于今晚将它们推出去。',
      'binNotificationChannel': '垃圾桶收集前一晚提醒',
      'binNotificationChannelDescription': '每周家庭垃圾桶收集提醒',
      'libraryActivityTitle': '已添加图书馆会员信息',
      'libraryActivityBody': '借书卡提示已保存到本地生活必备信息。',
      'librarySaved': '借书卡提示已保存到社区护照。',
      'transportActivityTitle': '已保存常用交通站点',
      'transportActivityBody': '已将{stop}保存为您的{mode}出发点。',
      'transportSaved': '交通快捷信息已保存到社区护照。',
      'councilSaved': '市政问题报告编号已保存。',
      'petSaved': '已将{name}添加到您的本地社区护照。',
      'localEssentials': '本地生活必备信息',
      'linkCopied': '官方链接已复制到剪贴板。',
      'badgeCompleted': '已完成{badge}徽章。',
      'journeySavedMessage': '已保存到您的新居民指南。',
      'saveError': '无法保存此步骤。',
      'setupTitle': '设置本地生活必备信息',
      'setupBody': '这些信息会成为社区护照中的实用卡片，而不是另一份互不关联的清单。',
      'binCollection': '垃圾桶收集',
      'reminderOn': '提醒已开启',
      'reminderOff': '提醒已关闭',
      'confirmCollectionDay': '确认您的垃圾收集日',
      'libraryMembership': '图书馆会员',
      'joinSaveCard': '加入图书馆并保存借书卡提示',
      'personalShortcuts': '个人快捷信息',
      'optionalToolsSaved': '已保存{count}/3项可选工具',
      'usualStop': '我的常用车站',
      'saveStop': '保存火车站、码头或公交站',
      'councilTracker': '市政问题报告追踪',
      'keepReport': '保存报告编号，方便日后查找',
      'petGuide': '宠物友好本地指南',
      'petStatus': '{name} · 探索可不拴绳区域',
      'addPet': '添加宠物并寻找合适地点',
      'binSheetTitle': '确认垃圾桶收集前一晚',
      'binSheetBody': '请先使用市政府的地址查询，然后保存您住址所显示的收集日。',
      'binLookup': '在市政府网站查询我的住址',
      'collectionDay': '收集日',
      'weekday1': '星期一',
      'weekday2': '星期二',
      'weekday3': '星期三',
      'weekday4': '星期四',
      'weekday5': '星期五',
      'weekday6': '星期六',
      'weekday7': '星期日',
      'remindNightBefore': '前一晚提醒我',
      'weeklyAtSix': '每周晚上6点',
      'savePassport': '保存到我的社区护照',
      'librarySheetTitle': '加入本地图书馆',
      'librarySheetBody': '会员可以借阅资料、使用电子资源和自习空间，并参加本地活动。',
      'openLibrary': '打开图书馆会员页面',
      'cardLabel': '借书卡昵称或最后4位数字',
      'cardHint': '例如：我的借书卡 · 4821',
      'libraryPrivacy': '为保护隐私，请勿在此保存密码或完整条形码。此提示只保存在本设备上。',
      'transportSheetTitle': '保存您的常用车站',
      'transportSheetBody': '熟悉的出发点能让您在新地区使用地图和行程规划器时更轻松。',
      'openTransport': '打开新州交通服务',
      'travelMode': '我通常的出行方式',
      'modeTrain': '火车',
      'modeBus': '公交车',
      'modeFerry': '渡轮',
      'modeLightRail': '轻轨',
      'modeBike': '自行车',
      'modeWalk': '步行',
      'stopLabel': '火车站、码头或公交站',
      'stopHint': '例如：Concord West Station',
      'saveTransport': '保存交通快捷信息',
      'councilSheetTitle': '追踪市政问题报告',
      'councilSheetBody': '报告非法倾倒、道路损坏或其他本地问题，并保存确认编号以便日后查询。',
      'openReport': '打开官方报告表格',
      'reportTypeLabel': '您报告了什么问题？',
      'reportTypeHint': '例如：人行道损坏',
      'reportReferenceLabel': '确认编号',
      'reportReferenceHint': '粘贴市政府提供的编号',
      'reportPrivacy': '请勿在此保存照片、地址或私人通信，只保存问题标签和确认编号。',
      'saveReport': '保存报告编号',
      'petSheetTitle': '与宠物一起探索',
      'petSheetBody': '保存宠物名字，然后根据市政府指南查找指定的可不拴绳区域并了解本地限制。',
      'viewOffLeash': '查看可不拴绳区域',
      'petNameLabel': '宠物名字',
      'petNameHint': '例如：Milo',
      'addPetPassport': '将宠物添加到社区护照',
      'waterEyebrow': '水上安全速览',
      'waterTitle': '旗帜指引方向。\n看护保障儿童安全。',
      'waterBody': '在有救生员巡逻的海滩，请在红黄旗之间游泳。在泳池旁应始终主动看护幼童，并保持安全门关闭。',
      'flagSwimBetween': '请在这些旗帜之间游泳',
      'flagRed': '红旗：禁止游泳',
      'flagYellow': '黄旗：需要谨慎',
      'contextHeading': '为什么这在澳大利亚很重要',
      'understandGuidance': '我已了解此指南',
      'journeyUnavailable': '暂时无法加载新居民指南',
      'tryAgain': '重试',
      'companionCheckInEyebrow': '从您现在的需要开始',
      'companionCheckInTitle': '今天做什么会让生活更轻松？',
      'companionCheckInBody': '选择您当前的需要，应用会推荐一个实用的下一步。您可以随时查看完整计划。',
      'needSettle': '安顿居家生活',
      'needFindWay': '熟悉出行',
      'needMeetPeople': '认识新朋友',
      'needCareTogether': '共同关爱社区',
      'needSettleReason': '先了解能让日常生活更安全、更轻松的服务。',
      'needFindWayReason': '增强在新社区出行的信心。',
      'needMeetPeopleReason': '寻找轻松、友好的方式建立本地联系。',
      'needCareTogetherReason': '了解本地安全知识，并为大家共享的地方作出贡献。',
      'rightNow': '现在开始',
      'revisitStep': '再次查看',
      'chooseAnother': '选择其他步骤',
      'essentialsSaved': '已保存{count}项本地生活信息',
      'connectionPulseTitle': '您的社区融入进度',
      'connectionPulseBody':
          '已完成{completed}/{total}个步骤 · {setup}项生活信息 · {moments}个社区足迹',
      'latestMoment': '最近足迹：{name}',
      'viewWholeJourney': '查看完整指南',
      'journeyCompleteTitle': '加拿大湾正逐渐成为您的家',
      'journeyCompleteBody': '您已完成入门指南。继续探索、认识邻里，并把本地经历加入社区护照。',
      'belongingPathEyebrow': '您的社区融入路径',
      'belongingPathTitle': '建立归属感的四个方面',
      'belongingPathBody': '这些步骤把生活服务、出行信心、社区联系和共同关爱连在一起。',
      'chapterSettleTitle': '安心安顿',
      'chapterSettleBody': '了解支持日常生活的重要制度和服务。',
      'chapterRhythmTitle': '找到生活节奏',
      'chapterRhythmBody': '自信出行并逐渐熟悉周边地区。',
      'chapterPeopleTitle': '认识身边的人',
      'chapterPeopleBody': '通过友好的场所和活动建立联系。',
      'chapterCareTitle': '共同关爱',
      'chapterCareBody': '注意安全并帮助保护共享的本地空间。',
      'chapterProgress': '已完成{completed}/{total}',
      'wholeJourneyTitle': '您的完整安居融入旅程',
      'wholeJourneyBody': '浏览所有体验，或再次查看已经熟悉的内容。',
      'connectionPulse': '您的社区融入状态',
      'pulseStart': '从一个实用步骤开始，建立您的第一个本地联系。',
      'pulseGrowing': '您正把陌生的生活制度变成熟悉的日常习惯。',
      'pulseBelonging': '您正在建立本地生活节奏和更紧密的社区联系。',
      'pulseComplete': '入门指南已经完成，您的本地故事仍在继续。',
      'familiarMoments': '已熟悉部分',
      'localTools': '本地工具',
      'passportStories': '护照足迹',
      'recentMoment': '最近的本地足迹',
      'seeWholeJourney': '查看完整指南',
      'completeCompanionTitle': '您已经建立了稳固的本地生活基础',
      'completeCompanionBody': '继续探索、认识邻里，并把有意义的本地经历加入社区护照。',
      'belongingEyebrow': '从初来乍到到融入社区',
      'belongingTitle': '把生活各方面连在一起的路径',
      'belongingBody': '按照自己的节奏了解重要制度、建立本地信心、认识他人并共同关爱社区。',
      'rooted': '已经融入',
      'growing': '正在成长',
      'readyWhenYouAre': '准备好时开始',
      'toolkitEyebrow': '您的本地工具箱',
      'toolkitTitle': '实用信息，需要时随时可用',
      'toolkitBody': '把本地生活中的小信息集中保存，方便随时查找。',
      'anchorsReady': '项已就绪',
      'companionHeroLabel': '您的安居融入伙伴',
      'heroCompanionStart': '从熟悉加拿大湾开始',
      'heroCompanionGrowing': '您的新社区正逐渐清晰',
      'heroCompanionBelonging': '您正在建立有联系、有归属的生活',
      'heroCompanionComplete': '加拿大湾正成为您的社区',
      'heroCompanionStartBody': '一个实用步骤，就能让新环境轻松许多。',
      'heroCompanionGrowingBody': '每项保存的信息和本地经历都会增强您的信心。',
      'heroCompanionCompleteBody': '入门计划已完成，但您的本地故事仍在继续。',
      'heroFamiliarCount': '熟悉了{count}个本地生活片段',
      'wholeJourneyProgress': '已熟悉{completed}/{total}个步骤 · 浏览所有步骤',
      'scanWhenThere': '到达后扫描',
    },
    'ko': {
      'continueExplore': 'Explore Canada Bay 계속 둘러보기',
      'guidanceReviewed': '안내 검토일: {date} · 항상 최신 표지판과 공식 안내를 따르세요.',
      'binActivityTitle': '쓰레기 수거일 확인 완료',
      'binActivityBody': '{day} 수거 정보를 커뮤니티 패스포트에 저장했습니다.',
      'binReminderSaved': '쓰레기 수거 전날 알림을 저장했습니다. 전날 저녁에 알려 드립니다.',
      'binDaySaved': '쓰레기 수거일을 커뮤니티 패스포트에 저장했습니다.',
      'binNotificationTitle': '오늘 밤 쓰레기통을 내놓으세요',
      'binNotificationBody': '내일 수거합니다. 수거 대상 쓰레기통을 확인해 오늘 저녁에 내놓으세요.',
      'binNotificationChannel': '쓰레기통 수거 전날 알림',
      'binNotificationChannelDescription': '가정 쓰레기통 수거를 위한 주간 알림',
      'libraryActivityTitle': '도서관 회원 정보 추가 완료',
      'libraryActivityBody': '도서관 카드 참조 정보를 지역 필수 정보에 저장했습니다.',
      'librarySaved': '도서관 카드 참조 정보를 패스포트에 저장했습니다.',
      'transportActivityTitle': '자주 이용하는 교통 정류장 저장 완료',
      'transportActivityBody': '{stop}을(를) {mode} 출발지로 저장했습니다.',
      'transportSaved': '교통 바로가기를 패스포트에 저장했습니다.',
      'councilSaved': 'Council 신고 참조 번호를 저장했습니다.',
      'petSaved': '{name}을(를) 지역 패스포트에 추가했습니다.',
      'localEssentials': '지역 생활 필수 정보',
      'linkCopied': '공식 링크를 클립보드에 복사했습니다.',
      'badgeCompleted': '{badge} 배지를 완료했습니다.',
      'journeySavedMessage': '새 주민 여정에 저장했습니다.',
      'saveError': '이 단계를 저장하지 못했습니다.',
      'setupTitle': '지역 생활 필수 정보 설정',
      'setupBody': '이 정보는 서로 동떨어진 체크리스트가 아니라 패스포트의 유용한 카드로 저장됩니다.',
      'binCollection': '쓰레기 수거',
      'reminderOn': '알림 켜짐',
      'reminderOff': '알림 꺼짐',
      'confirmCollectionDay': '수거일 확인하기',
      'libraryMembership': '도서관 회원 정보',
      'joinSaveCard': '가입하고 카드 참조 정보 저장하기',
      'personalShortcuts': '개인 바로가기',
      'optionalToolsSaved': '선택 도구 {count}/3개 저장됨',
      'usualStop': '자주 이용하는 정류장',
      'saveStop': '역, 선착장 또는 버스 정류장 저장하기',
      'councilTracker': 'Council 신고 추적',
      'keepReport': '신고 참조 번호를 쉽게 찾도록 저장하기',
      'petGuide': '반려동물과 함께하는 지역 안내',
      'petStatus': '{name} · 목줄 없이 이용 가능한 구역 찾기',
      'addPet': '반려동물을 추가하고 알맞은 장소 찾기',
      'binSheetTitle': '쓰레기 수거 전날 확인',
      'binSheetBody': '먼저 Council 주소 검색을 이용한 뒤, 집 주소에 표시된 수거일을 저장하세요.',
      'binLookup': 'Council 웹사이트에서 내 주소 확인',
      'collectionDay': '수거일',
      'weekday1': '월요일',
      'weekday2': '화요일',
      'weekday3': '수요일',
      'weekday4': '목요일',
      'weekday5': '금요일',
      'weekday6': '토요일',
      'weekday7': '일요일',
      'remindNightBefore': '전날 저녁에 알림 받기',
      'weeklyAtSix': '매주 오후 6시',
      'savePassport': '내 패스포트에 저장',
      'librarySheetTitle': '지역 도서관 가입하기',
      'librarySheetBody': '회원은 자료 대출, 디지털 자료, 학습 공간과 지역 프로그램을 이용할 수 있습니다.',
      'openLibrary': '도서관 회원 가입 페이지 열기',
      'cardLabel': '카드 별칭 또는 마지막 네 자리',
      'cardHint': '예: 내 카드 · 4821',
      'libraryPrivacy':
          '개인정보 보호를 위해 PIN이나 전체 바코드를 저장하지 마세요. 이 참조 정보는 이 기기에만 보관됩니다.',
      'transportSheetTitle': '자주 이용하는 정류장 저장',
      'transportSheetBody':
          '익숙한 출발지를 정해 두면 새로운 지역에서 지도와 Trip Planner를 더 편하게 이용할 수 있습니다.',
      'openTransport': 'Transport for NSW 둘러보기',
      'travelMode': '주로 이용하는 교통수단',
      'modeTrain': '기차',
      'modeBus': '버스',
      'modeFerry': '페리',
      'modeLightRail': '경전철',
      'modeBike': '자전거',
      'modeWalk': '도보',
      'stopLabel': '역, 선착장 또는 정류장',
      'stopHint': '예: Concord West Station',
      'saveTransport': '교통 바로가기 저장',
      'councilSheetTitle': 'Council 신고 추적',
      'councilSheetBody': '불법 투기, 파손된 보도 또는 다른 지역 문제를 신고한 뒤 확인 참조 번호를 저장하세요.',
      'openReport': '공식 신고 양식 열기',
      'reportTypeLabel': '무엇을 신고했나요?',
      'reportTypeHint': '예: 파손된 보도',
      'reportReferenceLabel': '확인 참조 번호',
      'reportReferenceHint': 'Council에서 받은 번호 붙여넣기',
      'reportPrivacy': '사진, 주소 또는 개인 서신은 저장하지 말고 신고명과 참조 번호만 저장하세요.',
      'saveReport': '신고 참조 번호 저장',
      'petSheetTitle': '반려동물과 함께 둘러보기',
      'petSheetBody': '반려동물 이름을 저장한 뒤 Council 안내에서 지정된 목줄 해제 구역과 지역 제한을 확인하세요.',
      'viewOffLeash': '목줄 해제 구역 보기',
      'petNameLabel': '반려동물 이름',
      'petNameHint': '예: Milo',
      'addPetPassport': '패스포트에 반려동물 추가',
      'waterEyebrow': '한눈에 보는 수상 안전',
      'waterTitle': '깃발은 길을 안내하고,\n보호자의 감독은 어린이를 지킵니다.',
      'waterBody':
          '안전요원이 순찰하는 해변에서는 빨간색과 노란색 깃발 사이에서 수영하세요. 수영장 주변에서는 어린이를 적극적으로 지켜보고 출입문을 닫아 두세요.',
      'flagSwimBetween': '이 깃발 사이에서 수영하세요',
      'flagRed': '빨간색: 수영 금지',
      'flagYellow': '노란색: 주의 필요',
      'contextHeading': '호주에서 이것이 중요한 이유',
      'understandGuidance': '이 안내를 이해했습니다',
      'journeyUnavailable': '새 주민 여정을 불러올 수 없습니다',
      'tryAgain': '다시 시도',
      'companionCheckInEyebrow': '지금 필요한 것부터',
      'companionCheckInTitle': '오늘 무엇이 조금 더 쉬워지면 좋을까요?',
      'companionCheckInBody':
          '지금 필요한 항목을 고르면 실용적인 다음 단계 하나를 추천합니다. 전체 계획은 언제든 볼 수 있습니다.',
      'needSettle': '집과 생활 정착',
      'needFindWay': '길과 교통 익히기',
      'needMeetPeople': '사람들 만나기',
      'needCareTogether': '지역사회 돌보기',
      'needSettleReason': '일상을 더 안전하고 편리하게 만드는 서비스부터 시작하세요.',
      'needFindWayReason': '새로운 동네를 자신 있게 이동하는 방법을 익혀 보세요.',
      'needMeetPeopleReason': '부담 없이 환영받으며 지역 사람들과 연결되는 방법을 찾아보세요.',
      'needCareTogetherReason': '지역 안전을 배우고 모두가 함께 쓰는 장소를 돌보세요.',
      'rightNow': '지금 할 일',
      'revisitStep': '다시 보기',
      'chooseAnother': '다른 단계 선택',
      'essentialsSaved': '지역 필수 정보 {count}개 저장됨',
      'connectionPulseTitle': '지역 연결 현황',
      'connectionPulseBody':
          '여정 {completed}/{total}단계 · 필수 정보 {setup}개 · 지역 활동 {moments}개',
      'latestMoment': '최근 활동: {name}',
      'viewWholeJourney': '전체 여정 보기',
      'journeyCompleteTitle': 'Canada Bay가 내 동네가 되어 가고 있어요',
      'journeyCompleteBody':
          '첫 여정을 모두 마쳤습니다. 계속 둘러보고 사람들을 만나며 지역 활동을 패스포트에 더해 보세요.',
      'belongingPathEyebrow': '소속감을 만드는 여정',
      'belongingPathTitle': '동네가 편안해지는 네 가지 과정',
      'belongingPathBody': '필수 서비스, 이동 자신감, 사람들과의 연결, 동네 돌봄이 하나의 여정으로 이어집니다.',
      'chapterSettleTitle': '안심하고 정착하기',
      'chapterSettleBody': '일상을 지원하는 제도와 서비스를 이해하세요.',
      'chapterRhythmTitle': '나만의 생활 리듬 찾기',
      'chapterRhythmBody': '자신 있게 이동하며 주변 지역을 익혀 보세요.',
      'chapterPeopleTitle': '우리 동네 사람들 만나기',
      'chapterPeopleBody': '환영받는 장소와 활동을 통해 연결되세요.',
      'chapterCareTitle': '함께 돌보기',
      'chapterCareBody': '안전을 익히고 모두의 지역 공간을 함께 돌보세요.',
      'chapterProgress': '{completed}/{total} 완료',
      'wholeJourneyTitle': '나의 전체 정착 여정',
      'wholeJourneyBody': '모든 경험을 둘러보거나 이미 익숙해진 내용을 다시 확인하세요.',
      'connectionPulse': '지역 연결 현황',
      'pulseStart': '유용한 한 단계로 첫 지역 연결을 시작해 보세요.',
      'pulseGrowing': '낯선 생활 제도가 익숙한 일상으로 바뀌고 있습니다.',
      'pulseBelonging': '지역 생활의 리듬과 더 깊은 연결을 만들어 가고 있습니다.',
      'pulseComplete': '첫 여정은 끝났지만 나의 지역 이야기는 계속 자랍니다.',
      'familiarMoments': '익숙해진 부분',
      'localTools': '지역 도구',
      'passportStories': '패스포트 이야기',
      'recentMoment': '최근 지역 활동',
      'seeWholeJourney': '전체 여정 보기',
      'completeCompanionTitle': '든든한 지역 생활의 기반을 만들었습니다',
      'completeCompanionBody': '계속 둘러보고 사람들을 만나며 의미 있는 지역 활동을 패스포트에 더해 보세요.',
      'belongingEyebrow': '도착에서 소속감까지',
      'belongingTitle': '생활의 조각을 연결하는 여정',
      'belongingBody': '필수 제도, 지역 자신감, 사람들과의 연결, 동네 돌봄을 내 속도에 맞춰 이어 가세요.',
      'rooted': '자리 잡음',
      'growing': '성장 중',
      'readyWhenYouAre': '준비되면 시작',
      'toolkitEyebrow': '나의 지역 생활 도구',
      'toolkitTitle': '필요할 때 바로 찾는 유용한 정보',
      'toolkitBody': '지역 생활의 작은 정보들을 한곳에 모아 쉽게 찾아보세요.',
      'anchorsReady': '개 준비됨',
      'companionHeroLabel': '나의 정착 동반자',
      'heroCompanionStart': 'Canada Bay를 익숙한 동네로 만들어 보세요',
      'heroCompanionGrowing': '새로운 동네가 점점 익숙해지고 있어요',
      'heroCompanionBelonging': '연결된 지역 생활을 만들어 가고 있어요',
      'heroCompanionComplete': 'Canada Bay가 나의 지역사회가 되고 있어요',
      'heroCompanionStartBody': '실용적인 한 단계가 새로운 곳에서의 생활을 훨씬 편하게 만듭니다.',
      'heroCompanionGrowingBody': '저장한 정보와 지역 경험 하나하나가 자신감을 키워 줍니다.',
      'heroCompanionCompleteBody': '첫 계획은 끝났지만 나의 지역 이야기는 계속 이어집니다.',
      'heroFamiliarCount': '익숙해진 지역 순간 {count}개',
      'wholeJourneyProgress': '{completed}/{total}단계 익숙해짐 · 모든 단계 보기',
      'scanWhenThere': '현장에서 스캔',
    },
    'it': {
      'continueExplore': 'Continua a esplorare Canada Bay',
      'guidanceReviewed':
          'Guida verificata il {date} · Segui sempre la segnaletica aggiornata e le indicazioni ufficiali.',
      'binActivityTitle': 'Giorno di raccolta confermato',
      'binActivityBody':
          'La raccolta di {day} è stata salvata nel tuo Passaporto.',
      'binReminderSaved':
          'Promemoria salvato. Riceverai una notifica la sera precedente.',
      'binDaySaved': 'Giorno di raccolta salvato nel tuo Passaporto.',
      'binNotificationTitle': 'Metti fuori i bidoni stasera',
      'binNotificationBody':
          'La raccolta è domani. Controlla quali bidoni verranno svuotati e mettili fuori questa sera.',
      'binNotificationChannel': 'Promemoria per la sera dei bidoni',
      'binNotificationChannelDescription':
          'Promemoria settimanali per la raccolta dei rifiuti domestici',
      'libraryActivityTitle': 'Iscrizione alla biblioteca aggiunta',
      'libraryActivityBody':
          'Il riferimento della tessera è salvato tra i servizi essenziali.',
      'librarySaved': 'Riferimento della tessera salvato nel Passaporto.',
      'transportActivityTitle': 'Fermata abituale salvata',
      'transportActivityBody':
          '{stop} è stata salvata come punto di partenza per {mode}.',
      'transportSaved': 'Collegamento ai trasporti salvato nel Passaporto.',
      'councilSaved': 'Riferimento della segnalazione al Council salvato.',
      'petSaved': '{name} è stato aggiunto al tuo Passaporto locale.',
      'localEssentials': 'Servizi essenziali locali',
      'linkCopied': 'Link ufficiale copiato negli appunti.',
      'badgeCompleted': 'Badge {badge} completato.',
      'journeySavedMessage': 'Salvato nel tuo percorso per nuovi residenti.',
      'saveError': 'Non è stato possibile salvare questo passaggio.',
      'setupTitle': 'Configura i servizi essenziali locali',
      'setupBody':
          'Questi dati diventano schede utili nel Passaporto, non un’altra lista scollegata.',
      'binCollection': 'Raccolta dei rifiuti',
      'reminderOn': 'promemoria attivo',
      'reminderOff': 'promemoria disattivato',
      'confirmCollectionDay': 'Conferma il giorno di raccolta',
      'libraryMembership': 'Iscrizione alla biblioteca',
      'joinSaveCard': 'Iscriviti e salva un riferimento alla tessera',
      'personalShortcuts': 'Collegamenti personali',
      'optionalToolsSaved': '{count}/3 strumenti facoltativi salvati',
      'usualStop': 'La mia fermata abituale',
      'saveStop': 'Salva una stazione, un molo o una fermata',
      'councilTracker': 'Segnalazioni al Council',
      'keepReport': 'Tieni a portata di mano il riferimento',
      'petGuide': 'Guida locale per animali domestici',
      'petStatus': '{name} · scopri le aree senza guinzaglio',
      'addPet': 'Aggiungi un animale e trova luoghi adatti',
      'binSheetTitle': 'Conferma la sera dei bidoni',
      'binSheetBody':
          'Prima cerca il tuo indirizzo sul sito del Council, poi salva il giorno indicato per la tua abitazione.',
      'binLookup': 'Cerca il mio indirizzo sul sito del Council',
      'collectionDay': 'Giorno di raccolta',
      'weekday1': 'Lunedì',
      'weekday2': 'Martedì',
      'weekday3': 'Mercoledì',
      'weekday4': 'Giovedì',
      'weekday5': 'Venerdì',
      'weekday6': 'Sabato',
      'weekday7': 'Domenica',
      'remindNightBefore': 'Ricordamelo la sera prima',
      'weeklyAtSix': 'Ogni settimana alle 18:00',
      'savePassport': 'Salva nel mio Passaporto',
      'librarySheetTitle': 'Iscriviti alla biblioteca locale',
      'librarySheetBody':
          'L’iscrizione offre prestiti, risorse digitali, spazi di studio e programmi locali.',
      'openLibrary': 'Apri la pagina di iscrizione',
      'cardLabel': 'Nome della tessera o ultime 4 cifre',
      'cardHint': 'Ad esempio: La mia tessera · 4821',
      'libraryPrivacy':
          'Per la tua privacy, non salvare qui il PIN o il codice a barre completo. Questo riferimento resta sul dispositivo.',
      'transportSheetTitle': 'Salva la fermata abituale',
      'transportSheetBody':
          'Un punto di partenza familiare rende la mappa e il Trip Planner più semplici in una zona nuova.',
      'openTransport': 'Esplora Transport for NSW',
      'travelMode': 'Come viaggio di solito',
      'modeTrain': 'Treno',
      'modeBus': 'Autobus',
      'modeFerry': 'Traghetto',
      'modeLightRail': 'Metrotranvia',
      'modeBike': 'Bicicletta',
      'modeWalk': 'A piedi',
      'stopLabel': 'Stazione, molo o fermata',
      'stopHint': 'Ad esempio: Concord West Station',
      'saveTransport': 'Salva il collegamento ai trasporti',
      'councilSheetTitle': 'Segui una segnalazione al Council',
      'councilSheetBody':
          'Segnala rifiuti abbandonati, sentieri danneggiati o altri problemi locali e conserva il riferimento di conferma.',
      'openReport': 'Apri il modulo ufficiale',
      'reportTypeLabel': 'Che cosa hai segnalato?',
      'reportTypeHint': 'Ad esempio: marciapiede danneggiato',
      'reportReferenceLabel': 'Riferimento di conferma',
      'reportReferenceHint': 'Incolla il riferimento ricevuto dal Council',
      'reportPrivacy':
          'Non salvare foto, indirizzi o corrispondenza personale: conserva solo l’etichetta e il riferimento della segnalazione.',
      'saveReport': 'Salva il riferimento',
      'petSheetTitle': 'Esplora con il tuo animale',
      'petSheetBody':
          'Salva il nome dell’animale, poi usa la guida del Council per trovare le aree senza guinzaglio e conoscere le restrizioni locali.',
      'viewOffLeash': 'Vedi le aree senza guinzaglio',
      'petNameLabel': 'Nome dell’animale',
      'petNameHint': 'Ad esempio: Milo',
      'addPetPassport': 'Aggiungi l’animale al Passaporto',
      'waterEyebrow': 'SICUREZZA IN ACQUA IN BREVE',
      'waterTitle':
          'Le bandiere ti guidano.\nLa sorveglianza protegge i bambini.',
      'waterBody':
          'In una spiaggia sorvegliata, nuota tra le bandiere rosse e gialle. Vicino alle piscine, sorveglia attivamente i bambini e tieni chiusi i cancelli.',
      'flagSwimBetween': 'Nuota tra queste bandiere',
      'flagRed': 'Rosso: vietato nuotare',
      'flagYellow': 'Giallo: occorre prudenza',
      'contextHeading': 'Perché è importante in Australia',
      'understandGuidance': 'Ho compreso queste indicazioni',
      'journeyUnavailable': 'Il percorso per nuovi residenti non è disponibile',
      'tryAgain': 'Riprova',
      'companionCheckInEyebrow': 'PARTI DA CIÒ CHE TI SERVE',
      'companionCheckInTitle': 'Che cosa renderebbe più semplice la giornata?',
      'companionCheckInBody':
          'Scegli ciò di cui hai bisogno e l’app ti proporrà un prossimo passo concreto. Puoi aprire il piano completo in qualsiasi momento.',
      'needSettle': 'Ambientarmi a casa',
      'needFindWay': 'Orientarmi',
      'needMeetPeople': 'Conoscere persone',
      'needCareTogether': 'Prendermi cura della comunità',
      'needSettleReason':
          'Inizia dai servizi che rendono la vita quotidiana più sicura e semplice.',
      'needFindWayReason':
          'Acquista sicurezza negli spostamenti nel tuo nuovo quartiere.',
      'needMeetPeopleReason':
          'Trova modi accoglienti e informali per creare legami nella zona.',
      'needCareTogetherReason':
          'Impara le regole di sicurezza e contribuisci ai luoghi condivisi.',
      'rightNow': 'Da fare ora',
      'revisitStep': 'Rivedi il passaggio',
      'chooseAnother': 'Scegline un altro',
      'essentialsSaved': '{count} informazioni essenziali salvate',
      'connectionPulseTitle': 'Il tuo livello di connessione',
      'connectionPulseBody':
          '{completed}/{total} passaggi · {setup} informazioni essenziali · {moments} momenti nella comunità',
      'latestMoment': 'Più recente: {name}',
      'viewWholeJourney': 'Vedi l’intero percorso',
      'journeyCompleteTitle': 'Canada Bay sta diventando casa tua',
      'journeyCompleteBody':
          'Hai completato il percorso iniziale. Continua a esplorare, incontrare persone e aggiungere esperienze locali al Passaporto.',
      'belongingPathEyebrow': 'IL TUO PERCORSO VERSO L’APPARTENENZA',
      'belongingPathTitle': 'Quattro aspetti per sentirsi a casa',
      'belongingPathBody':
          'I passaggi uniscono servizi essenziali, autonomia, persone e cura del quartiere.',
      'chapterSettleTitle': 'Sentiti al sicuro',
      'chapterSettleBody':
          'Comprendi i sistemi che sostengono la vita quotidiana.',
      'chapterRhythmTitle': 'Trova il tuo ritmo',
      'chapterRhythmBody':
          'Muoviti con sicurezza e impara a conoscere la zona.',
      'chapterPeopleTitle': 'Incontra la tua comunità',
      'chapterPeopleBody':
          'Crea legami attraverso luoghi e attività accoglienti.',
      'chapterCareTitle': 'Prendiamocene cura insieme',
      'chapterCareBody': 'Resta al sicuro e contribuisci agli spazi condivisi.',
      'chapterProgress': '{completed}/{total} completati',
      'wholeJourneyTitle': 'Il tuo intero percorso di ambientamento',
      'wholeJourneyBody':
          'Esplora tutte le esperienze o rivedi ciò che ti è già familiare.',
      'connectionPulse': 'Il tuo livello di connessione',
      'pulseStart': 'Il primo legame locale inizia con un passo utile.',
      'pulseGrowing':
          'I sistemi poco familiari stanno diventando abitudini quotidiane.',
      'pulseBelonging':
          'Stai creando un ritmo locale e legami sempre più forti.',
      'pulseComplete':
          'Il percorso iniziale è completo, ma la tua storia locale continua.',
      'familiarMoments': 'aspetti familiari',
      'localTools': 'strumenti locali',
      'passportStories': 'storie nel Passaporto',
      'recentMoment': 'Esperienza locale recente',
      'seeWholeJourney': 'Vedi l’intero percorso',
      'completeCompanionTitle': 'Hai costruito solide basi nella comunità',
      'completeCompanionBody':
          'Continua a esplorare, incontrare persone e aggiungere esperienze significative al Passaporto.',
      'belongingEyebrow': 'DALL’ARRIVO ALL’APPARTENENZA',
      'belongingTitle': 'Un percorso che unisce ogni aspetto',
      'belongingBody':
          'Procedi al tuo ritmo tra servizi essenziali, autonomia, persone e cura del quartiere.',
      'rooted': 'Ben radicato',
      'growing': 'In crescita',
      'readyWhenYouAre': 'Quando vuoi, si parte',
      'toolkitEyebrow': 'I TUOI STRUMENTI LOCALI',
      'toolkitTitle': 'Informazioni utili, pronte quando servono',
      'toolkitBody':
          'Riunisci i piccoli dettagli della vita locale per trovarli facilmente.',
      'anchorsReady': 'pronti',
      'companionHeroLabel': 'Il tuo compagno per ambientarti',
      'heroCompanionStart': 'Inizia a rendere Canada Bay un luogo familiare',
      'heroCompanionGrowing': 'Il tuo nuovo quartiere sta prendendo forma',
      'heroCompanionBelonging': 'Stai costruendo una vita ricca di legami',
      'heroCompanionComplete': 'Canada Bay sta diventando la tua comunità',
      'heroCompanionStartBody':
          'Un passo concreto può rendere molto più semplice un luogo nuovo.',
      'heroCompanionGrowingBody':
          'Ogni dettaglio salvato ed esperienza locale aumenta la sicurezza.',
      'heroCompanionCompleteBody':
          'Il piano iniziale è completo, ma la tua storia locale continua.',
      'heroFamiliarCount': '{count} momenti locali familiari',
      'wholeJourneyProgress':
          '{completed}/{total} passaggi familiari · Sfogliali tutti',
      'scanWhenThere': 'Scansiona sul posto',
    },
    'hi': {
      'continueExplore': 'Explore Canada Bay में आगे बढ़ें',
      'guidanceReviewed':
          'मार्गदर्शन की समीक्षा {date} को हुई · हमेशा मौजूदा संकेतों और आधिकारिक सलाह का पालन करें।',
      'binActivityTitle': 'कूड़ा उठाने का दिन पक्का हुआ',
      'binActivityBody':
          '{day} की कूड़ा उठाने की जानकारी आपके पासपोर्ट में सेव की गई।',
      'binReminderSaved':
          'कूड़ेदान की रात सेव हो गई। आपको एक शाम पहले याद दिलाया जाएगा।',
      'binDaySaved': 'कूड़ा उठाने का दिन आपके पासपोर्ट में सेव किया गया।',
      'binNotificationTitle': 'आज रात कूड़ेदान बाहर रखें',
      'binNotificationBody':
          'कूड़ा कल उठेगा। देखें कि कौन-से कूड़ेदान लेने हैं और उन्हें आज शाम बाहर रखें।',
      'binNotificationChannel': 'कूड़ेदान रात अनुस्मारक',
      'binNotificationChannelDescription':
          'घरेलू कूड़ा संग्रह के साप्ताहिक अनुस्मारक',
      'libraryActivityTitle': 'लाइब्रेरी सदस्यता जोड़ी गई',
      'libraryActivityBody':
          'लाइब्रेरी कार्ड की पहचान स्थानीय ज़रूरी जानकारी में सेव है।',
      'librarySaved': 'लाइब्रेरी कार्ड की पहचान पासपोर्ट में सेव की गई।',
      'transportActivityTitle': 'नियमित परिवहन स्टॉप सेव हुआ',
      'transportActivityBody':
          '{stop} को आपकी {mode} यात्रा के शुरुआती स्थान के रूप में सेव किया गया।',
      'transportSaved': 'परिवहन शॉर्टकट पासपोर्ट में सेव किया गया।',
      'councilSaved': 'काउंसिल रिपोर्ट की संदर्भ संख्या सेव की गई।',
      'petSaved': '{name} को आपके स्थानीय पासपोर्ट में जोड़ा गया।',
      'localEssentials': 'स्थानीय ज़रूरी जानकारी',
      'linkCopied': 'आधिकारिक लिंक क्लिपबोर्ड पर कॉपी किया गया।',
      'badgeCompleted': '{badge} बैज पूरा हुआ।',
      'journeySavedMessage': 'आपकी नए निवासी की यात्रा में सेव किया गया।',
      'saveError': 'यह चरण सेव नहीं हो सका।',
      'setupTitle': 'अपनी स्थानीय ज़रूरी जानकारी सेट करें',
      'setupBody':
          'ये जानकारियाँ अलग चेकलिस्ट नहीं, बल्कि आपके पासपोर्ट में उपयोगी कार्ड बनती हैं।',
      'binCollection': 'कूड़ा उठाना',
      'reminderOn': 'रिमाइंडर चालू',
      'reminderOff': 'रिमाइंडर बंद',
      'confirmCollectionDay': 'कूड़ा उठाने का दिन पक्का करें',
      'libraryMembership': 'लाइब्रेरी सदस्यता',
      'joinSaveCard': 'जुड़ें और कार्ड की पहचान सेव करें',
      'personalShortcuts': 'निजी शॉर्टकट',
      'optionalToolsSaved': '{count}/3 वैकल्पिक टूल सेव किए गए',
      'usualStop': 'मेरा नियमित स्टॉप',
      'saveStop': 'स्टेशन, घाट या बस स्टॉप सेव करें',
      'councilTracker': 'काउंसिल रिपोर्ट ट्रैकर',
      'keepReport': 'रिपोर्ट की संदर्भ संख्या आसानी से मिलने के लिए सेव करें',
      'petGuide': 'पालतू पशु के अनुकूल स्थानीय गाइड',
      'petStatus': '{name} · बिना पट्टे वाले क्षेत्र खोजें',
      'addPet': 'पालतू पशु जोड़ें और सही जगहें खोजें',
      'binSheetTitle': 'कूड़ेदान बाहर रखने की रात पक्की करें',
      'binSheetBody':
          'पहले काउंसिल की वेबसाइट पर अपना पता खोजें, फिर अपने घर के लिए दिखाया गया दिन सेव करें।',
      'binLookup': 'काउंसिल वेबसाइट पर मेरा पता देखें',
      'collectionDay': 'कूड़ा उठाने का दिन',
      'weekday1': 'सोमवार',
      'weekday2': 'मंगलवार',
      'weekday3': 'बुधवार',
      'weekday4': 'गुरुवार',
      'weekday5': 'शुक्रवार',
      'weekday6': 'शनिवार',
      'weekday7': 'रविवार',
      'remindNightBefore': 'एक रात पहले याद दिलाएँ',
      'weeklyAtSix': 'हर सप्ताह शाम 6:00 बजे',
      'savePassport': 'मेरे पासपोर्ट में सेव करें',
      'librarySheetTitle': 'अपनी स्थानीय लाइब्रेरी से जुड़ें',
      'librarySheetBody':
          'सदस्यता से किताबें, डिजिटल सामग्री, पढ़ने की जगह और स्थानीय कार्यक्रम मिलते हैं।',
      'openLibrary': 'लाइब्रेरी सदस्यता खोलें',
      'cardLabel': 'कार्ड का नाम या आख़िरी 4 अंक',
      'cardHint': 'उदाहरण: मेरा कार्ड · 4821',
      'libraryPrivacy':
          'निजता के लिए यहाँ PIN या पूरा बारकोड सेव न करें। यह पहचान केवल इस डिवाइस पर रहती है।',
      'transportSheetTitle': 'अपना नियमित स्टॉप सेव करें',
      'transportSheetBody':
          'पहचाना हुआ शुरुआती स्थान नई जगह में मैप और Trip Planner का उपयोग आसान बनाता है।',
      'openTransport': 'Transport for NSW देखें',
      'travelMode': 'मैं आम तौर पर कैसे यात्रा करता हूँ',
      'modeTrain': 'ट्रेन',
      'modeBus': 'बस',
      'modeFerry': 'फ़ेरी',
      'modeLightRail': 'लाइट रेल',
      'modeBike': 'साइकिल',
      'modeWalk': 'पैदल',
      'stopLabel': 'स्टेशन, घाट या स्टॉप',
      'stopHint': 'उदाहरण: Concord West Station',
      'saveTransport': 'परिवहन शॉर्टकट सेव करें',
      'councilSheetTitle': 'काउंसिल रिपोर्ट को ट्रैक करें',
      'councilSheetBody':
          'कचरा फेंकने, खराब रास्तों या दूसरी स्थानीय समस्याओं की रिपोर्ट करें और पुष्टि संख्या सेव रखें।',
      'openReport': 'आधिकारिक रिपोर्ट फ़ॉर्म खोलें',
      'reportTypeLabel': 'आपने किस समस्या की रिपोर्ट की?',
      'reportTypeHint': 'उदाहरण: टूटा हुआ फुटपाथ',
      'reportReferenceLabel': 'पुष्टि संदर्भ संख्या',
      'reportReferenceHint': 'काउंसिल से मिली संख्या यहाँ पेस्ट करें',
      'reportPrivacy':
          'यहाँ फ़ोटो, पता या निजी पत्राचार सेव न करें—केवल रिपोर्ट का नाम और संदर्भ संख्या रखें।',
      'saveReport': 'रिपोर्ट की संदर्भ संख्या सेव करें',
      'petSheetTitle': 'अपने पालतू पशु के साथ घूमें',
      'petSheetBody':
          'पालतू पशु का नाम सेव करें, फिर काउंसिल की गाइड से बिना पट्टे वाले क्षेत्र और स्थानीय नियम जानें।',
      'viewOffLeash': 'बिना पट्टे वाले क्षेत्र देखें',
      'petNameLabel': 'पालतू पशु का नाम',
      'petNameHint': 'उदाहरण: Milo',
      'addPetPassport': 'पालतू पशु को पासपोर्ट में जोड़ें',
      'waterEyebrow': 'जल सुरक्षा एक नज़र में',
      'waterTitle':
          'झंडे दिशा दिखाते हैं।\nनिगरानी बच्चों को सुरक्षित रखती है।',
      'waterBody':
          'लाइफ़गार्ड वाले समुद्र तट पर लाल और पीले झंडों के बीच तैरें। पूल के पास छोटे बच्चों पर लगातार नज़र रखें और गेट बंद रखें।',
      'flagSwimBetween': 'इन झंडों के बीच तैरें',
      'flagRed': 'लाल: तैरना मना है',
      'flagYellow': 'पीला: सावधानी ज़रूरी है',
      'contextHeading': 'ऑस्ट्रेलिया में यह क्यों महत्वपूर्ण है',
      'understandGuidance': 'मैंने यह मार्गदर्शन समझ लिया है',
      'journeyUnavailable': 'नए निवासी की यात्रा उपलब्ध नहीं है',
      'tryAgain': 'फिर कोशिश करें',
      'companionCheckInEyebrow': 'जहाँ हैं, वहीं से शुरू करें',
      'companionCheckInTitle': 'आज कौन-सी चीज़ जीवन आसान बनाएगी?',
      'companionCheckInBody':
          'अपनी ज़रूरत चुनें और ऐप एक उपयोगी अगला कदम दिखाएगा। पूरी योजना कभी भी खोली जा सकती है।',
      'needSettle': 'घर और जीवन व्यवस्थित करें',
      'needFindWay': 'आने-जाने का रास्ता जानें',
      'needMeetPeople': 'लोगों से मिलें',
      'needCareTogether': 'समुदाय की देखभाल करें',
      'needSettleReason':
          'रोज़मर्रा के जीवन को सुरक्षित और आसान बनाने वाली सेवाओं से शुरू करें।',
      'needFindWayReason':
          'अपने नए पड़ोस में आत्मविश्वास से आने-जाने का तरीका जानें।',
      'needMeetPeopleReason':
          'स्थानीय लोगों से सहज और स्वागतपूर्ण तरीके से जुड़ें।',
      'needCareTogetherReason':
          'स्थानीय सुरक्षा जानें और सबकी साझा जगहों की देखभाल में योगदान दें।',
      'rightNow': 'अभी करें',
      'revisitStep': 'चरण फिर देखें',
      'chooseAnother': 'दूसरा चुनें',
      'essentialsSaved': '{count} स्थानीय ज़रूरी जानकारियाँ सेव हैं',
      'connectionPulseTitle': 'आपके सामुदायिक जुड़ाव की स्थिति',
      'connectionPulseBody':
          '{completed}/{total} चरण · {setup} ज़रूरी जानकारियाँ · {moments} सामुदायिक अनुभव',
      'latestMoment': 'सबसे नया: {name}',
      'viewWholeJourney': 'पूरी यात्रा देखें',
      'journeyCompleteTitle': 'Canada Bay अब आपका अपना बन रहा है',
      'journeyCompleteBody':
          'आपने शुरुआती यात्रा पूरी कर ली है। घूमते रहें, लोगों से मिलें और स्थानीय अनुभव अपने पासपोर्ट में जोड़ें।',
      'belongingPathEyebrow': 'अपनापन बनाने की आपकी राह',
      'belongingPathTitle': 'घर जैसा महसूस करने के चार हिस्से',
      'belongingPathBody':
          'ये चरण ज़रूरी सेवाओं, आत्मविश्वास, लोगों और पड़ोस की देखभाल को एक साथ जोड़ते हैं।',
      'chapterSettleTitle': 'सुरक्षित महसूस करें',
      'chapterSettleBody':
          'रोज़मर्रा के जीवन में मदद करने वाली व्यवस्थाएँ समझें।',
      'chapterRhythmTitle': 'अपनी दिनचर्या बनाएँ',
      'chapterRhythmBody': 'आत्मविश्वास से घूमें और इलाके को जानें।',
      'chapterPeopleTitle': 'अपने लोगों से मिलें',
      'chapterPeopleBody': 'स्वागतपूर्ण जगहों और गतिविधियों से जुड़ें।',
      'chapterCareTitle': 'मिलकर देखभाल करें',
      'chapterCareBody': 'सुरक्षित रहें और साझा स्थानीय जगहों की देखभाल करें।',
      'chapterProgress': '{completed}/{total} पूरे',
      'wholeJourneyTitle': 'आपकी पूरी बसने और जुड़ने की यात्रा',
      'wholeJourneyBody':
          'हर अनुभव देखें या पहले से परिचित किसी चीज़ को फिर से खोलें।',
      'connectionPulse': 'आपके सामुदायिक जुड़ाव की स्थिति',
      'pulseStart': 'एक उपयोगी कदम से अपना पहला स्थानीय जुड़ाव शुरू करें।',
      'pulseGrowing': 'अनजान व्यवस्थाएँ अब परिचित दिनचर्या बन रही हैं।',
      'pulseBelonging': 'आप स्थानीय जीवन की लय और मज़बूत संबंध बना रहे हैं।',
      'pulseComplete':
          'शुरुआती यात्रा पूरी है, लेकिन आपकी स्थानीय कहानी आगे बढ़ती रहेगी।',
      'familiarMoments': 'परिचित हिस्से',
      'localTools': 'स्थानीय टूल',
      'passportStories': 'पासपोर्ट की कहानियाँ',
      'recentMoment': 'हाल का स्थानीय अनुभव',
      'seeWholeJourney': 'पूरी यात्रा देखें',
      'completeCompanionTitle': 'आपने स्थानीय जीवन की मज़बूत नींव बना ली है',
      'completeCompanionBody':
          'घूमते रहें, लोगों से मिलें और सार्थक स्थानीय अनुभव अपने पासपोर्ट में जोड़ें।',
      'belongingEyebrow': 'आगमन से अपनापन तक',
      'belongingTitle': 'जीवन के हिस्सों को जोड़ने वाली राह',
      'belongingBody':
          'ज़रूरी व्यवस्थाओं, स्थानीय आत्मविश्वास, लोगों और पड़ोस की देखभाल में अपनी गति से आगे बढ़ें।',
      'rooted': 'अच्छी तरह जुड़ा',
      'growing': 'बढ़ रहा है',
      'readyWhenYouAre': 'जब आप तैयार हों',
      'toolkitEyebrow': 'आपका स्थानीय टूलकिट',
      'toolkitTitle': 'उपयोगी जानकारी, ज़रूरत के समय तैयार',
      'toolkitBody':
          'स्थानीय जीवन की छोटी जानकारियाँ एक जगह रखें ताकि वे आसानी से मिलें।',
      'anchorsReady': 'तैयार',
      'companionHeroLabel': 'बसने में आपका साथी',
      'heroCompanionStart': 'Canada Bay को परिचित बनाना शुरू करें',
      'heroCompanionGrowing': 'आपका नया पड़ोस आकार ले रहा है',
      'heroCompanionBelonging': 'आप जुड़ाव वाला स्थानीय जीवन बना रहे हैं',
      'heroCompanionComplete': 'Canada Bay आपका समुदाय बन रहा है',
      'heroCompanionStartBody':
          'एक उपयोगी कदम नई जगह को बहुत आसान बना सकता है।',
      'heroCompanionGrowingBody':
          'हर सेव की गई जानकारी और स्थानीय अनुभव आत्मविश्वास बढ़ाता है।',
      'heroCompanionCompleteBody':
          'शुरुआती योजना पूरी है, लेकिन आपकी स्थानीय कहानी आगे बढ़ती रहेगी।',
      'heroFamiliarCount': '{count} स्थानीय पल अब परिचित',
      'wholeJourneyProgress': '{completed}/{total} चरण परिचित · सभी चरण देखें',
      'scanWhenThere': 'वहाँ पहुँचकर स्कैन करें',
    },
  };

  static const _additionalTitles = <String, Map<String, String>>{
    'zh': {
      'find-council-contact': '保存市议会联系方式',
      'learn-local-suburbs': '了解周边城区',
      'understand-opal': '了解 Opal 出行基础',
      'browse-library-programs': '浏览图书馆活动',
      'find-healthcare': '寻找附近的医疗服务',
      'learn-bond-basics': '了解租房押金基础',
      'find-conversation-group': '寻找英语会话小组',
      'prepare-emergency-plan': '制定简单的应急计划',
      'learn-river-safety': '了解河岸与河流安全',
      'choose-local-park': '选择您的本地公园',
      'sort-household-waste': '练习家庭垃圾分类',
      'plan-weekend-walk': '计划周末步行',
      'notice-local-wildlife': '观察本地野生动物',
      'visit-local-business': '发现一家本地商户',
      'save-community-event': '保存一个社区活动',
      'choose-volunteer-interest': '选择一种志愿服务方式',
      'understand-council-decisions': '了解市议会如何作出决定',
      'reflect-first-month': '回顾您的第一个月',
    },
    'ko': {
      'find-council-contact': '시의회 연락처 저장하기',
      'learn-local-suburbs': '주변 지역 알아보기',
      'understand-opal': 'Opal 교통 기본 이해하기',
      'browse-library-programs': '도서관 프로그램 찾아보기',
      'find-healthcare': '가까운 의료 서비스 찾기',
      'learn-bond-basics': '임대 보증금 기본 알아보기',
      'find-conversation-group': '영어 회화 모임 찾기',
      'prepare-emergency-plan': '간단한 비상 계획 세우기',
      'learn-river-safety': '강변과 수상 안전 알아보기',
      'choose-local-park': '나의 동네 공원 정하기',
      'sort-household-waste': '생활 쓰레기 분리 연습하기',
      'plan-weekend-walk': '주말 산책 계획하기',
      'notice-local-wildlife': '지역 야생동물 관찰하기',
      'visit-local-business': '지역 상점 발견하기',
      'save-community-event': '커뮤니티 행사 저장하기',
      'choose-volunteer-interest': '관심 있는 자원봉사 선택하기',
      'understand-council-decisions': '시의회 결정 과정 알아보기',
      'reflect-first-month': '첫 한 달 돌아보기',
    },
    'it': {
      'find-council-contact': 'Salva i contatti del Comune',
      'learn-local-suburbs': 'Conosci i quartieri vicini',
      'understand-opal': 'Impara le basi dei viaggi Opal',
      'browse-library-programs': 'Scopri un programma della biblioteca',
      'find-healthcare': 'Trova servizi sanitari vicini',
      'learn-bond-basics': 'Impara le basi del deposito cauzionale',
      'find-conversation-group': 'Trova un gruppo di conversazione inglese',
      'prepare-emergency-plan': 'Prepara un semplice piano di emergenza',
      'learn-river-safety': 'Impara la sicurezza sul fiume e sul lungomare',
      'choose-local-park': 'Scegli il tuo parco locale',
      'sort-household-waste': 'Esercitati a separare i rifiuti domestici',
      'plan-weekend-walk': 'Pianifica una passeggiata nel fine settimana',
      'notice-local-wildlife': 'Osserva la fauna locale',
      'visit-local-business': 'Scopri un’attività locale',
      'save-community-event': 'Salva un evento della comunità',
      'choose-volunteer-interest': 'Scegli un modo per fare volontariato',
      'understand-council-decisions': 'Scopri come decide il Comune',
      'reflect-first-month': 'Ripensa al tuo primo mese',
    },
    'hi': {
      'find-council-contact': 'काउंसिल की संपर्क जानकारी सहेजें',
      'learn-local-suburbs': 'आस-पास के उपनगरों को जानें',
      'understand-opal': 'ओपल यात्रा की बुनियादी बातें समझें',
      'browse-library-programs': 'लाइब्रेरी कार्यक्रम देखें',
      'find-healthcare': 'नज़दीकी स्वास्थ्य सेवाएँ खोजें',
      'learn-bond-basics': 'किराये के बॉन्ड की बुनियादी बातें जानें',
      'find-conversation-group': 'अंग्रेज़ी वार्तालाप समूह खोजें',
      'prepare-emergency-plan': 'एक सरल आपातकालीन योजना बनाएँ',
      'learn-river-safety': 'नदी और तट की सुरक्षा जानें',
      'choose-local-park': 'अपना स्थानीय पार्क चुनें',
      'sort-household-waste': 'घरेलू कचरा अलग करने का अभ्यास करें',
      'plan-weekend-walk': 'सप्ताहांत की सैर की योजना बनाएँ',
      'notice-local-wildlife': 'स्थानीय वन्यजीवों को देखें',
      'visit-local-business': 'एक स्थानीय व्यवसाय खोजें',
      'save-community-event': 'एक सामुदायिक कार्यक्रम सहेजें',
      'choose-volunteer-interest': 'स्वयंसेवा का एक तरीका चुनें',
      'understand-council-decisions': 'जानें कि काउंसिल निर्णय कैसे लेती है',
      'reflect-first-month': 'अपने पहले महीने पर विचार करें',
    },
  };

  static const _sections = <String, Map<String, String>>{
    'zh': {
      'First 48 hours': '最初48小时',
      'Your first week': '第一周',
      'Your first month': '第一个月',
      'Australian water safety': '澳大利亚水上安全',
      'Know your neighbourhood': '了解您的社区',
      'Feel connected': '融入社区',
      'Care for your neighbourhood': '关爱您的社区',
    },
    'ko': {
      'First 48 hours': '처음 48시간',
      'Your first week': '첫 주',
      'Your first month': '첫 달',
      'Australian water safety': '호주의 물놀이 안전',
      'Know your neighbourhood': '우리 동네 알아보기',
      'Feel connected': '지역사회와 연결되기',
      'Care for your neighbourhood': '우리 동네 돌보기',
    },
    'it': {
      'First 48 hours': 'Prime 48 ore',
      'Your first week': 'La tua prima settimana',
      'Your first month': 'Il tuo primo mese',
      'Australian water safety': 'Sicurezza in acqua in Australia',
      'Know your neighbourhood': 'Conosci il tuo quartiere',
      'Feel connected': 'Entra nella comunità',
      'Care for your neighbourhood': 'Prenditi cura del quartiere',
    },
    'hi': {
      'First 48 hours': 'पहले 48 घंटे',
      'Your first week': 'आपका पहला सप्ताह',
      'Your first month': 'आपका पहला महीना',
      'Australian water safety': 'ऑस्ट्रेलिया में जल सुरक्षा',
      'Know your neighbourhood': 'अपने पड़ोस को जानें',
      'Feel connected': 'समुदाय से जुड़ें',
      'Care for your neighbourhood': 'अपने पड़ोस की देखभाल करें',
    },
  };

  static const _taskSections = <String, String>{
    'know-triple-zero': 'First 48 hours',
    'use-an-interpreter': 'First 48 hours',
    'find-bin-day': 'Your first week',
    'plan-first-trip': 'Your first week',
    'discover-library': 'Your first week',
    'check-medicare': 'Your first week',
    'know-rental-rights': 'Your first month',
    'find-english-support': 'Your first month',
    'swim-between-flags': 'Australian water safety',
    'home-pool-safety': 'Australian water safety',
    'complete-local-route': 'Know your neighbourhood',
    'join-community-activity': 'Feel connected',
    'help-local-environment': 'Feel connected',
    'find-council-contact': 'First 48 hours',
    'learn-local-suburbs': 'Your first week',
    'understand-opal': 'Your first week',
    'browse-library-programs': 'Your first week',
    'find-healthcare': 'Your first week',
    'learn-bond-basics': 'Your first month',
    'find-conversation-group': 'Feel connected',
    'prepare-emergency-plan': 'Your first month',
    'learn-river-safety': 'Australian water safety',
    'choose-local-park': 'Know your neighbourhood',
    'sort-household-waste': 'Care for your neighbourhood',
    'plan-weekend-walk': 'Know your neighbourhood',
    'notice-local-wildlife': 'Know your neighbourhood',
    'visit-local-business': 'Feel connected',
    'save-community-event': 'Feel connected',
    'choose-volunteer-interest': 'Feel connected',
    'understand-council-decisions': 'Care for your neighbourhood',
    'reflect-first-month': 'Feel connected',
  };

  static const _tasks = <String, Map<String, _JourneyTranslation>>{
    'en': {
      'find-council-contact': _JourneyTranslation(
        title: 'Save the Council contact details',
        summary:
            'Know where to ask about local services, facilities and neighbourhood concerns.',
        action: 'Explore local services',
      ),
      'learn-local-suburbs': _JourneyTranslation(
        title: 'Learn the suburbs around you',
        summary:
            'Use the map to recognise nearby suburbs, foreshore areas and useful local landmarks.',
        action: 'Open the local map',
      ),
      'understand-opal': _JourneyTranslation(
        title: 'Understand Opal travel basics',
        summary:
            'Learn how to tap on and off and where to check fares before your next trip.',
        action: 'Explore transport help',
      ),
      'browse-library-programs': _JourneyTranslation(
        title: 'Browse a library program',
        summary:
            'Find a free session, workshop or activity that feels useful or welcoming.',
        action: 'Browse community activities',
      ),
      'find-healthcare': _JourneyTranslation(
        title: 'Find nearby healthcare options',
        summary:
            'Identify where you could seek routine medical help and where to go after hours.',
        action: 'Explore health services',
      ),
      'find-conversation-group': _JourneyTranslation(
        title: 'Find an English conversation group',
        summary:
            'Choose a friendly local place where you can practise English and meet people.',
        action: 'Find a local group',
      ),
      'prepare-emergency-plan': _JourneyTranslation(
        title: 'Make a simple emergency plan',
        summary:
            'Choose a household contact, note essential numbers and think about where you would meet.',
        action: 'Review emergency services',
      ),
      'learn-river-safety': _JourneyTranslation(
        title: 'Learn foreshore and river safety',
        summary:
            'Notice changing conditions, slippery edges and signs before enjoying the Parramatta River foreshore.',
        action: 'Explore a safe foreshore route',
      ),
      'choose-local-park': _JourneyTranslation(
        title: 'Choose your local park',
        summary:
            'Find a nearby green space you could revisit for exercise, rest or time with others.',
        action: 'Find a park',
      ),
      'sort-household-waste': _JourneyTranslation(
        title: 'Practise sorting household waste',
        summary:
            'Check one everyday item and learn which Canada Bay bin it belongs in.',
        action: 'Review waste services',
      ),
      'plan-weekend-walk': _JourneyTranslation(
        title: 'Plan a weekend walk',
        summary:
            'Pick a route, check its distance and invite someone to explore Canada Bay with you.',
        action: 'Choose a walking route',
      ),
      'notice-local-wildlife': _JourneyTranslation(
        title: 'Notice local wildlife',
        summary:
            'Use a biodiversity checkpoint to learn about a species sharing your neighbourhood.',
        action: 'Explore biodiversity places',
      ),
      'visit-local-business': _JourneyTranslation(
        title: 'Discover a local business',
        summary:
            'Find an independent cafe, shop or service and become more familiar with a local centre.',
        action: 'Explore local places',
      ),
      'save-community-event': _JourneyTranslation(
        title: 'Save a community event',
        summary:
            'Choose one upcoming activity you may enjoy and make a simple plan to attend.',
        action: 'Browse local events',
      ),
      'choose-volunteer-interest': _JourneyTranslation(
        title: 'Choose a way to volunteer',
        summary:
            'Find a local cause that matches your interests, availability and confidence.',
        action: 'Explore volunteering',
      ),
      'understand-council-decisions': _JourneyTranslation(
        title: 'See how Council decisions are made',
        summary:
            'Learn where community consultations, meeting information and local updates are shared.',
        action: 'Explore Council services',
      ),
      'reflect-first-month': _JourneyTranslation(
        title: 'Reflect on your first month',
        summary:
            'Look back at the places, services and people that now make Canada Bay feel more familiar.',
        action: 'Open your Community Passport',
      ),
    },
    'zh': {
      'know-triple-zero': _JourneyTranslation(
        title: '了解何时拨打000',
        summary: '了解哪些情况需要拨打000，以及如何联系非紧急警务服务或新州紧急服务处。',
        action: '阅读紧急情况指南',
      ),
      'use-an-interpreter': _JourneyTranslation(
        title: '了解如何申请口译员',
        summary: '联系政府部门和重要服务时，您可以询问是否提供语言协助。',
        action: '查看口译帮助',
      ),
      'find-bin-day': _JourneyTranslation(
        title: '确认垃圾桶收集日',
        summary: '查询您住址的收集日期，并了解不同垃圾桶分别可以放哪些物品。',
        action: '设置垃圾桶收集日',
      ),
      'plan-first-trip': _JourneyTranslation(
        title: '规划第一次本地公共交通出行',
        summary: '使用新州交通行程规划器了解附近的火车、公交车和渡轮。',
        action: '设置常用车站',
      ),
      'discover-library': _JourneyTranslation(
        title: '加入本地图书馆',
        summary: '了解免费会员服务、寻找最近的分馆，并在社区护照中保存安全的借书卡提示。',
        action: '设置图书馆会员',
      ),
      'check-medicare': _JourneyTranslation(
        title: '查询Medicare资格',
        summary: '了解哪些人可以申请、需要哪些材料，以及如何通过myGov办理。',
        action: '查询Medicare资格',
      ),
      'know-rental-rights': _JourneyTranslation(
        title: '了解租房权利',
        summary: '了解租约、押金、维修、租金支付以及发生租赁问题时如何获得帮助。',
        action: '阅读新州租房指南',
      ),
      'find-english-support': _JourneyTranslation(
        title: '寻找免费英语学习支持',
        summary: '查看成人移民英语课程、在线学习或本地英语交流小组是否适合您。',
        action: '查看免费英语支持',
      ),
      'swim-between-flags': _JourneyTranslation(
        title: '了解海滩旗帜',
        summary: '红黄旗之间是有人巡逻的游泳区域。下水前请了解其他警告标志。',
        action: '学习旗帜含义',
      ),
      'home-pool-safety': _JourneyTranslation(
        title: '保护儿童泳池安全',
        summary: '了解主动看护、自闭式安全门、合规围栏以及心肺复苏技能的重要性。',
        action: '阅读新州泳池指南',
      ),
      'complete-local-route': _JourneyTranslation(
        title: '完成一条加拿大湾路线',
        summary: '选择地图中的步行路线，探索海滨、公园和本地街区。',
        action: '选择路线',
      ),
      'join-community-activity': _JourneyTranslation(
        title: '参加一次社区活动',
        summary: '参加图书馆课程、本地活动、俱乐部或欢迎新居民的社区聚会。',
        action: '寻找活动',
      ),
      'help-local-environment': _JourneyTranslation(
        title: '帮助保护本地环境',
        summary: '了解Bushcare、Love Your Place或其他有组织的环境志愿活动。',
        action: '查看志愿服务',
      ),
    },
    'ko': {
      'know-triple-zero': _JourneyTranslation(
        title: '000에 언제 전화해야 하는지 알아보기',
        summary:
            '어떤 상황에서 000에 전화해야 하는지, 긴급하지 않은 경찰 업무나 NSW 긴급구조 서비스에는 어떻게 연락하는지 알아보세요.',
        action: '긴급 상황 안내 읽기',
      ),
      'use-an-interpreter': _JourneyTranslation(
        title: '통역 서비스를 요청하는 방법 알아보기',
        summary: '정부 기관과 필수 서비스에 연락할 때 언어 지원을 받을 수 있는지 문의할 수 있습니다.',
        action: '통역 지원 보기',
      ),
      'find-bin-day': _JourneyTranslation(
        title: '쓰레기통 수거일 확인하기',
        summary: '주소별 수거일을 확인하고 각 쓰레기통에 어떤 품목을 넣어야 하는지 알아보세요.',
        action: '쓰레기통 수거일 설정',
      ),
      'plan-first-trip': _JourneyTranslation(
        title: '첫 지역 대중교통 여정 계획하기',
        summary: 'Transport for NSW의 여정 계획기를 이용해 가까운 기차, 버스, 페리를 알아보세요.',
        action: '자주 이용하는 정류장 설정',
      ),
      'discover-library': _JourneyTranslation(
        title: '지역 도서관 회원 되기',
        summary:
            '무료 회원 가입 방법을 알아보고, 가장 가까운 도서관을 찾은 뒤 커뮤니티 패스포트에 안전한 도서관 카드 정보를 저장하세요.',
        action: '도서관 회원 정보 설정',
      ),
      'check-medicare': _JourneyTranslation(
        title: 'Medicare 가입 자격 확인하기',
        summary: '누가 가입할 수 있는지, 어떤 서류가 필요한지, myGov를 통해 어떻게 신청하는지 알아보세요.',
        action: 'Medicare 가입 자격 확인',
      ),
      'know-rental-rights': _JourneyTranslation(
        title: '임차인의 권리 알아보기',
        summary: '임대차 계약, 보증금, 수리, 임대료 납부, 임대차 문제가 생겼을 때 도움받는 방법을 알아보세요.',
        action: 'NSW 임대 안내 읽기',
      ),
      'find-english-support': _JourneyTranslation(
        title: '무료 영어 학습 지원 찾기',
        summary: '성인 이민자 영어 프로그램, 온라인 학습 또는 지역 영어 회화 모임이 나에게 적합한지 확인하세요.',
        action: '무료 영어 지원 보기',
      ),
      'swim-between-flags': _JourneyTranslation(
        title: '해변 깃발의 의미 알아보기',
        summary:
            '빨간색과 노란색 깃발 사이가 안전요원이 순찰하는 수영 구역입니다. 물에 들어가기 전에 다른 경고 표지의 의미도 확인하세요.',
        action: '깃발의 의미 알아보기',
      ),
      'home-pool-safety': _JourneyTranslation(
        title: '집 수영장에서 어린이를 안전하게 보호하기',
        summary:
            '적극적인 보호자 감독, 자동으로 닫히는 출입문, 규정에 맞는 울타리, 심폐소생술 능력이 왜 중요한지 알아보세요.',
        action: 'NSW 수영장 안전 안내 읽기',
      ),
      'complete-local-route': _JourneyTranslation(
        title: 'Canada Bay 지역 경로 하나 완주하기',
        summary: '지도에서 도보 경로를 선택해 물가, 공원, 지역 상권을 둘러보세요.',
        action: '경로 선택하기',
      ),
      'join-community-activity': _JourneyTranslation(
        title: '지역사회 활동에 참여하기',
        summary: '도서관 강좌, 지역 행사, 클럽 또는 새 주민을 환영하는 모임에 참여해 보세요.',
        action: '활동 찾기',
      ),
      'help-local-environment': _JourneyTranslation(
        title: '지역 환경 보호에 참여하기',
        summary: 'Bushcare, Love Your Place 또는 그 밖의 체계적인 환경 자원봉사 활동을 알아보세요.',
        action: '자원봉사 기회 보기',
      ),
    },
    'it': {
      'know-triple-zero': _JourneyTranslation(
        title: 'Sapere quando chiamare lo 000',
        summary:
            'Scopri in quali situazioni chiamare lo 000 e come contattare la polizia per questioni non urgenti o i servizi di emergenza del NSW.',
        action: 'Leggi le indicazioni per le emergenze',
      ),
      'use-an-interpreter': _JourneyTranslation(
        title: 'Scopri come richiedere un interprete',
        summary:
            'Quando contatti enti pubblici e servizi essenziali, puoi chiedere se è disponibile assistenza linguistica.',
        action: 'Consulta il servizio di interpretariato',
      ),
      'find-bin-day': _JourneyTranslation(
        title: 'Conferma il giorno di raccolta dei rifiuti',
        summary:
            'Controlla il giorno di raccolta previsto per il tuo indirizzo e scopri cosa va messo nei diversi bidoni.',
        action: 'Imposta il giorno di raccolta',
      ),
      'plan-first-trip': _JourneyTranslation(
        title:
            'Pianifica il tuo primo viaggio con il trasporto pubblico locale',
        summary:
            'Usa il pianificatore di viaggio di Transport for NSW per conoscere treni, autobus e traghetti nelle vicinanze.',
        action: 'Imposta la fermata che usi di solito',
      ),
      'discover-library': _JourneyTranslation(
        title: 'Iscriviti alla biblioteca locale',
        summary:
            'Scopri l’iscrizione gratuita, trova la sede più vicina e salva un riferimento sicuro alla tessera nel tuo Passaporto della comunità.',
        action: 'Configura l’iscrizione alla biblioteca',
      ),
      'check-medicare': _JourneyTranslation(
        title: 'Verifica se puoi iscriverti a Medicare',
        summary:
            'Scopri chi può iscriversi, quali documenti servono e come presentare la richiesta tramite myGov.',
        action: 'Verifica l’idoneità a Medicare',
      ),
      'know-rental-rights': _JourneyTranslation(
        title: 'Conosci i tuoi diritti come inquilino',
        summary:
            'Informati su contratti di locazione, deposito cauzionale, riparazioni, pagamento dell’affitto e assistenza in caso di problemi.',
        action: 'Leggi la guida agli affitti del NSW',
      ),
      'find-english-support': _JourneyTranslation(
        title: 'Trova supporto gratuito per imparare l’inglese',
        summary:
            'Scopri se fanno per te i corsi di inglese per migranti adulti, lo studio online o i gruppi locali di conversazione.',
        action: 'Consulta il supporto gratuito per l’inglese',
      ),
      'swim-between-flags': _JourneyTranslation(
        title: 'Comprendi le bandiere in spiaggia',
        summary:
            'L’area tra le bandiere rosse e gialle è sorvegliata dai bagnini. Prima di entrare in acqua, impara a riconoscere anche gli altri segnali di pericolo.',
        action: 'Impara il significato delle bandiere',
      ),
      'home-pool-safety': _JourneyTranslation(
        title: 'Proteggi i bambini vicino alla piscina di casa',
        summary:
            'Scopri l’importanza della sorveglianza attiva, dei cancelli a chiusura automatica, delle recinzioni a norma e delle competenze di rianimazione cardiopolmonare.',
        action: 'Leggi la guida del NSW sulla sicurezza in piscina',
      ),
      'complete-local-route': _JourneyTranslation(
        title: 'Completa un percorso a Canada Bay',
        summary:
            'Scegli un itinerario a piedi sulla mappa ed esplora il lungomare, i parchi e le zone commerciali locali.',
        action: 'Scegli un percorso',
      ),
      'join-community-activity': _JourneyTranslation(
        title: 'Partecipa a un’attività della comunità',
        summary:
            'Prova un corso in biblioteca, un evento locale, un’associazione o un incontro di quartiere che accoglie i nuovi residenti.',
        action: 'Trova un’attività',
      ),
      'help-local-environment': _JourneyTranslation(
        title: 'Contribuisci alla tutela dell’ambiente locale',
        summary:
            'Scopri Bushcare, Love Your Place o altre iniziative organizzate di volontariato ambientale.',
        action: 'Consulta le opportunità di volontariato',
      ),
    },
    'hi': {
      'know-triple-zero': _JourneyTranslation(
        title: 'जानें कि 000 पर कब कॉल करना है',
        summary:
            'जानें कि किन परिस्थितियों में 000 पर कॉल करना चाहिए और गैर-आपातकालीन पुलिस सेवा या NSW आपातकालीन सेवाओं से कैसे संपर्क करना है।',
        action: 'आपातकालीन जानकारी पढ़ें',
      ),
      'use-an-interpreter': _JourneyTranslation(
        title: 'दुभाषिया माँगने का तरीका जानें',
        summary:
            'सरकारी विभागों और ज़रूरी सेवाओं से संपर्क करते समय आप पूछ सकते हैं कि भाषा सहायता उपलब्ध है या नहीं।',
        action: 'दुभाषिया सहायता देखें',
      ),
      'find-bin-day': _JourneyTranslation(
        title: 'कूड़ेदान उठाने का दिन पक्का करें',
        summary:
            'अपने पते के लिए कूड़ा उठाने का दिन देखें और जानें कि अलग-अलग कूड़ेदानों में क्या डालना है।',
        action: 'कूड़ा उठाने का दिन सेट करें',
      ),
      'plan-first-trip': _JourneyTranslation(
        title: 'स्थानीय सार्वजनिक परिवहन से अपनी पहली यात्रा की योजना बनाएँ',
        summary:
            'आस-पास की ट्रेन, बस और फ़ेरी सेवाओं को समझने के लिए Transport for NSW के ट्रिप प्लानर का इस्तेमाल करें।',
        action: 'अपना नियमित स्टॉप सेट करें',
      ),
      'discover-library': _JourneyTranslation(
        title: 'स्थानीय लाइब्रेरी से जुड़ें',
        summary:
            'मुफ़्त सदस्यता के बारे में जानें, नज़दीकी शाखा खोजें और अपने कम्युनिटी पासपोर्ट में लाइब्रेरी कार्ड की सुरक्षित पहचान सेव करें।',
        action: 'लाइब्रेरी सदस्यता सेट करें',
      ),
      'check-medicare': _JourneyTranslation(
        title: 'Medicare की पात्रता जाँचें',
        summary:
            'जानें कि कौन नामांकन कर सकता है, किन दस्तावेज़ों की ज़रूरत है और myGov से आवेदन कैसे करना है।',
        action: 'Medicare की पात्रता जाँचें',
      ),
      'know-rental-rights': _JourneyTranslation(
        title: 'किरायेदार के अधिकार जानें',
        summary:
            'लीज़, रेंटल बॉन्ड यानी सुरक्षा राशि, मरम्मत, किराया चुकाने और किराये से जुड़ी समस्या होने पर मदद पाने के बारे में जानें।',
        action: 'NSW की किराया गाइड पढ़ें',
      ),
      'find-english-support': _JourneyTranslation(
        title: 'अंग्रेज़ी सीखने की मुफ़्त सहायता खोजें',
        summary:
            'देखें कि वयस्क प्रवासी अंग्रेज़ी कार्यक्रम, ऑनलाइन पढ़ाई या स्थानीय अंग्रेज़ी बातचीत समूह आपके लिए सही हैं या नहीं।',
        action: 'अंग्रेज़ी की मुफ़्त सहायता देखें',
      ),
      'swim-between-flags': _JourneyTranslation(
        title: 'समुद्र तट के झंडों को समझें',
        summary:
            'लाल और पीले झंडों के बीच का हिस्सा लाइफ़गार्ड की निगरानी वाला तैराकी क्षेत्र है। पानी में जाने से पहले दूसरे चेतावनी संकेत भी समझें।',
        action: 'झंडों का मतलब जानें',
      ),
      'home-pool-safety': _JourneyTranslation(
        title: 'घर के पूल के पास बच्चों को सुरक्षित रखें',
        summary:
            'सक्रिय निगरानी, अपने-आप बंद होने वाले गेट, नियमों के मुताबिक बाड़ और CPR कौशल की अहमियत जानें।',
        action: 'NSW की पूल गाइड पढ़ें',
      ),
      'complete-local-route': _JourneyTranslation(
        title: 'Canada Bay का एक स्थानीय रास्ता पूरा करें',
        summary:
            'मैप से पैदल चलने का रास्ता चुनें और तट, पार्कों और स्थानीय बाज़ार क्षेत्रों को देखें।',
        action: 'रास्ता चुनें',
      ),
      'join-community-activity': _JourneyTranslation(
        title: 'किसी सामुदायिक गतिविधि में शामिल हों',
        summary:
            'लाइब्रेरी की कक्षा, स्थानीय कार्यक्रम, क्लब या नए निवासियों का स्वागत करने वाली सामुदायिक बैठक में जाएँ।',
        action: 'गतिविधियाँ खोजें',
      ),
      'help-local-environment': _JourneyTranslation(
        title: 'स्थानीय पर्यावरण की देखभाल में मदद करें',
        summary:
            'Bushcare, Love Your Place या पर्यावरण से जुड़ी दूसरी संगठित स्वयंसेवी गतिविधियों के बारे में जानें।',
        action: 'स्वयंसेवा के अवसर देखें',
      ),
    },
  };

  static const _contextNotes = <String, Map<String, String>>{
    'en': {
      'know-triple-zero':
          'In Australia, 000 is only for urgent threats to life or property. Different numbers handle non-urgent police and storm assistance.',
      'use-an-interpreter':
          'You can ask many government services to arrange an interpreter. Needing language support should not stop you from accessing essential help.',
      'find-bin-day':
          'Households separate general waste, recycling and garden organics. Collection schedules and bin colours may differ from where you lived before.',
      'discover-library':
          'Australian public libraries offer much more than books: free Wi-Fi, digital resources, study space, children’s programs and community activities.',
      'check-medicare':
          'Medicare is Australia’s public health insurance system. Eligibility depends on citizenship, residency and visa circumstances.',
      'know-rental-rights':
          'A lease is a legal agreement. NSW rules cover bonds, rent increases, repairs, privacy and how a landlord may end a tenancy.',
      'find-english-support':
          'Eligible migrants may access free government-funded English tuition. Libraries and community groups may also run informal conversation sessions.',
    },
    'zh': {
      'know-triple-zero': '在澳大利亚，000仅用于生命或财产受到紧急威胁的情况。非紧急警务和风暴援助使用其他电话号码。',
      'use-an-interpreter': '许多政府服务可以安排口译员。语言障碍不应妨碍您获得重要帮助。',
      'find-bin-day': '澳大利亚家庭通常将普通垃圾、可回收物和园林垃圾分类处理。收集安排和垃圾桶颜色可能与您以前居住的地方不同。',
      'discover-library': '澳大利亚公共图书馆不仅提供书籍，还常有免费无线网络、电子资源、自习空间、儿童项目和社区活动。',
      'check-medicare': 'Medicare是澳大利亚的公共医疗保险制度。资格取决于公民身份、居留身份和签证情况。',
      'know-rental-rights': '租约是具有法律效力的协议。新州法律规定押金、涨租、维修、隐私以及房东终止租约的程序。',
      'find-english-support': '符合条件的移民可以参加政府资助的免费英语课程。图书馆和社区组织也可能提供英语交流活动。',
    },
    'ko': {
      'know-triple-zero':
          '호주에서 000은 생명이나 재산이 즉각적인 위험에 처한 경우에만 이용합니다. 긴급하지 않은 경찰 업무와 폭풍 피해 지원은 다른 전화번호로 요청합니다.',
      'use-an-interpreter':
          '여러 정부 서비스에서 통역을 주선해 달라고 요청할 수 있습니다. 언어 지원이 필요하더라도 필수 도움을 받는 데 장벽이 되어서는 안 됩니다.',
      'find-bin-day':
          '호주 가정에서는 일반 쓰레기, 재활용품, 정원 유기 폐기물을 분리합니다. 수거 일정과 쓰레기통 색상은 이전에 살던 곳과 다를 수 있습니다.',
      'discover-library':
          '호주 공공도서관은 책뿐 아니라 무료 Wi-Fi, 디지털 자료, 학습 공간, 어린이 프로그램, 지역사회 활동도 제공합니다.',
      'check-medicare':
          'Medicare는 호주의 공공 의료보험 제도입니다. 가입 자격은 시민권, 거주 자격, 비자 상황에 따라 달라집니다.',
      'know-rental-rights':
          '임대차 계약은 법적 계약입니다. NSW 규정에는 보증금, 임대료 인상, 수리, 사생활 보호, 임대인의 계약 종료 절차가 포함됩니다.',
      'find-english-support':
          '자격 요건을 충족하는 이민자는 정부가 지원하는 무료 영어 교육을 받을 수 있습니다. 도서관과 지역 단체에서 비공식 회화 모임을 운영하기도 합니다.',
    },
    'it': {
      'know-triple-zero':
          'In Australia, lo 000 va usato solo in caso di minaccia urgente alla vita o ai beni. Per la polizia in situazioni non urgenti e per l’assistenza durante le tempeste si usano numeri diversi.',
      'use-an-interpreter':
          'Puoi chiedere a molti servizi pubblici di organizzare un interprete. La necessità di assistenza linguistica non dovrebbe impedirti di ricevere un aiuto essenziale.',
      'find-bin-day':
          'Le famiglie australiane separano i rifiuti generici, i materiali riciclabili e gli scarti da giardino. I calendari di raccolta e i colori dei bidoni possono essere diversi da quelli del luogo in cui vivevi prima.',
      'discover-library':
          'Le biblioteche pubbliche australiane offrono molto più dei libri: Wi-Fi gratuito, risorse digitali, spazi per lo studio, programmi per bambini e attività comunitarie.',
      'check-medicare':
          'Medicare è il sistema sanitario pubblico australiano. L’idoneità dipende dalla cittadinanza, dallo status di residenza e dalla situazione del visto.',
      'know-rental-rights':
          'Un contratto di locazione è un accordo legale. Le norme del NSW regolano deposito cauzionale, aumenti dell’affitto, riparazioni, privacy e modalità con cui il proprietario può porre fine alla locazione.',
      'find-english-support':
          'I migranti idonei possono accedere a corsi di inglese gratuiti finanziati dal governo. Biblioteche e gruppi comunitari possono inoltre organizzare incontri informali di conversazione.',
    },
    'hi': {
      'know-triple-zero':
          'ऑस्ट्रेलिया में 000 केवल तभी इस्तेमाल किया जाता है जब जीवन या संपत्ति को तत्काल खतरा हो। गैर-आपातकालीन पुलिस सहायता और तूफ़ान से जुड़ी सहायता के लिए अलग नंबर हैं।',
      'use-an-interpreter':
          'आप कई सरकारी सेवाओं से दुभाषिए की व्यवस्था करने के लिए कह सकते हैं। भाषा सहायता की ज़रूरत आपको आवश्यक मदद पाने से नहीं रोकनी चाहिए।',
      'find-bin-day':
          'ऑस्ट्रेलिया में घरों का सामान्य कूड़ा, रीसाइक्लिंग और बगीचे का जैविक कचरा अलग किया जाता है। कूड़ा उठाने का समय और कूड़ेदानों के रंग आपके पिछले निवास स्थान से अलग हो सकते हैं।',
      'discover-library':
          'ऑस्ट्रेलिया की सार्वजनिक लाइब्रेरी किताबों से कहीं अधिक सुविधाएँ देती हैं—मुफ़्त Wi-Fi, डिजिटल सामग्री, पढ़ाई की जगह, बच्चों के कार्यक्रम और सामुदायिक गतिविधियाँ।',
      'check-medicare':
          'Medicare ऑस्ट्रेलिया की सार्वजनिक स्वास्थ्य बीमा व्यवस्था है। पात्रता नागरिकता, निवास स्थिति और वीज़ा परिस्थितियों पर निर्भर करती है।',
      'know-rental-rights':
          'लीज़ एक कानूनी समझौता है। NSW के नियम रेंटल बॉन्ड, किराया बढ़ोतरी, मरम्मत, निजता और मकान मालिक द्वारा किरायेदारी खत्म करने के तरीके को नियंत्रित करते हैं।',
      'find-english-support':
          'पात्र प्रवासियों को सरकार द्वारा वित्तपोषित मुफ़्त अंग्रेज़ी कक्षाएँ मिल सकती हैं। लाइब्रेरी और सामुदायिक समूह अनौपचारिक बातचीत सत्र भी चला सकते हैं।',
    },
  };
}

class _JourneyTranslation {
  const _JourneyTranslation({
    required this.title,
    required this.summary,
    required this.action,
  });

  final String title;
  final String summary;
  final String action;
}
