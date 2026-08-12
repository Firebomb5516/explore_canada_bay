import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Small, dependency-free application string catalogue.
///
/// Stable proper names and technical values remain canonical, while this
/// catalogue translates shared interface language and app-owned descriptive
/// content. Domain catalogues provide their own locale-aware content fields.
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale('ko'),
    Locale('it'),
    Locale('hi'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('en'));
  }

  String text(String key) {
    final language = _values[locale.languageCode] ?? _values['en']!;
    return language[key] ?? _values['en']![key] ?? key;
  }

  /// Replaces named placeholders in a keyed message.
  String message(String key, Map<String, Object?> values) {
    var result = text(key);
    for (final entry in values.entries) {
      final raw = '${entry.value ?? ''}';
      result = result.replaceAll(
        '{${entry.key}}',
        entry.value is String ? literal(raw) : raw,
      );
    }
    return result;
  }

  /// Returns true only when [key] exists in the requested locale itself.
  /// This deliberately does not count the English runtime fallback.
  static bool hasOwnTranslation(String languageCode, String key) =>
      _values[languageCode]?.containsKey(key) ?? false;

  static Set<String> get requiredTextKeys =>
      Set.unmodifiable(_values['en']!.keys);

  static Set<String> get requiredScreenPhrases =>
      Set.unmodifiable(_screenPhrases.keys);

  static Set<String> get requiredDynamicPhrases =>
      Set.unmodifiable(_dynamicPhrases.keys);

  static Set<String> get requiredInterfaceLiterals => Set.unmodifiable(
    _interfaceLiterals.values.expand((language) => language.keys).toSet(),
  );

  static bool hasScreenPhraseTranslation(String languageCode, String source) =>
      _screenPhrases[source]?.containsKey(languageCode) ?? false;

  static bool hasDynamicPhraseTranslation(String languageCode, String source) =>
      _dynamicPhrases[source]?.containsKey(languageCode) ?? false;

  static bool hasInterfaceLiteralTranslation(
    String languageCode,
    String source,
  ) => _interfaceLiterals[languageCode]?.containsKey(source) ?? false;

  /// Localises hard-coded interface literals while leaving proper names and
  /// JSON content unchanged. Dynamic counters are handled by their stable
  /// prefix/suffix patterns.
  String literal(String source) {
    if (locale.languageCode == 'en') return source;
    final screen = _screenPhrases[source]?[locale.languageCode];
    if (screen != null) return screen;
    final direct = _interfaceLiterals[locale.languageCode]?[source];
    if (direct != null) return direct;
    final key = _literalKeys[source];
    if (key != null) return text(key);

    final dynamic = _translateDynamicPhrase(source);
    if (dynamic != null) return dynamic;

    final level = RegExp(r'^Level (\d+)$').firstMatch(source);
    if (level != null) {
      return text('levelNumber').replaceAll('{number}', level.group(1)!);
    }
    final xp = RegExp(r'^(\d+) XP$').firstMatch(source);
    if (xp != null) return '${xp.group(1)} XP';
    return source;
  }

  String? _translateDynamicPhrase(String source) {
    for (final entry in _dynamicPhrases.entries) {
      final template = entry.key;
      final translated = entry.value[locale.languageCode];
      if (translated == null) continue;

      final placeholders = RegExp(
        r'\{([a-zA-Z0-9_]+)\}',
      ).allMatches(template).toList(growable: false);
      final pattern = StringBuffer('^');
      var cursor = 0;
      for (final placeholder in placeholders) {
        pattern.write(
          RegExp.escape(template.substring(cursor, placeholder.start)),
        );
        pattern.write('(.*?)');
        cursor = placeholder.end;
      }
      pattern.write(RegExp.escape(template.substring(cursor)));
      pattern.write(r'$');

      final match = RegExp(pattern.toString()).firstMatch(source);
      if (match == null) continue;
      var result = translated;
      for (var index = 0; index < placeholders.length; index++) {
        final value = match.group(index + 1) ?? '';
        result = result.replaceAll(
          '{${placeholders[index].group(1)}}',
          literal(value),
        );
      }
      return result;
    }
    return null;
  }

  String weekday(int weekday) => text('weekday$weekday');

  String transportMode(String source) => switch (source) {
    'Train' => text('modeTrain'),
    'Bus' => text('modeBus'),
    'Ferry' => text('modeFerry'),
    'Light rail' => text('modeLightRail'),
    'Bike' => text('modeBike'),
    'Walk' => text('modeWalk'),
    'Public transport' => text('modePublicTransport'),
    _ => source,
  };

  String qrError(String source) {
    final translated = literal(source);
    if (translated != source) return translated;
    if (source.contains('must be a non-empty string')) {
      return text('qrInvalidField');
    }
    if (source.contains('must be no more than')) return text('qrFieldTooLong');
    if (source.contains('must be an integer')) return text('qrInvalidNumber');
    if (source.contains('must be a JSON object')) {
      return text('qrInvalidObject');
    }
    if (source.contains('must be an HTTP or HTTPS URL')) {
      return text('qrInvalidLink');
    }
    return text('qrInvalidGeneric');
  }

  String rewardMessage({
    required String placeName,
    required int xp,
    required bool duplicate,
    required bool badgeJustEarned,
    String? badgeName,
    int? badgeProgress,
    int? badgeTarget,
  }) {
    if (duplicate) {
      return message('rewardDuplicate', {'place': placeName});
    }
    if (badgeName != null && badgeJustEarned) {
      return message(xp > 0 ? 'rewardBadgeXp' : 'rewardBadge', {
        'badge': badgeName,
        'xp': xp,
      });
    }
    if (badgeName != null && badgeProgress != null && badgeTarget != null) {
      return message(xp > 0 ? 'rewardProgressXp' : 'rewardProgress', {
        'place': placeName,
        'badge': badgeName,
        'progress': badgeProgress,
        'target': badgeTarget,
        'xp': xp,
      });
    }
    if (xp > 0) return message('rewardXp', {'place': placeName, 'xp': xp});
    return message('rewardAdded', {'place': placeName});
  }

  /// Exact user-facing phrases which are still supplied by legacy widgets.
  /// Keeping this table strict lets us migrate those widgets incrementally
  /// without allowing an English phrase to leak into another locale.
  static const Map<String, Map<String, String>> _screenPhrases = {
    'COMMUNITY CHALLENGE': {
      'zh': '社区挑战',
      'ko': '커뮤니티 도전',
      'it': 'SFIDA DELLA COMUNITÀ',
      'hi': 'सामुदायिक चुनौती',
    },
    'Community challenge': {
      'zh': '社区挑战',
      'ko': '커뮤니티 도전',
      'it': 'Sfida della comunità',
      'hi': 'सामुदायिक चुनौती',
    },
    'Together Canada Bay': {
      'zh': '加拿大湾齐参与',
      'ko': '함께하는 캐나다 베이',
      'it': 'Canada Bay insieme',
      'hi': 'टुगेदर कनाडा बे',
    },
    'Complete meaningful local activities and move the community forward together.': {
      'zh': '完成有意义的本地活动，共同推动社区进步。',
      'ko': '의미 있는 지역 활동을 완료하고 공동체와 함께 나아가세요.',
      'it':
          'Completa attività locali significative e fai crescere la comunità insieme.',
      'hi': 'सार्थक स्थानीय गतिविधियाँ पूरी करें और समुदाय को साथ आगे बढ़ाएँ।',
    },
    'Explore, volunteer, walk and learn together. Every verified Passport activity moves the whole community forward.': {
      'zh': '一起探索、志愿服务、步行和学习。每项已验证的护照活动都会推动整个社区前进。',
      'ko': '함께 탐험하고 봉사하고 걷고 배워요. 인증된 모든 패스포트 활동이 공동체를 앞으로 나아가게 합니다.',
      'it':
          'Esplora, fai volontariato, cammina e impara insieme. Ogni attività verificata del Passaporto fa avanzare tutta la comunità.',
      'hi':
          'साथ मिलकर खोजें, स्वयंसेवा करें, चलें और सीखें। हर सत्यापित पासपोर्ट गतिविधि पूरे समुदाय को आगे बढ़ाती है।',
    },
    'Unlock the Together Canada Bay digital celebration.': {
      'zh': '解锁“加拿大湾齐参与”数字庆祝内容。',
      'ko': '함께하는 캐나다 베이 디지털 축하 콘텐츠를 잠금 해제하세요.',
      'it': 'Sblocca la celebrazione digitale Canada Bay insieme.',
      'hi': 'टुगेदर कनाडा बे डिजिटल उत्सव अनलॉक करें।',
    },
    'Unlock the Together Canada Bay digital celebration and community impact story.': {
      'zh': '解锁“加拿大湾齐参与”数字庆祝内容和社区影响故事。',
      'ko': '함께하는 캐나다 베이 디지털 축하와 공동체 성과 이야기를 잠금 해제하세요.',
      'it':
          'Sblocca la celebrazione digitale Canada Bay insieme e la storia dell’impatto comunitario.',
      'hi':
          'टुगेदर कनाडा बे डिजिटल उत्सव और सामुदायिक प्रभाव कहानी अनलॉक करें।',
    },
    'Your contribution to what Canada Bay achieves together': {
      'zh': '您为加拿大湾共同成就作出的贡献',
      'ko': '캐나다 베이가 함께 이루는 성과에 대한 나의 기여',
      'it': 'Il tuo contributo ai risultati condivisi di Canada Bay',
      'hi': 'कनाडा बे की सामूहिक उपलब्धि में आपका योगदान',
    },
    'community points': {
      'zh': '社区积分',
      'ko': '커뮤니티 포인트',
      'it': 'punti comunità',
      'hi': 'सामुदायिक अंक',
    },
    'your points': {
      'zh': '您的积分',
      'ko': '내 포인트',
      'it': 'i tuoi punti',
      'hi': 'आपके अंक',
    },
    'contributors': {
      'zh': '参与者',
      'ko': '참여자',
      'it': 'partecipanti',
      'hi': 'योगदानकर्ता',
    },
    'points to go': {
      'zh': '剩余积分',
      'ko': '남은 포인트',
      'it': 'punti mancanti',
      'hi': 'शेष अंक',
    },
    'yours': {'zh': '您的贡献', 'ko': '내 기여', 'it': 'tuoi', 'hi': 'आपके'},
    'Connect Supabase to activate shared progress': {
      'zh': '连接 Supabase 以启用共享进度',
      'ko': '공동 진행률을 활성화하려면 Supabase를 연결하세요',
      'it': 'Collega Supabase per attivare i progressi condivisi',
      'hi': 'साझा प्रगति सक्रिय करने के लिए Supabase जोड़ें',
    },
    'Sign in to add your activities': {
      'zh': '登录以添加您的活动',
      'ko': '내 활동을 추가하려면 로그인하세요',
      'it': 'Accedi per aggiungere le tue attività',
      'hi': 'अपनी गतिविधियाँ जोड़ने के लिए साइन इन करें',
    },
    'Community reward unlocked!': {
      'zh': '社区奖励已解锁！',
      'ko': '커뮤니티 보상이 잠금 해제되었습니다!',
      'it': 'Ricompensa della comunità sbloccata!',
      'hi': 'सामुदायिक पुरस्कार अनलॉक हुआ!',
    },
    'Your Passport activities count automatically': {
      'zh': '您的护照活动会自动计入',
      'ko': '패스포트 활동이 자동으로 반영됩니다',
      'it': 'Le attività del Passaporto vengono conteggiate automaticamente',
      'hi': 'आपकी पासपोर्ट गतिविधियाँ अपने आप गिनी जाती हैं',
    },
    'Refresh community progress': {
      'zh': '刷新社区进度',
      'ko': '커뮤니티 진행률 새로고침',
      'it': 'Aggiorna i progressi della comunità',
      'hi': 'सामुदायिक प्रगति रीफ़्रेश करें',
    },
    'Shared progress activates when this build is connected to Supabase.': {
      'zh': '此版本连接到 Supabase 后，共享进度便会启用。',
      'ko': '이 빌드가 Supabase에 연결되면 공동 진행률이 활성화됩니다.',
      'it':
          'I progressi condivisi si attivano quando questa versione è collegata a Supabase.',
      'hi': 'इस बिल्ड के Supabase से जुड़ने पर साझा प्रगति सक्रिय होगी।',
    },
    'Sign in from Profile to contribute your Passport activities to the community total.': {
      'zh': '从个人资料登录，将您的护照活动计入社区总数。',
      'ko': '프로필에서 로그인하여 패스포트 활동을 커뮤니티 합계에 더하세요.',
      'it':
          'Accedi dal Profilo per aggiungere le attività del Passaporto al totale della comunità.',
      'hi':
          'अपनी पासपोर्ट गतिविधियाँ सामुदायिक कुल में जोड़ने के लिए प्रोफ़ाइल से साइन इन करें।',
    },
    'Join the seasonal leaderboard': {
      'zh': '加入季度排行榜',
      'ko': '시즌 순위표 참여',
      'it': 'Partecipa alla classifica stagionale',
      'hi': 'मौसमी लीडरबोर्ड में शामिल हों',
    },
    'Optional. Only a generated Neighbour alias and your points are shown.': {
      'zh': '可选。仅显示系统生成的“邻居”别名和您的积分。',
      'ko': '선택 사항입니다. 생성된 이웃 별칭과 포인트만 표시됩니다.',
      'it':
          'Facoltativo. Vengono mostrati solo un alias Neighbour generato e i tuoi punti.',
      'hi': 'वैकल्पिक। केवल बनाया गया Neighbour उपनाम और आपके अंक दिखेंगे।',
    },
    'Season leaders': {
      'zh': '本季领先者',
      'ko': '시즌 선두',
      'it': 'Leader stagionali',
      'hi': 'सीज़न लीडर्स',
    },
    'Community progress could not sync. Your Passport activity is safe and will retry.': {
      'zh': '社区进度无法同步。您的护照活动已安全保存，稍后将重试。',
      'ko': '커뮤니티 진행률을 동기화하지 못했습니다. 패스포트 활동은 안전하며 다시 시도됩니다.',
      'it':
          'Impossibile sincronizzare i progressi comunitari. Le attività del Passaporto sono al sicuro e verrà effettuato un nuovo tentativo.',
      'hi':
          'सामुदायिक प्रगति सिंक नहीं हुई। आपकी पासपोर्ट गतिविधि सुरक्षित है और फिर प्रयास होगा।',
    },
    'Explorer': {
      'zh': '探索者',
      'ko': '탐험가',
      'it': 'Esploratore',
      'hi': 'खोजकर्ता',
    },
    'Not set': {
      'zh': '未设置',
      'ko': '설정되지 않음',
      'it': 'Non impostato',
      'hi': 'सेट नहीं',
    },
    'City of Canada Bay logo': {
      'zh': '加拿大湾市徽标',
      'ko': '캐나다 베이 시 로고',
      'it': 'Logo della Città di Canada Bay',
      'hi': 'सिटी ऑफ़ कनाडा बे लोगो',
    },
    'Guest explorer': {
      'zh': '访客探索者',
      'ko': '게스트 탐험가',
      'it': 'Esploratore ospite',
      'hi': 'अतिथि खोजकर्ता',
    },
    'Coming Soon': {
      'zh': '即将推出',
      'ko': '곧 제공됩니다',
      'it': 'Prossimamente',
      'hi': 'जल्द आ रहा है',
    },
    'Cancel': {'zh': '取消', 'ko': '취소', 'it': 'Annulla', 'hi': 'रद्द करें'},
    'Save': {'zh': '保存', 'ko': '저장', 'it': 'Salva', 'hi': 'सहेजें'},
    'Close': {'zh': '关闭', 'ko': '닫기', 'it': 'Chiudi', 'hi': 'बंद करें'},
    'Retry': {
      'zh': '重试',
      'ko': '다시 시도',
      'it': 'Riprova',
      'hi': 'फिर कोशिश करें',
    },
    'Try again': {
      'zh': '重试',
      'ko': '다시 시도',
      'it': 'Riprova',
      'hi': 'फिर कोशिश करें',
    },
    'View': {'zh': '查看', 'ko': '보기', 'it': 'Visualizza', 'hi': 'देखें'},
    'Manage': {'zh': '管理', 'ko': '관리', 'it': 'Gestisci', 'hi': 'प्रबंधित करें'},
    'Official details': {
      'zh': '官方详情',
      'ko': '공식 정보',
      'it': 'Dettagli ufficiali',
      'hi': 'आधिकारिक विवरण',
    },
    'Open official source': {
      'zh': '打开官方来源',
      'ko': '공식 출처 열기',
      'it': 'Apri la fonte ufficiale',
      'hi': 'आधिकारिक स्रोत खोलें',
    },
    'The link could not open, so it was copied instead.': {
      'zh': '无法打开链接，已将其复制。',
      'ko': '링크를 열 수 없어 대신 복사했습니다.',
      'it': 'Impossibile aprire il link; è stato copiato.',
      'hi': 'लिंक नहीं खुल सका, इसलिए उसे कॉपी कर दिया गया है।',
    },
    'Create account': {
      'zh': '创建账户',
      'ko': '계정 만들기',
      'it': 'Crea account',
      'hi': 'खाता बनाएँ',
    },
    'Sign in': {'zh': '登录', 'ko': '로그인', 'it': 'Accedi', 'hi': 'साइन इन करें'},
    'Save your progress online': {
      'zh': '在线保存您的进度',
      'ko': '진행 상황을 온라인에 저장',
      'it': 'Salva i progressi online',
      'hi': 'अपनी प्रगति ऑनलाइन सहेजें',
    },
    'Welcome back': {
      'zh': '欢迎回来',
      'ko': '다시 오신 것을 환영합니다',
      'it': 'Bentornato',
      'hi': 'वापसी पर स्वागत है',
    },
    'An account is optional. Guests can still use maps, services, routes, scanning and a passport on this device.': {
      'zh': '账户为可选项。访客仍可在此设备上使用地图、服务、路线、扫描和社区护照。',
      'ko': '계정은 선택 사항입니다. 게스트도 이 기기에서 지도, 서비스, 경로, 스캔 및 패스포트를 이용할 수 있습니다.',
      'it':
          'L’account è facoltativo. Gli ospiti possono comunque usare mappe, servizi, percorsi, scansioni e passaporto su questo dispositivo.',
      'hi':
          'खाता वैकल्पिक है। अतिथि इस डिवाइस पर नक्शे, सेवाएँ, मार्ग, स्कैनिंग और पासपोर्ट का उपयोग कर सकते हैं।',
    },
    'Display name': {
      'zh': '显示名称',
      'ko': '표시 이름',
      'it': 'Nome visualizzato',
      'hi': 'दिखाया जाने वाला नाम',
    },
    'Email address': {
      'zh': '电子邮箱',
      'ko': '이메일 주소',
      'it': 'Indirizzo email',
      'hi': 'ईमेल पता',
    },
    'Email identifier': {
      'zh': '邮箱标识',
      'ko': '이메일 식별자',
      'it': 'Identificativo email',
      'hi': 'ईमेल पहचान',
    },
    'Password': {'zh': '密码', 'ko': '비밀번호', 'it': 'Password', 'hi': 'पासवर्ड'},
    'Show password': {
      'zh': '显示密码',
      'ko': '비밀번호 표시',
      'it': 'Mostra password',
      'hi': 'पासवर्ड दिखाएँ',
    },
    'Hide password': {
      'zh': '隐藏密码',
      'ko': '비밀번호 숨기기',
      'it': 'Nascondi password',
      'hi': 'पासवर्ड छिपाएँ',
    },
    'Forgot password?': {
      'zh': '忘记密码？',
      'ko': '비밀번호를 잊으셨나요?',
      'it': 'Password dimenticata?',
      'hi': 'पासवर्ड भूल गए?',
    },
    'You can continue as a guest using the button below.': {
      'zh': '您可以使用下方按钮以访客身份继续。',
      'ko': '아래 버튼을 눌러 게스트로 계속할 수 있습니다.',
      'it': 'Puoi continuare come ospite usando il pulsante qui sotto.',
      'hi': 'आप नीचे दिए बटन से अतिथि के रूप में जारी रख सकते हैं।',
    },
    'Enter a valid email and 6+ character password.': {
      'zh': '请输入有效邮箱和至少 6 个字符的密码。',
      'ko': '유효한 이메일과 6자 이상의 비밀번호를 입력하세요.',
      'it': 'Inserisci un’email valida e una password di almeno 6 caratteri.',
      'hi': 'मान्य ईमेल और कम से कम 6 अक्षरों का पासवर्ड दर्ज करें।',
    },
    'Enter a display name.': {
      'zh': '请输入显示名称。',
      'ko': '표시 이름을 입력하세요.',
      'it': 'Inserisci un nome visualizzato.',
      'hi': 'दिखाया जाने वाला नाम दर्ज करें।',
    },
    'Enter a display name': {
      'zh': '请输入显示名称',
      'ko': '표시 이름을 입력하세요',
      'it': 'Inserisci un nome visualizzato',
      'hi': 'दिखाया जाने वाला नाम दर्ज करें',
    },
    'Enter your email address first.': {
      'zh': '请先输入您的电子邮箱。',
      'ko': '먼저 이메일 주소를 입력하세요.',
      'it': 'Inserisci prima il tuo indirizzo email.',
      'hi': 'पहले अपना ईमेल पता दर्ज करें।',
    },
    'Check your email for a reset link.': {
      'zh': '请查看邮箱中的重置链接。',
      'ko': '이메일에서 재설정 링크를 확인하세요.',
      'it': 'Controlla l’email per il link di reimpostazione.',
      'hi': 'रीसेट लिंक के लिए अपना ईमेल देखें।',
    },
    'Check your email to confirm the account, then sign in.': {
      'zh': '请查看邮箱以确认账户，然后登录。',
      'ko': '이메일에서 계정을 확인한 후 로그인하세요.',
      'it': 'Controlla l’email, conferma l’account e poi accedi.',
      'hi': 'खाते की पुष्टि के लिए ईमेल देखें, फिर साइन इन करें।',
    },
    'Check your email, confirm the account, then sign in.': {
      'zh': '请查看邮箱、确认账户，然后登录。',
      'ko': '이메일에서 계정을 확인한 후 로그인하세요.',
      'it': 'Controlla l’email, conferma l’account e poi accedi.',
      'hi': 'ईमेल देखें, खाते की पुष्टि करें, फिर साइन इन करें।',
    },
    'Online accounts are not configured': {
      'zh': '尚未配置在线账户',
      'ko': '온라인 계정이 설정되지 않았습니다',
      'it': 'Gli account online non sono configurati',
      'hi': 'ऑनलाइन खाते कॉन्फ़िगर नहीं हैं',
    },
    'Continue as a guest. Sign-in becomes available when the app starts with its Supabase configuration.': {
      'zh': '请以访客身份继续。应用使用 Supabase 配置启动后即可登录。',
      'ko': '게스트로 계속하세요. 앱이 Supabase 설정으로 시작되면 로그인할 수 있습니다.',
      'it':
          'Continua come ospite. L’accesso sarà disponibile quando l’app verrà avviata con la configurazione Supabase.',
      'hi':
          'अतिथि के रूप में जारी रखें। Supabase कॉन्फ़िगरेशन के साथ ऐप शुरू होने पर साइन-इन उपलब्ध होगा।',
    },
    'Your account is ready. Cloud passport sync will be enabled in the next data stage.': {
      'zh': '您的账户已准备就绪。云端护照同步将在下一数据阶段启用。',
      'ko': '계정이 준비되었습니다. 클라우드 패스포트 동기화는 다음 데이터 단계에서 활성화됩니다.',
      'it':
          'Il tuo account è pronto. La sincronizzazione cloud del passaporto sarà attivata nella prossima fase.',
      'hi':
          'आपका खाता तैयार है। क्लाउड पासपोर्ट सिंक अगले डेटा चरण में सक्षम होगा।',
    },
    'YOUR LOCAL COMMUNITY GUIDE': {
      'zh': '您的本地社区指南',
      'ko': '우리 동네 커뮤니티 가이드',
      'it': 'LA TUA GUIDA ALLA COMUNITÀ LOCALE',
      'hi': 'आपकी स्थानीय समुदाय मार्गदर्शिका',
    },
    'Device profile': {
      'zh': '设备资料',
      'ko': '기기 프로필',
      'it': 'Profilo del dispositivo',
      'hi': 'डिवाइस प्रोफ़ाइल',
    },
    'Your local identity on this device': {
      'zh': '您在此设备上的本地身份',
      'ko': '이 기기의 내 로컬 신원',
      'it': 'La tua identità locale su questo dispositivo',
      'hi': 'इस डिवाइस पर आपकी स्थानीय पहचान',
    },
    'Personalise your experience on this device': {
      'zh': '个性化您在此设备上的体验',
      'ko': '이 기기에서 경험을 맞춤 설정하세요',
      'it': 'Personalizza l’esperienza su questo dispositivo',
      'hi': 'इस डिवाइस पर अपना अनुभव व्यक्तिगत बनाएँ',
    },
    'Edit device profile': {
      'zh': '编辑设备资料',
      'ko': '기기 프로필 편집',
      'it': 'Modifica profilo del dispositivo',
      'hi': 'डिवाइस प्रोफ़ाइल संपादित करें',
    },
    'Set up device profile': {
      'zh': '设置设备资料',
      'ko': '기기 프로필 설정',
      'it': 'Configura profilo del dispositivo',
      'hi': 'डिवाइस प्रोफ़ाइल सेट करें',
    },
    'Set up a device profile': {
      'zh': '设置设备资料',
      'ko': '기기 프로필 설정',
      'it': 'Configura un profilo del dispositivo',
      'hi': 'डिवाइस प्रोफ़ाइल सेट करें',
    },
    'Local profile only. This does not sign you into a secure online account, and it cannot be recovered on another device.': {
      'zh': '仅限本地资料。这不会让您登录安全的在线账户，也无法在其他设备上恢复。',
      'ko': '로컬 프로필 전용입니다. 보안 온라인 계정에 로그인되지 않으며 다른 기기에서 복구할 수 없습니다.',
      'it':
          'Solo profilo locale. Non effettua l’accesso a un account online sicuro e non può essere recuperato su un altro dispositivo.',
      'hi':
          'केवल स्थानीय प्रोफ़ाइल। इससे सुरक्षित ऑनलाइन खाते में साइन इन नहीं होता और इसे दूसरे डिवाइस पर पुनर्प्राप्त नहीं किया जा सकता।',
    },
    'This is a local profile, not secure cloud authentication. Its details are stored on this device and do not sync.': {
      'zh': '这是本地资料，并非安全的云端身份验证。详细信息保存在此设备上，不会同步。',
      'ko': '보안 클라우드 인증이 아닌 로컬 프로필입니다. 정보는 이 기기에 저장되며 동기화되지 않습니다.',
      'it':
          'È un profilo locale, non un’autenticazione cloud sicura. I dati restano su questo dispositivo e non vengono sincronizzati.',
      'hi':
          'यह स्थानीय प्रोफ़ाइल है, सुरक्षित क्लाउड प्रमाणीकरण नहीं। इसकी जानकारी इस डिवाइस पर रहती है और सिंक नहीं होती।',
    },
    'Know where your information is kept': {
      'zh': '了解您的信息存储位置',
      'ko': '정보가 저장되는 위치를 확인하세요',
      'it': 'Scopri dove sono conservate le tue informazioni',
      'hi': 'जानें कि आपकी जानकारी कहाँ रखी जाती है',
    },
    'Stored on this device': {
      'zh': '存储在此设备上',
      'ko': '이 기기에 저장됨',
      'it': 'Salvato su questo dispositivo',
      'hi': 'इस डिवाइस पर संग्रहीत',
    },
    'Cloud backup and account recovery are not connected yet.': {
      'zh': '云端备份和账户恢复尚未连接。',
      'ko': '클라우드 백업과 계정 복구는 아직 연결되지 않았습니다.',
      'it': 'Backup cloud e recupero account non sono ancora collegati.',
      'hi': 'क्लाउड बैकअप और खाता पुनर्प्राप्ति अभी जुड़े नहीं हैं।',
    },
    'Leave device profile': {
      'zh': '退出设备资料',
      'ko': '기기 프로필 나가기',
      'it': 'Esci dal profilo del dispositivo',
      'hi': 'डिवाइस प्रोफ़ाइल छोड़ें',
    },
    'Return this device to Guest mode': {
      'zh': '将此设备恢复为访客模式',
      'ko': '이 기기를 게스트 모드로 전환',
      'it': 'Riporta il dispositivo alla modalità ospite',
      'hi': 'इस डिवाइस को अतिथि मोड में लौटाएँ',
    },
    'Appearance': {'zh': '外观', 'ko': '화면 모양', 'it': 'Aspetto', 'hi': 'दिखावट'},
    'Choose how Explore Canada Bay looks': {
      'zh': '选择 Explore Canada Bay 的显示方式',
      'ko': 'Explore Canada Bay의 화면 모양을 선택하세요',
      'it': 'Scegli l’aspetto di Explore Canada Bay',
      'hi': 'Explore Canada Bay का रूप चुनें',
    },
    'Choose the interface language for this device': {
      'zh': '选择此设备的界面语言',
      'ko': '이 기기의 인터페이스 언어를 선택하세요',
      'it': 'Scegli la lingua dell’interfaccia per questo dispositivo',
      'hi': 'इस डिवाइस के लिए इंटरफ़ेस भाषा चुनें',
    },
    'Replay welcome setup': {
      'zh': '重新进行欢迎设置',
      'ko': '환영 설정 다시 보기',
      'it': 'Ripeti la configurazione iniziale',
      'hi': 'स्वागत सेटअप फिर चलाएँ',
    },
    'App preferences are not connected on this screen': {
      'zh': '此屏幕未连接应用偏好设置',
      'ko': '이 화면에는 앱 환경설정이 연결되지 않았습니다',
      'it': 'Le preferenze dell’app non sono collegate a questa schermata',
      'hi': 'इस स्क्रीन पर ऐप प्राथमिकताएँ जुड़ी नहीं हैं',
    },
    'Review your language, interests and newcomer profile': {
      'zh': '检查您的语言、兴趣和新居民资料',
      'ko': '언어, 관심사 및 새 주민 프로필을 검토하세요',
      'it': 'Rivedi lingua, interessi e profilo di nuovo residente',
      'hi': 'अपनी भाषा, रुचियों और नवागंतुक प्रोफ़ाइल की समीक्षा करें',
    },
    'Choose what appears when you show your passport': {
      'zh': '选择展示护照时显示的内容',
      'ko': '패스포트를 보여줄 때 표시할 항목을 선택하세요',
      'it': 'Scegli cosa mostrare nel passaporto',
      'hi': 'पासपोर्ट दिखाते समय क्या दिखाई दे, चुनें',
    },
    'Show profile name': {
      'zh': '显示资料名称',
      'ko': '프로필 이름 표시',
      'it': 'Mostra nome del profilo',
      'hi': 'प्रोफ़ाइल नाम दिखाएँ',
    },
    'Use your display name on the Community Passport': {
      'zh': '在社区护照上使用您的显示名称',
      'ko': '커뮤니티 패스포트에 표시 이름 사용',
      'it': 'Usa il nome visualizzato nel Passaporto della comunità',
      'hi': 'समुदाय पासपोर्ट पर अपना प्रदर्शित नाम उपयोग करें',
    },
    'Use the neutral Explorer label on the passport': {
      'zh': '在护照上使用中性的“探索者”称呼',
      'ko': '패스포트에 중립적인 탐험가 이름 사용',
      'it': 'Usa l’etichetta neutra Esploratore nel passaporto',
      'hi': 'पासपोर्ट पर तटस्थ “खोजकर्ता” नाम उपयोग करें',
    },
    'Show achievements': {
      'zh': '显示成就',
      'ko': '업적 표시',
      'it': 'Mostra traguardi',
      'hi': 'उपलब्धियाँ दिखाएँ',
    },
    'Display your chosen rare achievements': {
      'zh': '显示您选择的稀有成就',
      'ko': '선택한 희귀 업적 표시',
      'it': 'Mostra i traguardi rari scelti',
      'hi': 'अपनी चुनी हुई दुर्लभ उपलब्धियाँ दिखाएँ',
    },
    'Hidden while your profile name is hidden': {
      'zh': '资料名称隐藏时也会隐藏',
      'ko': '프로필 이름이 숨겨져 있는 동안 표시되지 않음',
      'it': 'Nascosti quando il nome del profilo è nascosto',
      'hi': 'प्रोफ़ाइल नाम छिपा होने पर ये भी छिपेंगी',
    },
    'What should we call you?': {
      'zh': '我们该如何称呼您？',
      'ko': '어떻게 불러 드릴까요?',
      'it': 'Come vuoi essere chiamato?',
      'hi': 'हम आपको क्या कहें?',
    },
    'Used only to separate local passport progress.': {
      'zh': '仅用于区分本地护照进度。',
      'ko': '로컬 패스포트 진행 상황을 구분하는 데만 사용됩니다.',
      'it': 'Usato solo per separare i progressi locali del passaporto.',
      'hi': 'केवल स्थानीय पासपोर्ट प्रगति अलग रखने के लिए उपयोग होता है।',
    },
    'Save locally': {
      'zh': '保存到本机',
      'ko': '로컬에 저장',
      'it': 'Salva localmente',
      'hi': 'स्थानीय रूप से सहेजें',
    },
    'Device profile saved locally.': {
      'zh': '设备资料已保存到本机。',
      'ko': '기기 프로필이 로컬에 저장되었습니다.',
      'it': 'Profilo del dispositivo salvato localmente.',
      'hi': 'डिवाइस प्रोफ़ाइल स्थानीय रूप से सहेजी गई।',
    },
    'Return to Guest mode?': {
      'zh': '恢复为访客模式？',
      'ko': '게스트 모드로 돌아갈까요?',
      'it': 'Tornare alla modalità ospite?',
      'hi': 'अतिथि मोड में लौटें?',
    },
    'This signs out of the online account on this device. Guest mode will remain available and keeps separate local passport progress.': {
      'zh': '这将退出此设备上的在线账户。访客模式仍可使用，并会单独保留本地护照进度。',
      'ko':
          '이 기기의 온라인 계정에서 로그아웃합니다. 게스트 모드는 계속 사용할 수 있으며 별도의 로컬 패스포트 진행 상황을 유지합니다.',
      'it':
          'Questo disconnette l’account online sul dispositivo. La modalità ospite resterà disponibile con progressi locali separati.',
      'hi':
          'यह इस डिवाइस पर ऑनलाइन खाते से साइन आउट करेगा। अतिथि मोड उपलब्ध रहेगा और अलग स्थानीय पासपोर्ट प्रगति रखेगा।',
    },
    'Return to Guest': {
      'zh': '恢复为访客',
      'ko': '게스트로 돌아가기',
      'it': 'Torna come ospite',
      'hi': 'अतिथि मोड में लौटें',
    },
    'This device is now using the Guest profile.': {
      'zh': '此设备现已使用访客资料。',
      'ko': '이 기기는 이제 게스트 프로필을 사용합니다.',
      'it': 'Questo dispositivo ora usa il profilo ospite.',
      'hi': 'यह डिवाइस अब अतिथि प्रोफ़ाइल उपयोग कर रहा है।',
    },
    'Replay welcome setup?': {
      'zh': '重新进行欢迎设置？',
      'ko': '환영 설정을 다시 볼까요?',
      'it': 'Ripetere la configurazione iniziale?',
      'hi': 'स्वागत सेटअप फिर चलाएँ?',
    },
    'You can review your language, interests and newcomer profile. Your passport progress will not be changed.': {
      'zh': '您可以检查语言、兴趣和新居民资料。护照进度不会改变。',
      'ko': '언어, 관심사 및 새 주민 프로필을 검토할 수 있습니다. 패스포트 진행 상황은 변경되지 않습니다.',
      'it':
          'Puoi rivedere lingua, interessi e profilo di nuovo residente. I progressi del passaporto non cambieranno.',
      'hi':
          'आप अपनी भाषा, रुचियों और नवागंतुक प्रोफ़ाइल की समीक्षा कर सकते हैं। पासपोर्ट प्रगति नहीं बदलेगी।',
    },
    'Replay setup': {
      'zh': '重新设置',
      'ko': '설정 다시 보기',
      'it': 'Ripeti configurazione',
      'hi': 'सेटअप फिर चलाएँ',
    },
    'Enter an email identifier': {
      'zh': '请输入邮箱标识',
      'ko': '이메일 식별자를 입력하세요',
      'it': 'Inserisci un identificativo email',
      'hi': 'ईमेल पहचान दर्ज करें',
    },
    'Enter a valid email address': {
      'zh': '请输入有效电子邮箱',
      'ko': '유효한 이메일 주소를 입력하세요',
      'it': 'Inserisci un indirizzo email valido',
      'hi': 'मान्य ईमेल पता दर्ज करें',
    },
    'Already have an account? Sign in': {
      'zh': '已有账户？请登录',
      'ko': '이미 계정이 있나요? 로그인',
      'it': 'Hai già un account? Accedi',
      'hi': 'पहले से खाता है? साइन इन करें',
    },
    'New here? Create an account': {
      'zh': '初次使用？创建账户',
      'ko': '처음이신가요? 계정 만들기',
      'it': 'Sei nuovo? Crea un account',
      'hi': 'यहाँ नए हैं? खाता बनाएँ',
    },
    'Please wait…': {
      'zh': '请稍候…',
      'ko': '잠시만 기다려 주세요…',
      'it': 'Attendi…',
      'hi': 'कृपया प्रतीक्षा करें…',
    },
    'Create': {'zh': '创建', 'ko': '만들기', 'it': 'Crea', 'hi': 'बनाएँ'},
    'Edit display name': {
      'zh': '编辑显示名称',
      'ko': '표시 이름 편집',
      'it': 'Modifica nome visualizzato',
      'hi': 'प्रदर्शित नाम संपादित करें',
    },
    'Saved locally on this device': {
      'zh': '已保存在此设备上',
      'ko': '이 기기에 로컬 저장됨',
      'it': 'Salvato localmente sul dispositivo',
      'hi': 'इस डिवाइस पर स्थानीय रूप से सहेजा गया',
    },
    'Progress is stored on this device': {
      'zh': '进度存储在此设备上',
      'ko': '진행 상황이 이 기기에 저장됩니다',
      'it': 'I progressi sono salvati su questo dispositivo',
      'hi': 'प्रगति इस डिवाइस पर संग्रहीत है',
    },
    'DEVICE': {'zh': '设备', 'ko': '기기', 'it': 'DISPOSITIVO', 'hi': 'डिवाइस'},
    'GUEST': {'zh': '访客', 'ko': '게스트', 'it': 'OSPITE', 'hi': 'अतिथि'},
    'Language changes require app preferences to be connected.': {
      'zh': '更改语言需要连接应用偏好设置。',
      'ko': '언어를 변경하려면 앱 환경설정이 연결되어야 합니다.',
      'it':
          'Per cambiare lingua devono essere collegate le preferenze dell’app.',
      'hi': 'भाषा बदलने के लिए ऐप प्राथमिकताओं का जुड़ा होना आवश्यक है।',
    },
    'Light': {'zh': '浅色', 'ko': '라이트', 'it': 'Chiaro', 'hi': 'हल्का'},
    'Dark': {'zh': '深色', 'ko': '다크', 'it': 'Scuro', 'hi': 'गहरा'},
    'Auto': {'zh': '自动', 'ko': '자동', 'it': 'Auto', 'hi': 'स्वचालित'},
    'System': {'zh': '跟随系统', 'ko': '시스템', 'it': 'Sistema', 'hi': 'सिस्टम'},
    'English': {'zh': '英语', 'ko': '영어', 'it': 'Inglese', 'hi': 'अंग्रेज़ी'},
    'Simplified Chinese': {
      'zh': '简体中文',
      'ko': '중국어 간체',
      'it': 'Cinese semplificato',
      'hi': 'सरलीकृत चीनी',
    },
    'Korean': {'zh': '韩语', 'ko': '한국어', 'it': 'Coreano', 'hi': 'कोरियाई'},
    'Italian': {'zh': '意大利语', 'ko': '이탈리아어', 'it': 'Italiano', 'hi': 'इतालवी'},
    'Hindi': {'zh': '印地语', 'ko': '힌디어', 'it': 'Hindi', 'hi': 'हिन्दी'},
    'Not signed in': {
      'zh': '未登录',
      'ko': '로그인하지 않음',
      'it': 'Accesso non effettuato',
      'hi': 'साइन इन नहीं',
    },
    'Signed in': {
      'zh': '已登录',
      'ko': '로그인됨',
      'it': 'Accesso effettuato',
      'hi': 'साइन इन है',
    },
    'Sign-in failed. Check your details and try again.': {
      'zh': '登录失败。请检查信息后重试。',
      'ko': '로그인하지 못했습니다. 입력 정보를 확인하고 다시 시도하세요.',
      'it': 'Accesso non riuscito. Controlla i dati e riprova.',
      'hi': 'साइन इन नहीं हो सका। अपनी जानकारी जाँचकर फिर प्रयास करें।',
    },
    'The account service is unavailable right now. Please try again later.': {
      'zh': '账户服务目前不可用。请稍后重试。',
      'ko': '현재 계정 서비스를 이용할 수 없습니다. 나중에 다시 시도하세요.',
      'it': 'Il servizio account non è disponibile. Riprova più tardi.',
      'hi': 'खाता सेवा अभी उपलब्ध नहीं है। बाद में फिर प्रयास करें।',
    },
    'Location services are off. Turn them on to sort places near you.': {
      'zh': '定位服务已关闭。请开启定位以按附近地点排序。',
      'ko': '위치 서비스가 꺼져 있습니다. 주변 장소를 정렬하려면 켜 주세요.',
      'it':
          'I servizi di posizione sono disattivati. Attivali per ordinare i luoghi vicini.',
      'hi':
          'स्थान सेवाएँ बंद हैं। आस-पास के स्थान क्रमबद्ध करने के लिए इन्हें चालू करें।',
    },
    'Location access was not allowed. You can still browse every place.': {
      'zh': '未允许位置访问。您仍可浏览所有地点。',
      'ko': '위치 접근이 허용되지 않았습니다. 모든 장소는 계속 둘러볼 수 있습니다.',
      'it':
          'Accesso alla posizione non consentito. Puoi comunque esplorare tutti i luoghi.',
      'hi': 'स्थान की अनुमति नहीं मिली। आप फिर भी सभी स्थान देख सकते हैं।',
    },
    'Location is blocked for this app. Enable it in device settings to use nearby sorting.': {
      'zh': '此应用的位置权限已被阻止。请在设备设置中启用，以使用附近排序。',
      'ko': '이 앱의 위치 접근이 차단되었습니다. 주변 정렬을 사용하려면 기기 설정에서 허용하세요.',
      'it':
          'La posizione è bloccata per questa app. Abilitala nelle impostazioni per ordinare i luoghi vicini.',
      'hi':
          'इस ऐप के लिए स्थान अवरुद्ध है। पास के स्थान क्रमबद्ध करने हेतु डिवाइस सेटिंग में इसे सक्षम करें।',
    },
    'Walking': {'zh': '步行', 'ko': '걷기', 'it': 'A piedi', 'hi': 'पैदल'},
    'Cycling': {'zh': '骑行', 'ko': '자전거', 'it': 'Ciclismo', 'hi': 'साइकिलिंग'},
    'Running': {'zh': '跑步', 'ko': '달리기', 'it': 'Corsa', 'hi': 'दौड़'},
    'Moderate': {'zh': '中等', 'ko': '보통', 'it': 'Moderato', 'hi': 'मध्यम'},
    'Hard': {'zh': '困难', 'ko': '어려움', 'it': 'Difficile', 'hi': 'कठिन'},
    'Load route': {
      'zh': '加载路线',
      'ko': '경로 불러오기',
      'it': 'Carica percorso',
      'hi': 'मार्ग लोड करें',
    },
    'Unavailable': {
      'zh': '不可用',
      'ko': '사용할 수 없음',
      'it': 'Non disponibile',
      'hi': 'उपलब्ध नहीं',
    },
    'Bins go out tonight': {
      'zh': '今晚请将垃圾桶推出',
      'ko': '오늘 저녁 쓰레기통을 내놓으세요',
      'it': 'Stasera esponi i bidoni',
      'hi': 'आज रात कचरे के डिब्बे बाहर रखें',
    },
    'Your collection is tomorrow. Check which bins are due and put them out this evening.': {
      'zh': '明天收集垃圾桶。请确认需要推出哪些垃圾桶，并在今晚将其放出。',
      'ko': '내일 수거일입니다. 해당 쓰레기통을 확인하고 오늘 저녁 내놓으세요.',
      'it':
          'La raccolta è domani. Controlla quali bidoni sono previsti ed esponili stasera.',
      'hi':
          'संग्रह कल है। देखें कौन से डिब्बे रखने हैं और उन्हें आज शाम बाहर रखें।',
    },
    'Bin night reminders': {
      'zh': '垃圾桶之夜提醒',
      'ko': '쓰레기 수거 전날 알림',
      'it': 'Promemoria raccolta rifiuti',
      'hi': 'कचरा रात रिमाइंडर',
    },
    'Weekly reminders for household bin collection': {
      'zh': '每周家庭垃圾桶收集提醒',
      'ko': '가정 쓰레기 수거 주간 알림',
      'it': 'Promemoria settimanali per la raccolta domestica',
      'hi': 'घरेलू कचरा संग्रह के साप्ताहिक रिमाइंडर',
    },
    'Explore is not connected yet.': {
      'zh': '探索功能尚未连接。',
      'ko': '탐색 기능이 아직 연결되지 않았습니다.',
      'it': 'La funzione Esplora non è ancora collegata.',
      'hi': 'खोज सुविधा अभी जुड़ी नहीं है।',
    },
    'The scanner is not connected yet.': {
      'zh': '扫描器尚未连接。',
      'ko': '스캐너가 아직 연결되지 않았습니다.',
      'it': 'Lo scanner non è ancora collegato.',
      'hi': 'स्कैनर अभी जुड़ा नहीं है।',
    },
    'Community is not connected yet.': {
      'zh': '社区功能尚未连接。',
      'ko': '커뮤니티 기능이 아직 연결되지 않았습니다.',
      'it': 'La sezione Comunità non è ancora collegata.',
      'hi': 'समुदाय सुविधा अभी जुड़ी नहीं है।',
    },
    'Local Services is not connected yet.': {
      'zh': '本地服务尚未连接。',
      'ko': '지역 서비스가 아직 연결되지 않았습니다.',
      'it': 'I servizi locali non sono ancora collegati.',
      'hi': 'स्थानीय सेवाएँ अभी जुड़ी नहीं हैं।',
    },
    'This device could not open the link, so it was copied instead.': {
      'zh': '此设备无法打开链接，已将其复制。',
      'ko': '이 기기에서 링크를 열 수 없어 대신 복사했습니다.',
      'it': 'Il dispositivo non ha potuto aprire il link; è stato copiato.',
      'hi': 'यह डिवाइस लिंक नहीं खोल सका, इसलिए उसे कॉपी कर दिया गया है।',
    },
    'Places are now sorted by distance from you.': {
      'zh': '地点现已按与您的距离排序。',
      'ko': '장소가 현재 위치와의 거리순으로 정렬되었습니다.',
      'it': 'I luoghi sono ora ordinati per distanza.',
      'hi': 'स्थान अब आपसे दूरी के अनुसार क्रमबद्ध हैं।',
    },
    'Your location is unavailable right now. You can still browse every place.': {
      'zh': '目前无法获取您的位置。您仍可浏览所有地点。',
      'ko': '현재 위치를 사용할 수 없습니다. 모든 장소는 계속 둘러볼 수 있습니다.',
      'it':
          'La tua posizione non è disponibile. Puoi comunque esplorare tutti i luoghi.',
      'hi': 'आपका स्थान अभी उपलब्ध नहीं है। आप फिर भी सभी स्थान देख सकते हैं।',
    },
    'There are no other routes to show yet.': {
      'zh': '目前没有其他路线可显示。',
      'ko': '아직 표시할 다른 경로가 없습니다.',
      'it': 'Non ci sono ancora altri percorsi da mostrare.',
      'hi': 'अभी दिखाने के लिए कोई और मार्ग नहीं है।',
    },
    'Stamp updated': {
      'zh': '印章已更新',
      'ko': '스탬프 업데이트됨',
      'it': 'Timbro aggiornato',
      'hi': 'स्टाम्प अपडेट हुआ',
    },
    'Added to your saved routes': {
      'zh': '已添加到您保存的路线',
      'ko': '저장한 경로에 추가됨',
      'it': 'Aggiunto ai percorsi salvati',
      'hi': 'आपके सहेजे मार्गों में जोड़ा गया',
    },
    'Route sent to the Explore map': {
      'zh': '路线已发送到探索地图',
      'ko': '경로를 탐색 지도로 보냈습니다',
      'it': 'Percorso inviato alla mappa Esplora',
      'hi': 'मार्ग खोज नक्शे पर भेजा गया',
    },
    'YOUR NEXT STEP': {
      'zh': '您的下一步',
      'ko': '다음 단계',
      'it': 'IL TUO PROSSIMO PASSO',
      'hi': 'आपका अगला कदम',
    },
    'KEEP SETTLING IN': {
      'zh': '继续融入',
      'ko': '정착을 이어가세요',
      'it': 'CONTINUA AD AMBIENTARTI',
      'hi': 'बसते रहिए',
    },
    'MAKE IT YOURS': {
      'zh': '打造您的本地生活',
      'ko': '나만의 동네로',
      'it': 'RENDILO TUO',
      'hi': 'इसे अपना बनाएँ',
    },
    'READY TO EXPLORE': {
      'zh': '准备探索',
      'ko': '탐색할 준비 완료',
      'it': 'PRONTO A ESPLORARE',
      'hi': 'खोजने के लिए तैयार',
    },
    'Confirm your bin collection day': {
      'zh': '确认垃圾桶收集日',
      'ko': '쓰레기 수거일 확인',
      'it': 'Conferma il giorno di raccolta',
      'hi': 'कचरा संग्रह का दिन पक्का करें',
    },
    'Save it once and get an optional reminder the night before.': {
      'zh': '保存一次，并可选择在前一晚收到提醒。',
      'ko': '한 번 저장하고 전날 저녁 알림을 선택할 수 있습니다.',
      'it': 'Salvalo una volta e, se vuoi, ricevi un promemoria la sera prima.',
      'hi':
          'इसे एक बार सहेजें और चाहें तो पिछली शाम याद दिलाने वाला संदेश पाएँ।',
    },
    'Join your local library': {
      'zh': '加入本地图书馆',
      'ko': '지역 도서관 가입',
      'it': 'Iscriviti alla biblioteca locale',
      'hi': 'स्थानीय पुस्तकालय से जुड़ें',
    },
    'Find free services, then keep your card reference in Passport.': {
      'zh': '查找免费服务，并将借书卡信息保存在护照中。',
      'ko': '무료 서비스를 찾고 카드 정보를 패스포트에 보관하세요.',
      'it':
          'Scopri i servizi gratuiti e conserva il riferimento della tessera nel Passaporto.',
      'hi': 'मुफ़्त सेवाएँ खोजें, फिर कार्ड का संदर्भ पासपोर्ट में रखें।',
    },
    'Save your usual transport stop': {
      'zh': '保存您常用的交通站点',
      'ko': '자주 이용하는 교통 정류장 저장',
      'it': 'Salva la tua fermata abituale',
      'hi': 'अपना सामान्य परिवहन स्टॉप सहेजें',
    },
    'Keep a familiar station, wharf or bus stop in your Passport.': {
      'zh': '将常用车站、码头或公交站保存在护照中。',
      'ko': '익숙한 역, 선착장 또는 버스 정류장을 패스포트에 보관하세요.',
      'it':
          'Conserva nel Passaporto una stazione, un molo o una fermata familiare.',
      'hi': 'किसी परिचित स्टेशन, घाट या बस स्टॉप को पासपोर्ट में रखें।',
    },
    'PASSPORT · ROUTES · LOCAL CHECKPOINTS': {
      'zh': '护照 · 路线 · 本地打卡点',
      'ko': '패스포트 · 경로 · 지역 체크포인트',
      'it': 'PASSAPORTO · PERCORSI · TAPPE LOCALI',
      'hi': 'पासपोर्ट · मार्ग · स्थानीय चेकपॉइंट',
    },
    'Profile': {'zh': '个人资料', 'ko': '프로필', 'it': 'Profilo', 'hi': 'प्रोफ़ाइल'},
    'Find the services, community activities and local places that help Canada Bay feel like home.': {
      'zh': '查找帮助您在加拿大湾安家的服务、社区活动和本地点。',
      'ko': '캐나다 베이가 집처럼 느껴지도록 돕는 서비스, 커뮤니티 활동 및 지역 장소를 찾아보세요.',
      'it':
          'Trova servizi, attività di comunità e luoghi che fanno sentire Canada Bay come casa.',
      'hi':
          'वे सेवाएँ, सामुदायिक गतिविधियाँ और स्थानीय स्थान खोजें जो कनाडा बे को घर जैसा बनाएँ।',
    },
    'Explore Map': {
      'zh': '探索地图',
      'ko': '지도 탐색',
      'it': 'Esplora la mappa',
      'hi': 'नक्शा खोजें',
    },
    'Browse Routes': {
      'zh': '浏览路线',
      'ko': '경로 둘러보기',
      'it': 'Sfoglia i percorsi',
      'hi': 'मार्ग देखें',
    },
    'Start a discovery streak': {
      'zh': '开始连续探索',
      'ko': '연속 탐색 시작',
      'it': 'Inizia una serie di scoperte',
      'hi': 'खोज की लगातार शुरुआत करें',
    },
    'Your main tools in one place': {
      'zh': '主要工具尽在一处',
      'ko': '주요 도구를 한곳에서',
      'it': 'I tuoi strumenti principali in un solo posto',
      'hi': 'आपके मुख्य साधन एक ही जगह',
    },
    'Settle-in essentials': {
      'zh': '安居必备',
      'ko': '정착 필수 정보',
      'it': 'Essenziali per ambientarsi',
      'hi': 'बसने की ज़रूरी बातें',
    },
    'Trusted practical information from official sources': {
      'zh': '来自官方来源的可靠实用信息',
      'ko': '공식 출처의 신뢰할 수 있는 생활 정보',
      'it': 'Informazioni pratiche affidabili da fonti ufficiali',
      'hi': 'आधिकारिक स्रोतों से भरोसेमंद व्यावहारिक जानकारी',
    },
    'All services': {
      'zh': '所有服务',
      'ko': '모든 서비스',
      'it': 'Tutti i servizi',
      'hi': 'सभी सेवाएँ',
    },
    'Civic information is being prepared': {
      'zh': '市政信息正在准备中',
      'ko': '생활 행정 정보를 준비 중입니다',
      'it': 'Le informazioni civiche sono in preparazione',
      'hi': 'नागरिक जानकारी तैयार की जा रही है',
    },
    'Open Local Services to browse practical help.': {
      'zh': '打开本地服务以浏览实用帮助。',
      'ko': '지역 서비스를 열어 실용적인 도움말을 확인하세요.',
      'it': 'Apri Servizi locali per consultare l’aiuto pratico.',
      'hi': 'व्यावहारिक सहायता देखने के लिए स्थानीय सेवाएँ खोलें।',
    },
    'Open Services': {
      'zh': '打开服务',
      'ko': '서비스 열기',
      'it': 'Apri servizi',
      'hi': 'सेवाएँ खोलें',
    },
    'Show another route': {
      'zh': '显示另一条路线',
      'ko': '다른 경로 보기',
      'it': 'Mostra un altro percorso',
      'hi': 'दूसरा मार्ग दिखाएँ',
    },
    'No route loaded': {
      'zh': '未加载路线',
      'ko': '불러온 경로 없음',
      'it': 'Nessun percorso caricato',
      'hi': 'कोई मार्ग लोड नहीं हुआ',
    },
    'Check routes.json and pubspec.yaml.': {
      'zh': '请检查 routes.json 和 pubspec.yaml。',
      'ko': 'routes.json과 pubspec.yaml을 확인하세요.',
      'it': 'Controlla routes.json e pubspec.yaml.',
      'hi': 'routes.json और pubspec.yaml जाँचें।',
    },
    'Open Map': {
      'zh': '打开地图',
      'ko': '지도 열기',
      'it': 'Apri mappa',
      'hi': 'नक्शा खोलें',
    },
    'Local Route': {
      'zh': '本地路线',
      'ko': '지역 경로',
      'it': 'Percorso locale',
      'hi': 'स्थानीय मार्ग',
    },
    'Route': {'zh': '路线', 'ko': '경로', 'it': 'Percorso', 'hi': 'मार्ग'},
    'Easy': {'zh': '简单', 'ko': '쉬움', 'it': 'Facile', 'hi': 'आसान'},
    'A local walk with plenty to discover along the way.': {
      'zh': '一条沿途有许多发现的本地步行路线。',
      'ko': '길을 따라 다양한 발견을 즐기는 지역 산책로입니다.',
      'it': 'Una passeggiata locale ricca di scoperte.',
      'hi': 'रास्ते में बहुत कुछ खोजने वाली स्थानीय सैर।',
    },
    'Unsave route': {
      'zh': '取消保存路线',
      'ko': '경로 저장 취소',
      'it': 'Rimuovi percorso salvato',
      'hi': 'मार्ग सहेजना हटाएँ',
    },
    'Save route': {
      'zh': '保存路线',
      'ko': '경로 저장',
      'it': 'Salva percorso',
      'hi': 'मार्ग सहेजें',
    },
    'SUGGESTED FOR YOU': {
      'zh': '为您推荐',
      'ko': '추천 경로',
      'it': 'CONSIGLIATO PER TE',
      'hi': 'आपके लिए सुझाया गया',
    },
    'Start Route': {
      'zh': '开始路线',
      'ko': '경로 시작',
      'it': 'Inizia percorso',
      'hi': 'मार्ग शुरू करें',
    },
    'Saved': {'zh': '已保存', 'ko': '저장됨', 'it': 'Salvato', 'hi': 'सहेजा गया'},
    'Your Progress': {
      'zh': '您的进度',
      'ko': '내 진행 상황',
      'it': 'I tuoi progressi',
      'hi': 'आपकी प्रगति',
    },
    'XP, scans and passport badges': {
      'zh': '经验值、扫描和护照徽章',
      'ko': 'XP, 스캔 및 패스포트 배지',
      'it': 'XP, scansioni e badge del passaporto',
      'hi': 'XP, स्कैन और पासपोर्ट बैज',
    },
    'XP today': {
      'zh': '今日经验值',
      'ko': '오늘의 XP',
      'it': 'XP di oggi',
      'hi': 'आज का XP',
    },
    'day streak': {
      'zh': '连续天数',
      'ko': '연속 일수',
      'it': 'giorni consecutivi',
      'hi': 'लगातार दिन',
    },
    'Passport progress': {
      'zh': '护照进度',
      'ko': '패스포트 진행 상황',
      'it': 'Progresso del passaporto',
      'hi': 'पासपोर्ट प्रगति',
    },
    'Your badge collection is getting ready.': {
      'zh': '您的徽章收藏正在准备中。',
      'ko': '배지 컬렉션을 준비 중입니다.',
      'it': 'La tua collezione di badge è in preparazione.',
      'hi': 'आपका बैज संग्रह तैयार हो रहा है।',
    },
    'Every passport badge has been earned!': {
      'zh': '所有护照徽章均已获得！',
      'ko': '모든 패스포트 배지를 획득했습니다!',
      'it': 'Hai ottenuto tutti i badge del passaporto!',
      'hi': 'सभी पासपोर्ट बैज अर्जित हो गए हैं!',
    },
    'Around You': {
      'zh': '您附近',
      'ko': '내 주변',
      'it': 'Vicino a te',
      'hi': 'आपके आसपास',
    },
    'Popular places across Canada Bay': {
      'zh': '加拿大湾热门地点',
      'ko': '캐나다 베이의 인기 장소',
      'it': 'Luoghi popolari di Canada Bay',
      'hi': 'कनाडा बे के लोकप्रिय स्थान',
    },
    'Sorted using your current location': {
      'zh': '已按您的当前位置排序',
      'ko': '현재 위치를 기준으로 정렬됨',
      'it': 'Ordinati usando la tua posizione attuale',
      'hi': 'आपके वर्तमान स्थान से क्रमबद्ध',
    },
    'Near me': {
      'zh': '我附近',
      'ko': '내 주변',
      'it': 'Vicino a me',
      'hi': 'मेरे पास',
    },
    'Refresh': {
      'zh': '刷新',
      'ko': '새로고침',
      'it': 'Aggiorna',
      'hi': 'रीफ़्रेश करें',
    },
    'No checkpoints loaded': {
      'zh': '未加载打卡点',
      'ko': '불러온 체크포인트 없음',
      'it': 'Nessuna tappa caricata',
      'hi': 'कोई चेकपॉइंट लोड नहीं हुआ',
    },
    'Check locations.json and pubspec.yaml.': {
      'zh': '请检查 locations.json 和 pubspec.yaml。',
      'ko': 'locations.json과 pubspec.yaml을 확인하세요.',
      'it': 'Controlla locations.json e pubspec.yaml.',
      'hi': 'locations.json और pubspec.yaml जाँचें।',
    },
    'Featured community activity': {
      'zh': '精选社区活动',
      'ko': '추천 커뮤니티 활동',
      'it': 'Attività di comunità in evidenza',
      'hi': 'विशेष सामुदायिक गतिविधि',
    },
    'A welcoming way to meet your neighbourhood': {
      'zh': '以友好方式认识您的社区',
      'ko': '이웃을 만나는 따뜻한 방법',
      'it': 'Un modo accogliente per conoscere il quartiere',
      'hi': 'अपने पड़ोस से मिलने का स्वागतपूर्ण तरीका',
    },
    'Community activities are being prepared': {
      'zh': '社区活动正在准备中',
      'ko': '커뮤니티 활동을 준비 중입니다',
      'it': 'Le attività di comunità sono in preparazione',
      'hi': 'सामुदायिक गतिविधियाँ तैयार की जा रही हैं',
    },
    'Open Community to browse the complete local guide.': {
      'zh': '打开社区以浏览完整本地指南。',
      'ko': '커뮤니티를 열어 전체 지역 가이드를 확인하세요.',
      'it': 'Apri Comunità per consultare la guida locale completa.',
      'hi': 'पूरी स्थानीय मार्गदर्शिका देखने के लिए समुदाय खोलें।',
    },
    'Open Community': {
      'zh': '打开社区',
      'ko': '커뮤니티 열기',
      'it': 'Apri Comunità',
      'hi': 'समुदाय खोलें',
    },
    'Explore Community': {
      'zh': '探索社区',
      'ko': '커뮤니티 탐색',
      'it': 'Esplora la comunità',
      'hi': 'समुदाय खोजें',
    },
    'Environmental discovery': {
      'zh': '环境探索',
      'ko': '환경 발견',
      'it': 'Scoperta ambientale',
      'hi': 'पर्यावरण खोज',
    },
    'Learn about the living places around you': {
      'zh': '了解您身边充满生命的地方',
      'ko': '주변의 살아 있는 장소를 알아보세요',
      'it': 'Scopri gli ambienti vivi intorno a te',
      'hi': 'अपने आसपास के जीवंत स्थानों के बारे में जानें',
    },
    'Environmental stories are being prepared': {
      'zh': '环境故事正在准备中',
      'ko': '환경 이야기를 준비 중입니다',
      'it': 'Le storie ambientali sono in preparazione',
      'hi': 'पर्यावरण कहानियाँ तैयार की जा रही हैं',
    },
    'Try again when local content is available.': {
      'zh': '本地内容可用时请重试。',
      'ko': '지역 콘텐츠가 제공되면 다시 시도하세요.',
      'it': 'Riprova quando saranno disponibili i contenuti locali.',
      'hi': 'स्थानीय सामग्री उपलब्ध होने पर फिर प्रयास करें।',
    },
    'Find on map': {
      'zh': '在地图上查找',
      'ko': '지도에서 찾기',
      'it': 'Trova sulla mappa',
      'hi': 'नक्शे पर खोजें',
    },
    'Recent Activity': {
      'zh': '最近活动',
      'ko': '최근 활동',
      'it': 'Attività recente',
      'hi': 'हाल की गतिविधि',
    },
    'Your latest discoveries': {
      'zh': '您的最新发现',
      'ko': '최근 발견',
      'it': 'Le tue ultime scoperte',
      'hi': 'आपकी नवीनतम खोजें',
    },
    'Scan a checkpoint or save a route to begin your activity feed.': {
      'zh': '扫描打卡点或保存路线以开始活动记录。',
      'ko': '체크포인트를 스캔하거나 경로를 저장해 활동 피드를 시작하세요.',
      'it':
          'Scansiona una tappa o salva un percorso per iniziare il registro attività.',
      'hi':
          'गतिविधि फ़ीड शुरू करने के लिए चेकपॉइंट स्कैन करें या मार्ग सहेजें।',
    },
    'Digital Passport': {
      'zh': '数字护照',
      'ko': '디지털 패스포트',
      'it': 'Passaporto digitale',
      'hi': 'डिजिटल पासपोर्ट',
    },
    'Scan real places to earn XP and complete badge collections.': {
      'zh': '扫描真实地点以获得经验值并完成徽章收藏。',
      'ko': '실제 장소를 스캔해 XP를 얻고 배지 컬렉션을 완성하세요.',
      'it':
          'Scansiona luoghi reali per ottenere XP e completare le collezioni di badge.',
      'hi': 'XP पाने और बैज संग्रह पूरा करने के लिए वास्तविक स्थान स्कैन करें।',
    },
    'No badges yet. Scan a passport QR code to start your first collection.': {
      'zh': '尚未获得徽章。扫描护照二维码以开始首个收藏。',
      'ko': '아직 배지가 없습니다. 패스포트 QR 코드를 스캔해 첫 컬렉션을 시작하세요.',
      'it':
          'Nessun badge. Scansiona un QR del passaporto per iniziare la prima collezione.',
      'hi':
          'अभी कोई बैज नहीं। पहला संग्रह शुरू करने के लिए पासपोर्ट QR कोड स्कैन करें।',
    },
    'Open full passport': {
      'zh': '打开完整护照',
      'ko': '전체 패스포트 열기',
      'it': 'Apri il passaporto completo',
      'hi': 'पूरा पासपोर्ट खोलें',
    },
    'MAP COORDINATES': {
      'zh': '地图坐标',
      'ko': '지도 좌표',
      'it': 'COORDINATE MAPPA',
      'hi': 'नक्शा निर्देशांक',
    },
    'Explore map': {
      'zh': '探索地图',
      'ko': '지도 탐색',
      'it': 'Esplora la mappa',
      'hi': 'नक्शा खोजें',
    },
    'View in Passport': {
      'zh': '在护照中查看',
      'ko': '패스포트에서 보기',
      'it': 'Visualizza nel Passaporto',
      'hi': 'पासपोर्ट में देखें',
    },
    'Scan this place': {
      'zh': '扫描此地点',
      'ko': '이 장소 스캔',
      'it': 'Scansiona questo luogo',
      'hi': 'इस स्थान को स्कैन करें',
    },
    'Food & cafés': {
      'zh': '美食与咖啡馆',
      'ko': '음식 및 카페',
      'it': 'Cibo e caffè',
      'hi': 'भोजन और कैफ़े',
    },
    'Park': {'zh': '公园', 'ko': '공원', 'it': 'Parco', 'hi': 'पार्क'},
    'Outdoor gym': {
      'zh': '户外健身房',
      'ko': '야외 운동 시설',
      'it': 'Palestra all’aperto',
      'hi': 'आउटडोर जिम',
    },
    'Library': {
      'zh': '图书馆',
      'ko': '도서관',
      'it': 'Biblioteca',
      'hi': 'पुस्तकालय',
    },
    'Public toilet': {
      'zh': '公共卫生间',
      'ko': '공중 화장실',
      'it': 'Bagno pubblico',
      'hi': 'सार्वजनिक शौचालय',
    },
    'Local business': {
      'zh': '本地商家',
      'ko': '지역 사업체',
      'it': 'Attività locale',
      'hi': 'स्थानीय व्यवसाय',
    },
    'Attraction': {'zh': '景点', 'ko': '명소', 'it': 'Attrazione', 'hi': 'आकर्षण'},
    'Biodiversity': {
      'zh': '生物多样性',
      'ko': '생물 다양성',
      'it': 'Biodiversità',
      'hi': 'जैव विविधता',
    },
    'Checkpoint': {'zh': '打卡点', 'ko': '체크포인트', 'it': 'Tappa', 'hi': 'चेकपॉइंट'},
    'Finding local adventures…': {
      'zh': '正在寻找本地探索…',
      'ko': '지역 모험을 찾는 중…',
      'it': 'Ricerca di avventure locali…',
      'hi': 'स्थानीय रोमांच खोजे जा रहे हैं…',
    },
    'Stamp collected': {
      'zh': '印章已收集',
      'ko': '스탬프 수집됨',
      'it': 'Timbro raccolto',
      'hi': 'स्टाम्प मिला',
    },
    'How your passport works': {
      'zh': '护照使用方式',
      'ko': '패스포트 이용 방법',
      'it': 'Come funziona il passaporto',
      'hi': 'आपका पासपोर्ट कैसे काम करता है',
    },
    'Find a passport QR code': {
      'zh': '查找护照二维码',
      'ko': '패스포트 QR 코드 찾기',
      'it': 'Trova un QR del passaporto',
      'hi': 'पासपोर्ट QR कोड खोजें',
    },
    'Look for Explore Canada Bay signs at participating places and trails.': {
      'zh': '在参与地点和步道寻找 Explore Canada Bay 标牌。',
      'ko': '참여 장소와 산책로에서 Explore Canada Bay 표지판을 찾아보세요.',
      'it':
          'Cerca i cartelli Explore Canada Bay nei luoghi e percorsi aderenti.',
      'hi':
          'भाग लेने वाले स्थानों और पगडंडियों पर Explore Canada Bay संकेत खोजें।',
    },
    'Scan once at each discovery': {
      'zh': '每个发现扫描一次',
      'ko': '각 발견 장소에서 한 번 스캔',
      'it': 'Scansiona una volta per ogni scoperta',
      'hi': 'हर खोज पर एक बार स्कैन करें',
    },
    'Every code has a unique reward ID, so the same reward cannot be claimed twice.': {
      'zh': '每个代码都有唯一奖励编号，因此同一奖励无法重复领取。',
      'ko': '각 코드에는 고유 보상 ID가 있어 같은 보상을 두 번 받을 수 없습니다.',
      'it':
          'Ogni codice ha un ID premio unico, quindi lo stesso premio non può essere riscattato due volte.',
      'hi':
          'हर कोड की अलग पुरस्कार ID होती है, इसलिए एक पुरस्कार दो बार नहीं लिया जा सकता।',
    },
    'Grow your collection': {
      'zh': '扩充您的收藏',
      'ko': '컬렉션 늘리기',
      'it': 'Fai crescere la collezione',
      'hi': 'अपना संग्रह बढ़ाएँ',
    },
    'A scan can award XP, add progress to a badge, or unlock a special badge immediately.': {
      'zh': '扫描可获得经验值、增加徽章进度或立即解锁特殊徽章。',
      'ko': '스캔하면 XP를 받거나 배지 진행 상황이 올라가며 특별 배지를 즉시 해제할 수도 있습니다.',
      'it':
          'Una scansione può assegnare XP, far avanzare un badge o sbloccare subito un badge speciale.',
      'hi':
          'स्कैन से XP मिल सकता है, बैज की प्रगति बढ़ सकती है या विशेष बैज तुरंत खुल सकता है।',
    },
    'My local essentials': {
      'zh': '我的本地必备信息',
      'ko': '내 지역 필수 정보',
      'it': 'I miei dati locali essenziali',
      'hi': 'मेरी स्थानीय ज़रूरी जानकारी',
    },
    'Useful details kept with your Community Passport': {
      'zh': '与社区护照一起保存的实用信息',
      'ko': '커뮤니티 패스포트에 보관되는 유용한 정보',
      'it': 'Informazioni utili conservate nel Passaporto della comunità',
      'hi': 'समुदाय पासपोर्ट में रखी उपयोगी जानकारी',
    },
    'Library card': {
      'zh': '借书卡',
      'ko': '도서관 카드',
      'it': 'Tessera della biblioteca',
      'hi': 'पुस्तकालय कार्ड',
    },
    'Not added yet': {
      'zh': '尚未添加',
      'ko': '아직 추가되지 않음',
      'it': 'Non ancora aggiunto',
      'hi': 'अभी नहीं जोड़ा गया',
    },
    'Card reference saved on this device': {
      'zh': '借书卡信息已保存在此设备上',
      'ko': '카드 정보가 이 기기에 저장됨',
      'it': 'Riferimento della tessera salvato sul dispositivo',
      'hi': 'कार्ड संदर्भ इस डिवाइस पर सहेजा गया',
    },
    'Join and keep a card reference here': {
      'zh': '加入图书馆并在此保存借书卡信息',
      'ko': '가입 후 카드 정보를 여기에 보관하세요',
      'it': 'Iscriviti e conserva qui il riferimento della tessera',
      'hi': 'जुड़ें और कार्ड का संदर्भ यहाँ रखें',
    },
    'Bin collection': {
      'zh': '垃圾桶收集',
      'ko': '쓰레기 수거',
      'it': 'Raccolta rifiuti',
      'hi': 'कचरा संग्रह',
    },
    'Not confirmed yet': {
      'zh': '尚未确认',
      'ko': '아직 확인되지 않음',
      'it': 'Non ancora confermato',
      'hi': 'अभी पक्का नहीं',
    },
    'Reminder on the evening before': {
      'zh': '前一晚提醒',
      'ko': '전날 저녁 알림',
      'it': 'Promemoria la sera prima',
      'hi': 'पिछली शाम याद दिलाना',
    },
    'Reminder is off': {
      'zh': '提醒已关闭',
      'ko': '알림 꺼짐',
      'it': 'Promemoria disattivato',
      'hi': 'रिमाइंडर बंद है',
    },
    'Usual stop': {
      'zh': '常用站点',
      'ko': '자주 이용하는 정류장',
      'it': 'Fermata abituale',
      'hi': 'सामान्य स्टॉप',
    },
    'Save a familiar starting point': {
      'zh': '保存熟悉的出发点',
      'ko': '익숙한 출발 지점을 저장하세요',
      'it': 'Salva un punto di partenza familiare',
      'hi': 'परिचित शुरुआती स्थान सहेजें',
    },
    'Council report': {
      'zh': '市政问题报告',
      'ko': '시의회 신고',
      'it': 'Segnalazione al Comune',
      'hi': 'काउंसिल रिपोर्ट',
    },
    'No report saved': {
      'zh': '未保存报告',
      'ko': '저장된 신고 없음',
      'it': 'Nessuna segnalazione salvata',
      'hi': 'कोई रिपोर्ट सहेजी नहीं गई',
    },
    'Keep a reference handy': {
      'zh': '妥善保存参考编号',
      'ko': '참조 번호를 가까이 보관하세요',
      'it': 'Tieni a portata di mano il riferimento',
      'hi': 'संदर्भ पास रखें',
    },
    'Pet guide': {
      'zh': '宠物指南',
      'ko': '반려동물 가이드',
      'it': 'Guida per animali',
      'hi': 'पालतू मार्गदर्शिका',
    },
    'No pet added': {
      'zh': '未添加宠物',
      'ko': '추가된 반려동물 없음',
      'it': 'Nessun animale aggiunto',
      'hi': 'कोई पालतू नहीं जोड़ा गया',
    },
    'Local off-leash guidance ready': {
      'zh': '本地免牵绳指南已准备就绪',
      'ko': '지역 목줄 해제 구역 안내 준비됨',
      'it': 'Guida locale alle aree senza guinzaglio pronta',
      'hi': 'स्थानीय बिना पट्टे की मार्गदर्शिका तैयार',
    },
    'Explore pet-friendly local places': {
      'zh': '探索宠物友好本地点',
      'ko': '반려동물 친화적인 지역 장소 탐색',
      'it': 'Esplora luoghi locali adatti agli animali',
      'hi': 'पालतू-अनुकूल स्थानीय स्थान खोजें',
    },
    'My local wallet': {
      'zh': '我的本地钱包',
      'ko': '내 지역 지갑',
      'it': 'Il mio portafoglio locale',
      'hi': 'मेरा स्थानीय वॉलेट',
    },
    'Manage essentials': {
      'zh': '管理必备信息',
      'ko': '필수 정보 관리',
      'it': 'Gestisci dati essenziali',
      'hi': 'ज़रूरी जानकारी प्रबंधित करें',
    },
    'Profile and preferences': {
      'zh': '个人资料和偏好设置',
      'ko': '프로필 및 환경설정',
      'it': 'Profilo e preferenze',
      'hi': 'प्रोफ़ाइल और प्राथमिकताएँ',
    },
    'How it works': {
      'zh': '使用方式',
      'ko': '이용 방법',
      'it': 'Come funziona',
      'hi': 'यह कैसे काम करता है',
    },
    'DISCOVER · SCAN · COLLECT': {
      'zh': '发现 · 扫描 · 收集',
      'ko': '발견 · 스캔 · 수집',
      'it': 'SCOPRI · SCANSIONA · RACCOGLI',
      'hi': 'खोजें · स्कैन करें · संग्रह करें',
    },
    'LOCAL EXPLORER': {
      'zh': '本地探索者',
      'ko': '지역 탐험가',
      'it': 'ESPLORATORE LOCALE',
      'hi': 'स्थानीय खोजकर्ता',
    },
    'GUEST PASSPORT': {
      'zh': '访客护照',
      'ko': '게스트 패스포트',
      'it': 'PASSAPORTO OSPITE',
      'hi': 'अतिथि पासपोर्ट',
    },
    'Your Canada Bay story starts with one local discovery.': {
      'zh': '您的加拿大湾故事从一次本地发现开始。',
      'ko': '캐나다 베이 이야기는 한 번의 지역 발견에서 시작됩니다.',
      'it': 'La tua storia a Canada Bay inizia con una scoperta locale.',
      'hi': 'आपकी कनाडा बे कहानी एक स्थानीय खोज से शुरू होती है।',
    },
    'Every place you explore adds another page to your story.': {
      'zh': '每探索一个地方，您的故事就会增添新的一页。',
      'ko': '탐험하는 모든 장소가 이야기에 새 페이지를 더합니다.',
      'it': 'Ogni luogo esplorato aggiunge una pagina alla tua storia.',
      'hi': 'आपका खोजा हर स्थान आपकी कहानी में एक नया पन्ना जोड़ता है।',
    },
    'CANADA BAY EXPLORER': {
      'zh': '加拿大湾探索者',
      'ko': '캐나다 베이 탐험가',
      'it': 'ESPLORATORE DI CANADA BAY',
      'hi': 'कनाडा बे खोजकर्ता',
    },
    'LOCAL PROFILE': {
      'zh': '本地资料',
      'ko': '로컬 프로필',
      'it': 'PROFILO LOCALE',
      'hi': 'स्थानीय प्रोफ़ाइल',
    },
    'EXPLORATION POINTS': {
      'zh': '探索积分',
      'ko': '탐험 포인트',
      'it': 'PUNTI ESPLORAZIONE',
      'hi': 'खोज अंक',
    },
    'Stamps': {'zh': '印章', 'ko': '스탬프', 'it': 'Timbri', 'hi': 'स्टाम्प'},
    'Scans': {'zh': '扫描', 'ko': '스캔', 'it': 'Scansioni', 'hi': 'स्कैन'},
    'Today': {'zh': '今天', 'ko': '오늘', 'it': 'Oggi', 'hi': 'आज'},
    'Continue your newcomer journey': {
      'zh': '继续您的新居民旅程',
      'ko': '새 주민 여정 계속하기',
      'it': 'Continua il percorso da nuovo residente',
      'hi': 'अपनी नवागंतुक यात्रा जारी रखें',
    },
    'Make your first discovery': {
      'zh': '进行第一次发现',
      'ko': '첫 발견 시작하기',
      'it': 'Fai la prima scoperta',
      'hi': 'अपनी पहली खोज करें',
    },
    'Scan another discovery': {
      'zh': '扫描另一个发现',
      'ko': '다른 발견 스캔',
      'it': 'Scansiona un’altra scoperta',
      'hi': 'एक और खोज स्कैन करें',
    },
    'Your passport shelf': {
      'zh': '您的护照展示架',
      'ko': '내 패스포트 선반',
      'it': 'La tua bacheca del passaporto',
      'hi': 'आपकी पासपोर्ट शेल्फ',
    },
    'Collect a first stamp and begin your story': {
      'zh': '收集第一枚印章，开始您的故事',
      'ko': '첫 스탬프를 모아 이야기를 시작하세요',
      'it': 'Raccogli il primo timbro e inizia la tua storia',
      'hi': 'पहला स्टाम्प लेकर अपनी कहानी शुरू करें',
    },
    'The achievements you are proud to display': {
      'zh': '您引以为豪并愿意展示的成就',
      'ko': '자랑스럽게 전시할 업적',
      'it': 'I traguardi che vuoi mostrare con orgoglio',
      'hi': 'वे उपलब्धियाँ जिन्हें दिखाने पर आपको गर्व है',
    },
    'Empty': {'zh': '空', 'ko': '비어 있음', 'it': 'Vuoto', 'hi': 'खाली'},
    'A blank page, ready for you': {
      'zh': '空白一页，等待您的发现',
      'ko': '당신을 기다리는 빈 페이지',
      'it': 'Una pagina vuota, pronta per te',
      'hi': 'एक खाली पन्ना, आपके लिए तैयार',
    },
    'Visit a participating place and scan its passport sign.': {
      'zh': '前往参与地点并扫描其护照标牌。',
      'ko': '참여 장소를 방문해 패스포트 표지판을 스캔하세요.',
      'it': 'Visita un luogo aderente e scansiona il cartello del passaporto.',
      'hi': 'भाग लेने वाले स्थान पर जाएँ और उसका पासपोर्ट संकेत स्कैन करें।',
    },
    'Find my first stamp': {
      'zh': '寻找我的第一枚印章',
      'ko': '첫 스탬프 찾기',
      'it': 'Trova il mio primo timbro',
      'hi': 'मेरा पहला स्टाम्प खोजें',
    },
    'Remove one displayed trophy before adding another.': {
      'zh': '请先移除一个展示中的奖杯，再添加另一个。',
      'ko': '다른 트로피를 추가하기 전에 전시 중인 트로피 하나를 제거하세요.',
      'it': 'Rimuovi un trofeo esposto prima di aggiungerne un altro.',
      'hi': 'दूसरी ट्रॉफ़ी जोड़ने से पहले दिखाई गई एक ट्रॉफ़ी हटाएँ।',
    },
    'Choose one displayed trophy to remove before adding another.': {
      'zh': '添加另一个奖杯前，请选择移除一个展示中的奖杯。',
      'ko': '다른 트로피를 추가하기 전에 제거할 전시 트로피를 선택하세요.',
      'it':
          'Scegli un trofeo esposto da rimuovere prima di aggiungerne un altro.',
      'hi': 'दूसरी जोड़ने से पहले हटाने के लिए एक दिखाई गई ट्रॉफ़ी चुनें।',
    },
    'Badge earned': {
      'zh': '已获得徽章',
      'ko': '배지 획득',
      'it': 'Badge ottenuto',
      'hi': 'बैज अर्जित',
    },
    'Remove from display': {
      'zh': '从展示中移除',
      'ko': '전시에서 제거',
      'it': 'Rimuovi dalla vetrina',
      'hi': 'प्रदर्शन से हटाएँ',
    },
    'Display this trophy': {
      'zh': '展示此奖杯',
      'ko': '이 트로피 전시',
      'it': 'Esponi questo trofeo',
      'hi': 'यह ट्रॉफ़ी दिखाएँ',
    },
    'Earn this trophy to display it': {
      'zh': '获得此奖杯后即可展示',
      'ko': '이 트로피를 획득하면 전시할 수 있습니다',
      'it': 'Ottieni questo trofeo per esporlo',
      'hi': 'इसे दिखाने के लिए यह ट्रॉफ़ी अर्जित करें',
    },
    'Your first discovery is waiting. Scan a Canada Bay passport QR code to begin.': {
      'zh': '您的第一次发现正在等待。扫描加拿大湾护照二维码即可开始。',
      'ko': '첫 발견이 기다리고 있습니다. 캐나다 베이 패스포트 QR 코드를 스캔해 시작하세요.',
      'it':
          'La prima scoperta ti aspetta. Scansiona un QR del passaporto di Canada Bay per iniziare.',
      'hi':
          'आपकी पहली खोज इंतज़ार कर रही है। शुरू करने के लिए कनाडा बे पासपोर्ट QR कोड स्कैन करें।',
    },
    'Read unlocked information': {
      'zh': '阅读已解锁信息',
      'ko': '해제된 정보 읽기',
      'it': 'Leggi le informazioni sbloccate',
      'hi': 'खुली जानकारी पढ़ें',
    },
    'STORY': {'zh': '故事', 'ko': '이야기', 'it': 'STORIA', 'hi': 'कहानी'},
    'STAMP': {'zh': '印章', 'ko': '스탬프', 'it': 'TIMBRO', 'hi': 'स्टाम्प'},
    'Enter a reward code': {
      'zh': '输入奖励代码',
      'ko': '보상 코드 입력',
      'it': 'Inserisci un codice premio',
      'hi': 'पुरस्कार कोड दर्ज करें',
    },
    'Paste the text stored inside a passport QR code. This is useful on a simulator or desktop.': {
      'zh': '粘贴护照二维码中存储的文本。这在模拟器或电脑上非常实用。',
      'ko': '패스포트 QR 코드에 저장된 텍스트를 붙여 넣으세요. 시뮬레이터나 데스크톱에서 유용합니다.',
      'it':
          'Incolla il testo contenuto nel QR del passaporto. È utile su simulatore o desktop.',
      'hi':
          'पासपोर्ट QR कोड में संग्रहीत टेक्स्ट चिपकाएँ। यह सिम्युलेटर या डेस्कटॉप पर उपयोगी है।',
    },
    'Use demo reward': {
      'zh': '使用演示奖励',
      'ko': '데모 보상 사용',
      'it': 'Usa premio demo',
      'hi': 'डेमो पुरस्कार उपयोग करें',
    },
    'Unlock all badges': {
      'zh': '解锁所有徽章',
      'ko': '모든 배지 해제',
      'it': 'Sblocca tutti i badge',
      'hi': 'सभी बैज खोलें',
    },
    'Claim reward': {
      'zh': '领取奖励',
      'ko': '보상 받기',
      'it': 'Riscatta premio',
      'hi': 'पुरस्कार लें',
    },
    'Already collected': {
      'zh': '已收集',
      'ko': '이미 수집됨',
      'it': 'Già raccolto',
      'hi': 'पहले ही संग्रहित',
    },
    'Badge unlocked!': {
      'zh': '徽章已解锁！',
      'ko': '배지 해제!',
      'it': 'Badge sbloccato!',
      'hi': 'बैज खुल गया!',
    },
    'Discovery collected!': {
      'zh': '发现已收集！',
      'ko': '발견 수집 완료!',
      'it': 'Scoperta raccolta!',
      'hi': 'खोज संग्रहित!',
    },
    'View passport': {
      'zh': '查看护照',
      'ko': '패스포트 보기',
      'it': 'Visualizza passaporto',
      'hi': 'पासपोर्ट देखें',
    },
    'Not a passport code': {
      'zh': '这不是护照代码',
      'ko': '패스포트 코드가 아닙니다',
      'it': 'Non è un codice del passaporto',
      'hi': 'यह पासपोर्ट कोड नहीं है',
    },
    'Camera access is unavailable on this device.': {
      'zh': '此设备无法使用相机。',
      'ko': '이 기기에서 카메라를 사용할 수 없습니다.',
      'it': 'La fotocamera non è disponibile su questo dispositivo.',
      'hi': 'इस डिवाइस पर कैमरा उपलब्ध नहीं है।',
    },
    'Checking reward…': {
      'zh': '正在检查奖励…',
      'ko': '보상 확인 중…',
      'it': 'Verifica del premio…',
      'hi': 'पुरस्कार जाँचा जा रहा है…',
    },
    'Hold the passport QR code inside the frame': {
      'zh': '将护照二维码保持在框内',
      'ko': '패스포트 QR 코드를 프레임 안에 맞추세요',
      'it': 'Mantieni il QR del passaporto dentro il riquadro',
      'hi': 'पासपोर्ट QR कोड को फ़्रेम के भीतर रखें',
    },
    'Turn real places into passport rewards': {
      'zh': '将真实地点变成护照奖励',
      'ko': '실제 장소를 패스포트 보상으로',
      'it': 'Trasforma luoghi reali in premi del passaporto',
      'hi': 'वास्तविक स्थानों को पासपोर्ट पुरस्कारों में बदलें',
    },
    'Scan official signs at parks, environmental sites, heritage places, libraries, council facilities and community events.': {
      'zh': '扫描公园、环境地点、历史遗址、图书馆、市政设施和社区活动中的官方标牌。',
      'ko': '공원, 환경 명소, 문화유산 장소, 도서관, 시의회 시설 및 커뮤니티 행사에서 공식 표지판을 스캔하세요.',
      'it':
          'Scansiona i cartelli ufficiali in parchi, siti ambientali, luoghi storici, biblioteche, strutture comunali ed eventi.',
      'hi':
          'पार्क, पर्यावरण स्थल, विरासत स्थान, पुस्तकालय, काउंसिल सुविधाओं और सामुदायिक कार्यक्रमों पर आधिकारिक संकेत स्कैन करें।',
    },
    'Earn XP': {
      'zh': '获得经验值',
      'ko': 'XP 획득',
      'it': 'Ottieni XP',
      'hi': 'XP पाएँ',
    },
    'Level up your local explorer profile.': {
      'zh': '提升您的本地探索者等级。',
      'ko': '지역 탐험가 프로필 레벨을 올리세요.',
      'it': 'Fai salire di livello il profilo esploratore locale.',
      'hi': 'अपनी स्थानीय खोजकर्ता प्रोफ़ाइल का स्तर बढ़ाएँ।',
    },
    'Build badge progress': {
      'zh': '增加徽章进度',
      'ko': '배지 진행 상황 쌓기',
      'it': 'Fai avanzare i badge',
      'hi': 'बैज की प्रगति बढ़ाएँ',
    },
    'Complete themed discovery collections.': {
      'zh': '完成主题探索收藏。',
      'ko': '테마별 발견 컬렉션을 완성하세요.',
      'it': 'Completa le collezioni di scoperte a tema.',
      'hi': 'थीम आधारित खोज संग्रह पूरे करें।',
    },
    'Unlock local stories': {
      'zh': '解锁本地故事',
      'ko': '지역 이야기 해제',
      'it': 'Sblocca storie locali',
      'hi': 'स्थानीय कहानियाँ खोलें',
    },
    'Reveal trusted place information and learning content.': {
      'zh': '查看可靠的地点信息和学习内容。',
      'ko': '신뢰할 수 있는 장소 정보와 학습 콘텐츠를 확인하세요.',
      'it': 'Scopri informazioni affidabili sui luoghi e contenuti educativi.',
      'hi': 'भरोसेमंद स्थान जानकारी और सीखने की सामग्री पाएँ।',
    },
    'Rewards are saved to your passport and each official QR reward can only be collected once.': {
      'zh': '奖励会保存到您的护照中，每个官方二维码奖励只能领取一次。',
      'ko': '보상은 패스포트에 저장되며 각 공식 QR 보상은 한 번만 받을 수 있습니다.',
      'it':
          'I premi vengono salvati nel passaporto e ogni premio QR ufficiale può essere raccolto una sola volta.',
      'hi':
          'पुरस्कार पासपोर्ट में सहेजे जाते हैं और हर आधिकारिक QR पुरस्कार केवल एक बार लिया जा सकता है।',
    },
    'YOUR NEXT REWARD IS OUT THERE': {
      'zh': '下一份奖励正在等您',
      'ko': '다음 보상이 기다리고 있습니다',
      'it': 'IL PROSSIMO PREMIO TI ASPETTA',
      'hi': 'अगला पुरस्कार बाहर आपका इंतज़ार कर रहा है',
    },
    'Continue on your mobile': {
      'zh': '在手机上继续',
      'ko': '모바일에서 계속하기',
      'it': 'Continua sul cellulare',
      'hi': 'मोबाइल पर जारी रखें',
    },
    'Explore the community in person by installing the Explore Canada Bay app on your mobile device. Use your phone to scan signs, collect XP and unlock passport badges as you visit.': {
      'zh': '在手机上安装 Explore Canada Bay 应用，亲自探索社区。到访时用手机扫描标牌、收集经验值并解锁护照徽章。',
      'ko':
          '모바일 기기에 Explore Canada Bay 앱을 설치하고 직접 커뮤니티를 탐험하세요. 방문 중 휴대전화로 표지판을 스캔하고 XP를 모아 패스포트 배지를 해제할 수 있습니다.',
      'it':
          'Installa Explore Canada Bay sul cellulare per esplorare la comunità di persona. Durante le visite scansiona i cartelli, raccogli XP e sblocca badge.',
      'hi':
          'समुदाय को स्वयं खोजने के लिए अपने मोबाइल पर Explore Canada Bay ऐप इंस्टॉल करें। यात्रा के दौरान संकेत स्कैन करें, XP जुटाएँ और पासपोर्ट बैज खोलें।',
    },
    'Scan local signs': {
      'zh': '扫描本地标牌',
      'ko': '지역 표지판 스캔',
      'it': 'Scansiona cartelli locali',
      'hi': 'स्थानीय संकेत स्कैन करें',
    },
    'Earn XP and badges': {
      'zh': '获得经验值和徽章',
      'ko': 'XP와 배지 획득',
      'it': 'Ottieni XP e badge',
      'hi': 'XP और बैज पाएँ',
    },
    'Camera unavailable': {
      'zh': '相机不可用',
      'ko': '카메라 사용 불가',
      'it': 'Fotocamera non disponibile',
      'hi': 'कैमरा उपलब्ध नहीं',
    },
    'Enter code instead': {
      'zh': '改为输入代码',
      'ko': '대신 코드 입력',
      'it': 'Inserisci il codice',
      'hi': 'इसके बजाय कोड दर्ज करें',
    },
    'This reward could not be saved. Please try again.': {
      'zh': '无法保存此奖励。请重试。',
      'ko': '이 보상을 저장할 수 없습니다. 다시 시도하세요.',
      'it': 'Impossibile salvare il premio. Riprova.',
      'hi': 'यह पुरस्कार सहेजा नहीं जा सका। फिर कोशिश करें।',
    },
    'The QR code is empty.': {
      'zh': '二维码为空。',
      'ko': 'QR 코드가 비어 있습니다.',
      'it': 'Il codice QR è vuoto.',
      'hi': 'QR कोड खाली है।',
    },
    'The QR code does not contain valid JSON.': {
      'zh': '二维码不包含有效的 JSON。',
      'ko': 'QR 코드에 유효한 JSON이 없습니다.',
      'it': 'Il codice QR non contiene JSON valido.',
      'hi': 'QR कोड में मान्य JSON नहीं है।',
    },
    'The QR reward must be a JSON object.': {
      'zh': '二维码奖励必须是 JSON 对象。',
      'ko': 'QR 보상은 JSON 객체여야 합니다.',
      'it': 'Il premio QR deve essere un oggetto JSON.',
      'hi': 'QR पुरस्कार JSON ऑब्जेक्ट होना चाहिए।',
    },
    'This QR code is not an Explore Canada Bay passport reward.': {
      'zh': '此二维码不是 Explore Canada Bay 护照奖励。',
      'ko': '이 QR 코드는 Explore Canada Bay 패스포트 보상이 아닙니다.',
      'it': 'Questo QR non è un premio del passaporto Explore Canada Bay.',
      'hi': 'यह QR कोड Explore Canada Bay पासपोर्ट पुरस्कार नहीं है।',
    },
    'This QR reward version is not supported.': {
      'zh': '不支持此二维码奖励版本。',
      'ko': '이 QR 보상 버전은 지원되지 않습니다.',
      'it': 'Questa versione del premio QR non è supportata.',
      'hi': 'यह QR पुरस्कार संस्करण समर्थित नहीं है।',
    },
    'Wetland habitat': {
      'zh': '湿地栖息地',
      'ko': '습지 서식지',
      'it': 'Habitat delle zone umide',
      'hi': 'आर्द्रभूमि आवास',
    },
    'Mangroves and saltmarsh provide habitat for local wildlife.': {
      'zh': '红树林和盐沼为本地野生动物提供栖息地。',
      'ko': '맹그로브와 염습지는 지역 야생동물의 서식지를 제공합니다.',
      'it': 'Mangrovie e paludi salmastre offrono habitat alla fauna locale.',
      'hi': 'मैंग्रोव और खारे दलदल स्थानीय वन्यजीवों को आवास देते हैं।',
    },
    'Environment': {'zh': '环境', 'ko': '환경', 'it': 'Ambiente', 'hi': 'पर्यावरण'},
  };

  static const Map<String, Map<String, String>> _dynamicPhrases = {
    'Signed in as {name}': {
      'zh': '已以 {name} 登录',
      'ko': '{name}(으)로 로그인됨',
      'it': 'Accesso effettuato come {name}',
      'hi': '{name} के रूप में साइन इन',
    },
    'Device profile • {email}': {
      'zh': '设备资料 • {email}',
      'ko': '기기 프로필 • {email}',
      'it': 'Profilo dispositivo • {email}',
      'hi': 'डिवाइस प्रोफ़ाइल • {email}',
    },
    '{files} could not be loaded. Check your asset paths and pubspec.yaml.': {
      'zh': '无法加载 {files}。请检查资源路径和 pubspec.yaml。',
      'ko': '{files}을(를) 불러올 수 없습니다. 에셋 경로와 pubspec.yaml을 확인하세요.',
      'it':
          'Impossibile caricare {files}. Controlla i percorsi delle risorse e pubspec.yaml.',
      'hi': '{files} लोड नहीं हो सका। एसेट पथ और pubspec.yaml जाँचें।',
    },
    '{reward} · Community Passport': {
      'zh': '{reward} · 社区护照',
      'ko': '{reward} · 커뮤니티 패스포트',
      'it': '{reward} · Passaporto della comunità',
      'hi': '{reward} · समुदाय पासपोर्ट',
    },
    '{distance} m away': {
      'zh': '距您 {distance} 米',
      'ko': '{distance}m 거리',
      'it': 'a {distance} m',
      'hi': '{distance} मीटर दूर',
    },
    '{distance} km away': {
      'zh': '距您 {distance} 公里',
      'ko': '{distance}km 거리',
      'it': 'a {distance} km',
      'hi': '{distance} किमी दूर',
    },
    '{title} saved': {
      'zh': '已保存 {title}',
      'ko': '{title} 저장됨',
      'it': '{title} salvato',
      'hi': '{title} सहेजा गया',
    },
    '{title} saved.': {
      'zh': '已保存 {title}。',
      'ko': '{title} 저장됨.',
      'it': '{title} salvato.',
      'hi': '{title} सहेजा गया।',
    },
    '{title} removed from saved routes.': {
      'zh': '已从保存的路线中移除 {title}。',
      'ko': '저장한 경로에서 {title}을(를) 삭제했습니다.',
      'it': '{title} rimosso dai percorsi salvati.',
      'hi': '{title} सहेजे गए मार्गों से हटाया गया।',
    },
    '{title} opened': {
      'zh': '已打开 {title}',
      'ko': '{title} 열림',
      'it': '{title} aperto',
      'hi': '{title} खोला गया',
    },
    '{count} local tools ready': {
      'zh': '{count} 个本地工具已准备就绪',
      'ko': '지역 도구 {count}개 준비됨',
      'it': '{count} strumenti locali pronti',
      'hi': '{count} स्थानीय साधन तैयार',
    },
    '{day} bins · {stop}': {
      'zh': '{day} 收垃圾桶 · {stop}',
      'ko': '{day} 쓰레기 수거 · {stop}',
      'it': 'Raccolta {day} · {stop}',
      'hi': '{day} कचरा संग्रह · {stop}',
    },
    'Welcome, {name}': {
      'zh': '欢迎，{name}',
      'ko': '환영합니다, {name}',
      'it': 'Benvenuto, {name}',
      'hi': 'स्वागत है, {name}',
    },
    'Level {level} progress': {
      'zh': '{level} 级进度',
      'ko': '레벨 {level} 진행 상황',
      'it': 'Progresso livello {level}',
      'hi': 'स्तर {level} की प्रगति',
    },
    '{xp} XP · {remaining} to next': {
      'zh': '{xp} XP · 距下一级 {remaining}',
      'ko': '{xp} XP · 다음 레벨까지 {remaining}',
      'it': '{xp} XP · {remaining} al prossimo livello',
      'hi': '{xp} XP · अगले स्तर तक {remaining}',
    },
    '{count} day streak': {
      'zh': '连续 {count} 天',
      'ko': '{count}일 연속',
      'it': 'serie di {count} giorni',
      'hi': '{count} दिन लगातार',
    },
    '{count} badges earned': {
      'zh': '已获得 {count} 个徽章',
      'ko': '배지 {count}개 획득',
      'it': '{count} badge ottenuti',
      'hi': '{count} बैज अर्जित',
    },
    '{earned}/{total} badges earned': {
      'zh': '已获得 {earned}/{total} 个徽章',
      'ko': '배지 {earned}/{total}개 획득',
      'it': '{earned}/{total} badge ottenuti',
      'hi': '{earned}/{total} बैज अर्जित',
    },
    '{count} badge still waiting.': {
      'zh': '还有 {count} 个徽章等待获得。',
      'ko': '배지 {count}개가 아직 남아 있습니다.',
      'it': 'Manca ancora {count} badge.',
      'hi': '{count} बैज अभी बाकी है।',
    },
    '{count} badges still waiting.': {
      'zh': '还有 {count} 个徽章等待获得。',
      'ko': '배지 {count}개가 아직 남아 있습니다.',
      'it': 'Mancano ancora {count} badge.',
      'hi': '{count} बैज अभी बाकी हैं।',
    },
    '{completed} of 5 essentials saved': {
      'zh': '已保存 {completed}/5 项必备信息',
      'ko': '필수 정보 5개 중 {completed}개 저장됨',
      'it': '{completed} elementi essenziali su 5 salvati',
      'hi': '5 में से {completed} ज़रूरी जानकारियाँ सहेजी गईं',
    },
    'Level {level}': {
      'zh': '等级 {level}',
      'ko': '레벨 {level}',
      'it': 'Livello {level}',
      'hi': 'स्तर {level}',
    },
    '{xp} XP to next level': {
      'zh': '距下一级 {xp} XP',
      'ko': '다음 레벨까지 {xp} XP',
      'it': '{xp} XP al prossimo livello',
      'hi': 'अगले स्तर तक {xp} XP',
    },
    "{name}'s Passport": {
      'zh': '{name} 的护照',
      'ko': '{name}의 패스포트',
      'it': 'Passaporto di {name}',
      'hi': '{name} का पासपोर्ट',
    },
    'Journey level {level} · {points} points to the next milestone': {
      'zh': '旅程等级 {level} · 距下一里程碑 {points} 分',
      'ko': '여정 레벨 {level} · 다음 이정표까지 {points}포인트',
      'it': 'Livello percorso {level} · {points} punti al prossimo traguardo',
      'hi': 'यात्रा स्तर {level} · अगले पड़ाव तक {points} अंक',
    },
    '{count} collections · {earned} of {total} stamps earned': {
      'zh': '{count} 个收藏 · 已获得 {earned}/{total} 枚印章',
      'ko': '컬렉션 {count}개 · 스탬프 {earned}/{total}개 획득',
      'it': '{count} collezioni · {earned} timbri su {total} ottenuti',
      'hi': '{count} संग्रह · {total} में से {earned} स्टाम्प अर्जित',
    },
    '{earned} of {total} earned': {
      'zh': '已获得 {earned}/{total}',
      'ko': '{earned}/{total}개 획득',
      'it': '{earned} su {total} ottenuti',
      'hi': '{total} में से {earned} अर्जित',
    },
    '{progress}/{target} discoveries': {
      'zh': '{progress}/{target} 次发现',
      'ko': '발견 {progress}/{target}',
      'it': '{progress}/{target} scoperte',
      'hi': '{progress}/{target} खोजें',
    },
    'Today at {time}': {
      'zh': '今天 {time}',
      'ko': '오늘 {time}',
      'it': 'Oggi alle {time}',
      'hi': 'आज {time} बजे',
    },
    '{badge} badge artwork': {
      'zh': '{badge} 徽章图案',
      'ko': '{badge} 배지 이미지',
      'it': 'Grafica del badge {badge}',
      'hi': '{badge} बैज चित्र',
    },
    '{badge} {progress}/{target}': {
      'zh': '{badge} {progress}/{target}',
      'ko': '{badge} {progress}/{target}',
      'it': '{badge} {progress}/{target}',
      'hi': '{badge} {progress}/{target}',
    },
    '{count} stops': {
      'zh': '{count} 个停靠点',
      'ko': '정류장 {count}개',
      'it': '{count} tappe',
      'hi': '{count} पड़ाव',
    },
    'Badge "{id}" is not in the trusted badge catalogue.': {
      'zh': '徽章“{id}”不在可信徽章目录中。',
      'ko': '배지 "{id}"은(는) 신뢰할 수 있는 배지 목록에 없습니다.',
      'it': 'Il badge “{id}” non è nel catalogo attendibile.',
      'hi': 'बैज “{id}” भरोसेमंद बैज सूची में नहीं है।',
    },
  };

  static const _literalKeys = <String, String>{
    'Community': 'community',
    'Services': 'services',
    'Passport': 'passport',
    'Profile': 'profile',
    'Scan': 'scan',
    'Map': 'openMap',
    'Suggested Route': 'suggestedRoute',
    'Community Passport': 'passportTitle',
    'Scan & Discover': 'scanDiscover',
    'Find your community': 'communityTitle',
    'Browse by interest': 'browseByInterest',
    'Search activities, groups or interests': 'searchCommunity',
    'Where would you like to explore?': 'explorePrompt',
    'Settle in with confidence': 'servicesTagline',
    'Your local adventure': 'localAdventure',
    'Your next reward is out there': 'scanTagline',
    'Your Canada Bay adventure starts here': 'profileAdventure',
    'Continue': 'continue',
    'Language': 'language',
  };

  static const _interfaceLiterals = <String, Map<String, String>>{
    'zh': {
      'On Display': '展示中的成就',
      'Community collections': '社区收藏',
      'Recent Discoveries': '最近发现',
      'Your latest passport rewards': '您最近获得的护照奖励',
      'Choose up to 3 earned trophies to feature': '最多选择 3 个已获得的徽章进行展示',
      'badges': '徽章',
      'scans': '扫描',
      'today': '今天',
      'Journey': '新居民指南',
      'Everyday essentials': '日常生活要点',
      'Start Exploring': '开始探索',
      'Civic help': '市政帮助',
      'Preferences': '偏好设置',
      'Badge Collection': '徽章收藏',
      'Profile storage': '个人资料存储',
      'Passport display': '护照展示',
      'Torch': '手电筒',
      'Enter code': '输入代码',
      'Scan another': '再次扫描',
      'Official source': '官方来源',
    },
    'ko': {
      'On Display': '전시 중인 성취',
      'Community collections': '커뮤니티 컬렉션',
      'Recent Discoveries': '최근 발견',
      'Your latest passport rewards': '최근 여권 보상',
      'Choose up to 3 earned trophies to feature': '획득한 배지 최대 3개를 전시하세요',
      'badges': '배지',
      'scans': '스캔',
      'today': '오늘',
      'Journey': '새 주민 안내',
      'Everyday essentials': '생활 필수 정보',
      'Start Exploring': '탐험 시작',
      'Civic help': '행정 도움',
      'Preferences': '환경설정',
      'Badge Collection': '배지 컬렉션',
      'Profile storage': '프로필 저장',
      'Passport display': '여권 전시',
      'Torch': '손전등',
      'Enter code': '코드 입력',
      'Scan another': '다시 스캔',
      'Official source': '공식 출처',
    },
    'it': {
      'On Display': 'In mostra',
      'Community collections': 'Collezioni della comunità',
      'Recent Discoveries': 'Scoperte recenti',
      'Your latest passport rewards': 'Le tue ricompense più recenti',
      'Choose up to 3 earned trophies to feature':
          'Scegli fino a 3 badge da mostrare',
      'badges': 'badge',
      'scans': 'scansioni',
      'today': 'oggi',
      'Journey': 'Percorso',
      'Everyday essentials': 'Servizi essenziali',
      'Start Exploring': 'Inizia a esplorare',
      'Civic help': 'Aiuto civico',
      'Preferences': 'Preferenze',
      'Badge Collection': 'Collezione badge',
      'Profile storage': 'Salvataggio profilo',
      'Passport display': 'Vetrina del passaporto',
      'Torch': 'Torcia',
      'Enter code': 'Inserisci codice',
      'Scan another': 'Scansiona ancora',
      'Official source': 'Fonte ufficiale',
    },
    'hi': {
      'On Display': 'प्रदर्शित उपलब्धियाँ',
      'Community collections': 'सामुदायिक संग्रह',
      'Recent Discoveries': 'हाल की खोजें',
      'Your latest passport rewards': 'आपके नवीनतम पासपोर्ट पुरस्कार',
      'Choose up to 3 earned trophies to feature':
          'दिखाने के लिए अधिकतम 3 अर्जित बैज चुनें',
      'badges': 'बैज',
      'scans': 'स्कैन',
      'today': 'आज',
      'Journey': 'निवासी यात्रा',
      'Everyday essentials': 'रोज़मर्रा की ज़रूरी जानकारी',
      'Start Exploring': 'खोजना शुरू करें',
      'Civic help': 'नागरिक सहायता',
      'Preferences': 'प्राथमिकताएँ',
      'Badge Collection': 'बैज संग्रह',
      'Profile storage': 'प्रोफ़ाइल संग्रहण',
      'Passport display': 'पासपोर्ट प्रदर्शन',
      'Torch': 'टॉर्च',
      'Enter code': 'कोड दर्ज करें',
      'Scan another': 'फिर स्कैन करें',
      'Official source': 'आधिकारिक स्रोत',
    },
  };

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'home': 'Home',
      'explore': 'Explore',
      'community': 'Community',
      'services': 'Services',
      'passport': 'Passport',
      'scan': 'Scan',
      'profile': 'Profile',
      'continue': 'Continue',
      'welcomeTitle': 'Make Canada Bay feel like home',
      'welcomeBody':
          'Find local services, community activities and places worth knowing.',
      'aboutYou': 'Tell us what brings you here',
      'interests': 'What would help you settle in?',
      'language': 'Language',
      'newResident': 'New resident',
      'student': 'Student',
      'family': 'Family',
      'professional': 'Young professional',
      'retiree': 'Retiree',
      'communityInterest': 'Community',
      'outdoorsInterest': 'Outdoors',
      'environmentInterest': 'Environment',
      'foodInterest': 'Local food',
      'servicesInterest': 'Local services',
      'homeWelcome': 'Welcome, {name}',
      'homePrompt': 'What would you like to do in Canada Bay today?',
      'openMap': 'Map',
      'journeyStart': 'Start your newcomer journey',
      'journeySaved': '{count} journey steps saved',
      'journeyBody': 'Learn the essentials, explore locally and feel connected',
      'suggestedRoute': 'Suggested route',
      'suggestedRouteBody': 'A local walk chosen for you',
      'communityTitle': 'Find your community',
      'communitySubtitle': 'Meet, join and belong',
      'trustedLeads': '{count} trusted leads',
      'welcomeDeskTitle': 'New here? Start with the local welcome desk',
      'welcomeDeskBody':
          'A quick guide to finding people, activities and trusted sources.',
      'browseByInterest': 'Browse by interest',
      'opportunity': 'opportunity',
      'opportunities': 'opportunities',
      'searchCommunity': 'Search activities, groups or interests',
      'localAdventure': 'Your local adventure',
      'explorePrompt': 'Where would you like to explore?',
      'servicesTagline': 'Settle in with confidence',
      'passportTitle': 'Community Passport',
      'passportTagline': 'Discover · Scan · Collect',
      'exploreAreaTitle': 'Explore',
      'exploreAreaSubtitle': 'Discover maps, routes and local places',
      'understandAreaTitle': 'Understand',
      'understandAreaSubtitle':
          'Find trusted local services and civic information',
      'connectAreaTitle': 'Connect',
      'connectAreaSubtitle': 'Find events, groups and ways to get involved',
      'engageAreaTitle': 'Engage',
      'engageAreaSubtitle':
          'Build your Passport with badges and QR discoveries',
      'scanDiscover': 'Scan & Discover',
      'scanTagline': 'Your next reward is out there',
      'helloName': 'Hello, {name}',
      'profileAdventure': 'Your Canada Bay adventure starts here',
      'servicesSearch': 'Search bins, parking, libraries or toilets',
      'levelNumber': 'Level {number}',
      'weekday1': 'Monday',
      'weekday2': 'Tuesday',
      'weekday3': 'Wednesday',
      'weekday4': 'Thursday',
      'weekday5': 'Friday',
      'weekday6': 'Saturday',
      'weekday7': 'Sunday',
      'modeTrain': 'Train',
      'modeBus': 'Bus',
      'modeFerry': 'Ferry',
      'modeLightRail': 'Light rail',
      'modeBike': 'Bike',
      'modeWalk': 'Walk',
      'modePublicTransport': 'Public transport',
      'qrInvalidField': 'A required QR reward field is missing or invalid.',
      'qrFieldTooLong': 'A QR reward field is too long.',
      'qrInvalidNumber': 'A QR reward number is invalid.',
      'qrInvalidObject': 'The QR reward has an invalid structure.',
      'qrInvalidLink': 'The QR reward link is not a safe web address.',
      'qrInvalidGeneric': 'This code is not a valid passport reward.',
      'rewardDuplicate':
          '{place} has already been scanned. No rewards were added.',
      'rewardBadge': '{badge} badge unlocked!',
      'rewardBadgeXp': '{badge} badge unlocked! +{xp} XP',
      'rewardProgress': '{place}: {badge} {progress}/{target} badge progress.',
      'rewardProgressXp':
          '+{xp} XP and {badge} {progress}/{target} badge progress at {place}.',
      'rewardXp': '+{xp} XP earned at {place}.',
      'rewardAdded': '{place} added to your passport.',
    },
    'zh': {
      'homeWelcome': '欢迎，{name}',
      'homePrompt': '今天您想在加拿大湾做什么？',
      'openMap': '地图',
      'journeyStart': '开始新居民之旅',
      'journeySaved': '已保存 {count} 个步骤',
      'journeyBody': '了解生活要点、探索本地并融入社区',
      'suggestedRoute': '推荐路线',
      'suggestedRouteBody': '为您选择的本地步行路线',
      'communityTitle': '寻找您的社区',
      'communitySubtitle': '认识、参与、融入',
      'trustedLeads': '{count} 条可信信息',
      'welcomeDeskTitle': '初来乍到？从本地欢迎指南开始',
      'welcomeDeskBody': '快速查找社区活动、组织和可信信息。',
      'browseByInterest': '按兴趣浏览',
      'opportunity': '项活动',
      'opportunities': '项活动',
      'searchCommunity': '搜索活动、组织或兴趣',
      'localAdventure': '您的本地探索',
      'explorePrompt': '您想探索哪里？',
      'servicesTagline': '安心融入本地生活',
      'passportTitle': '社区护照',
      'passportTagline': '探索 · 扫描 · 收集',
      'exploreAreaTitle': '探索',
      'exploreAreaSubtitle': '发现地图、路线和本地地点',
      'understandAreaTitle': '了解',
      'understandAreaSubtitle': '查找可信的本地服务和市政信息',
      'connectAreaTitle': '连接',
      'connectAreaSubtitle': '查找活动、团体和参与社区的方式',
      'engageAreaTitle': '参与',
      'engageAreaSubtitle': '通过徽章和二维码发现丰富您的社区护照',
      'scanDiscover': '扫描并发现',
      'scanTagline': '下一份奖励正在等您',
      'helloName': '您好，{name}',
      'profileAdventure': '您的加拿大湾探索从这里开始',
      'servicesSearch': '搜索垃圾、停车、图书馆或公厕',
      'levelNumber': '等级 {number}',
      'home': '首页',
      'explore': '探索',
      'community': '社区',
      'services': '本地服务',
      'passport': '社区护照',
      'scan': '扫描',
      'profile': '个人资料',
      'continue': '继续',
      'welcomeTitle': '让加拿大湾成为您的家',
      'welcomeBody': '查找本地服务、社区活动和值得了解的地方。',
      'aboutYou': '告诉我们您为何来到这里',
      'interests': '哪些信息能帮助您融入社区？',
      'language': '语言',
      'newResident': '新居民',
      'student': '学生',
      'family': '家庭',
      'professional': '年轻专业人士',
      'retiree': '退休人士',
      'communityInterest': '社区',
      'outdoorsInterest': '户外活动',
      'environmentInterest': '环境',
      'foodInterest': '本地美食',
      'servicesInterest': '本地服务',
      'weekday1': '星期一',
      'weekday2': '星期二',
      'weekday3': '星期三',
      'weekday4': '星期四',
      'weekday5': '星期五',
      'weekday6': '星期六',
      'weekday7': '星期日',
      'modeTrain': '火车',
      'modeBus': '公交车',
      'modeFerry': '渡轮',
      'modeLightRail': '轻轨',
      'modeBike': '自行车',
      'modeWalk': '步行',
      'modePublicTransport': '公共交通',
      'qrInvalidField': '二维码奖励缺少必填字段或字段无效。',
      'qrFieldTooLong': '二维码奖励中的字段过长。',
      'qrInvalidNumber': '二维码奖励中的数字无效。',
      'qrInvalidObject': '二维码奖励结构无效。',
      'qrInvalidLink': '二维码奖励链接不是安全的网址。',
      'qrInvalidGeneric': '此代码不是有效的护照奖励。',
      'rewardDuplicate': '{place} 已扫描过。未添加任何奖励。',
      'rewardBadge': '已解锁 {badge} 徽章！',
      'rewardBadgeXp': '已解锁 {badge} 徽章！+{xp} XP',
      'rewardProgress': '{place}：{badge} 徽章进度 {progress}/{target}。',
      'rewardProgressXp':
          '在 {place} 获得 +{xp} XP，{badge} 徽章进度 {progress}/{target}。',
      'rewardXp': '在 {place} 获得 +{xp} XP。',
      'rewardAdded': '{place} 已添加到您的护照。',
    },
    'ko': {
      'homeWelcome': '환영합니다, {name}',
      'homePrompt': '오늘 캐나다 베이에서 무엇을 하고 싶으신가요?',
      'openMap': '지도',
      'journeyStart': '새 주민 여정 시작하기',
      'journeySaved': '여정 단계 {count}개 저장됨',
      'journeyBody': '생활 정보를 배우고 지역을 탐색하며 이웃과 연결하세요',
      'suggestedRoute': '추천 경로',
      'suggestedRouteBody': '나를 위해 고른 지역 산책로',
      'communityTitle': '우리 동네 커뮤니티 찾기',
      'communitySubtitle': '만나고, 참여하고, 소속되세요',
      'trustedLeads': '신뢰할 수 있는 정보 {count}개',
      'welcomeDeskTitle': '처음 오셨나요? 지역 환영 안내부터 시작하세요',
      'welcomeDeskBody': '사람, 활동과 신뢰할 수 있는 정보를 빠르게 찾아보세요.',
      'browseByInterest': '관심사별 보기',
      'opportunity': '개 활동',
      'opportunities': '개 활동',
      'searchCommunity': '활동, 모임 또는 관심사 검색',
      'localAdventure': '우리 동네 탐험',
      'explorePrompt': '어디를 탐험하고 싶으신가요?',
      'servicesTagline': '안심하고 지역에 정착하세요',
      'passportTitle': '커뮤니티 여권',
      'passportTagline': '발견 · 스캔 · 수집',
      'exploreAreaTitle': '탐색',
      'exploreAreaSubtitle': '지도, 경로와 지역 장소를 발견하세요',
      'understandAreaTitle': '이해',
      'understandAreaSubtitle': '신뢰할 수 있는 지역 서비스와 시민 정보를 찾으세요',
      'connectAreaTitle': '연결',
      'connectAreaSubtitle': '행사와 모임, 지역사회 참여 방법을 찾아보세요',
      'engageAreaTitle': '참여',
      'engageAreaSubtitle': '배지와 QR 발견으로 커뮤니티 여권을 채우세요',
      'scanDiscover': '스캔하고 발견하기',
      'scanTagline': '다음 보상이 기다리고 있어요',
      'helloName': '안녕하세요, {name}',
      'profileAdventure': '캐나다 베이 탐험을 여기서 시작하세요',
      'servicesSearch': '쓰레기, 주차, 도서관 또는 화장실 검색',
      'levelNumber': '레벨 {number}',
      'home': '홈',
      'explore': '탐색',
      'community': '커뮤니티',
      'services': '지역 서비스',
      'passport': '커뮤니티 여권',
      'scan': '스캔',
      'profile': '프로필',
      'continue': '계속',
      'welcomeTitle': '캐나다 베이를 우리 동네로 만들어 보세요',
      'welcomeBody': '지역 서비스, 커뮤니티 활동과 알아두면 좋은 장소를 찾아보세요.',
      'aboutYou': '이곳에 오신 이유를 알려주세요',
      'interests': '정착에 어떤 도움이 필요하신가요?',
      'language': '언어',
      'newResident': '새 주민',
      'student': '학생',
      'family': '가족',
      'professional': '청년 직장인',
      'retiree': '은퇴자',
      'communityInterest': '커뮤니티',
      'outdoorsInterest': '야외 활동',
      'environmentInterest': '환경',
      'foodInterest': '지역 음식',
      'servicesInterest': '지역 서비스',
      'weekday1': '월요일',
      'weekday2': '화요일',
      'weekday3': '수요일',
      'weekday4': '목요일',
      'weekday5': '금요일',
      'weekday6': '토요일',
      'weekday7': '일요일',
      'modeTrain': '기차',
      'modeBus': '버스',
      'modeFerry': '페리',
      'modeLightRail': '경전철',
      'modeBike': '자전거',
      'modeWalk': '도보',
      'modePublicTransport': '대중교통',
      'qrInvalidField': '필수 QR 보상 필드가 없거나 올바르지 않습니다.',
      'qrFieldTooLong': 'QR 보상 필드가 너무 깁니다.',
      'qrInvalidNumber': 'QR 보상 숫자가 올바르지 않습니다.',
      'qrInvalidObject': 'QR 보상 구조가 올바르지 않습니다.',
      'qrInvalidLink': 'QR 보상 링크가 안전한 웹 주소가 아닙니다.',
      'qrInvalidGeneric': '유효한 패스포트 보상 코드가 아닙니다.',
      'rewardDuplicate': '{place}은(는) 이미 스캔했습니다. 보상이 추가되지 않았습니다.',
      'rewardBadge': '{badge} 배지 해제!',
      'rewardBadgeXp': '{badge} 배지 해제! +{xp} XP',
      'rewardProgress': '{place}: {badge} 배지 진행 상황 {progress}/{target}.',
      'rewardProgressXp':
          '{place}에서 +{xp} XP 및 {badge} 배지 진행 상황 {progress}/{target}.',
      'rewardXp': '{place}에서 +{xp} XP 획득.',
      'rewardAdded': '{place}이(가) 패스포트에 추가되었습니다.',
    },
    'it': {
      'homeWelcome': 'Benvenuto, {name}',
      'homePrompt': 'Cosa vorresti fare oggi a Canada Bay?',
      'openMap': 'Mappa',
      'journeyStart': 'Inizia il percorso per nuovi residenti',
      'journeySaved': '{count} tappe salvate',
      'journeyBody': 'Scopri i servizi essenziali, esplora e connettiti',
      'suggestedRoute': 'Percorso consigliato',
      'suggestedRouteBody': 'Una passeggiata locale scelta per te',
      'communityTitle': 'Trova la tua comunità',
      'communitySubtitle': 'Incontra, partecipa, sentiti a casa',
      'trustedLeads': '{count} risorse verificate',
      'welcomeDeskTitle': 'Sei nuovo? Inizia dalla guida di benvenuto',
      'welcomeDeskBody':
          'Una guida rapida ad attività, gruppi e fonti affidabili.',
      'browseByInterest': 'Esplora per interesse',
      'opportunity': 'opportunità',
      'opportunities': 'opportunità',
      'searchCommunity': 'Cerca attività, gruppi o interessi',
      'localAdventure': 'La tua avventura locale',
      'explorePrompt': 'Dove vorresti esplorare?',
      'servicesTagline': 'Ambientati con fiducia',
      'passportTitle': 'Passaporto della comunità',
      'passportTagline': 'Scopri · Scansiona · Colleziona',
      'exploreAreaTitle': 'Esplora',
      'exploreAreaSubtitle': 'Scopri mappe, percorsi e luoghi locali',
      'understandAreaTitle': 'Comprendi',
      'understandAreaSubtitle':
          'Trova servizi locali affidabili e informazioni civiche',
      'connectAreaTitle': 'Connettiti',
      'connectAreaSubtitle': 'Trova eventi, gruppi e modi per partecipare',
      'engageAreaTitle': 'Partecipa',
      'engageAreaSubtitle': 'Arricchisci il Passaporto con badge e scoperte QR',
      'scanDiscover': 'Scansiona e scopri',
      'scanTagline': 'La prossima ricompensa ti aspetta',
      'helloName': 'Ciao, {name}',
      'profileAdventure': 'La tua avventura a Canada Bay inizia qui',
      'servicesSearch': 'Cerca rifiuti, parcheggi, biblioteche o bagni',
      'levelNumber': 'Livello {number}',
      'home': 'Home',
      'explore': 'Esplora',
      'community': 'Comunità',
      'services': 'Servizi',
      'passport': 'Passaporto',
      'scan': 'Scansiona',
      'profile': 'Profilo',
      'continue': 'Continua',
      'welcomeTitle': 'Fai di Canada Bay la tua casa',
      'welcomeBody':
          'Trova servizi locali, attività comunitarie e luoghi da conoscere.',
      'aboutYou': 'Raccontaci cosa ti porta qui',
      'interests': 'Cosa ti aiuterebbe ad ambientarti?',
      'language': 'Lingua',
      'newResident': 'Nuovo residente',
      'student': 'Studente',
      'family': 'Famiglia',
      'professional': 'Giovane professionista',
      'retiree': 'Pensionato',
      'communityInterest': 'Comunità',
      'outdoorsInterest': 'Attività all’aperto',
      'environmentInterest': 'Ambiente',
      'foodInterest': 'Cibo locale',
      'servicesInterest': 'Servizi locali',
      'weekday1': 'Lunedì',
      'weekday2': 'Martedì',
      'weekday3': 'Mercoledì',
      'weekday4': 'Giovedì',
      'weekday5': 'Venerdì',
      'weekday6': 'Sabato',
      'weekday7': 'Domenica',
      'modeTrain': 'Treno',
      'modeBus': 'Autobus',
      'modeFerry': 'Traghetto',
      'modeLightRail': 'Metro leggera',
      'modeBike': 'Bicicletta',
      'modeWalk': 'A piedi',
      'modePublicTransport': 'Trasporto pubblico',
      'qrInvalidField':
          'Un campo obbligatorio del premio QR è mancante o non valido.',
      'qrFieldTooLong': 'Un campo del premio QR è troppo lungo.',
      'qrInvalidNumber': 'Un numero del premio QR non è valido.',
      'qrInvalidObject': 'La struttura del premio QR non è valida.',
      'qrInvalidLink': 'Il link del premio QR non è un indirizzo web sicuro.',
      'qrInvalidGeneric':
          'Questo codice non è un premio valido del passaporto.',
      'rewardDuplicate':
          '{place} è già stato scansionato. Nessun premio aggiunto.',
      'rewardBadge': 'Badge {badge} sbloccato!',
      'rewardBadgeXp': 'Badge {badge} sbloccato! +{xp} XP',
      'rewardProgress': '{place}: progresso badge {badge} {progress}/{target}.',
      'rewardProgressXp':
          '+{xp} XP e progresso badge {badge} {progress}/{target} a {place}.',
      'rewardXp': '+{xp} XP ottenuti a {place}.',
      'rewardAdded': '{place} aggiunto al passaporto.',
    },
    'hi': {
      'homeWelcome': 'स्वागत है, {name}',
      'homePrompt': 'आज आप कनाडा बे में क्या करना चाहेंगे?',
      'openMap': 'मानचित्र',
      'journeyStart': 'नए निवासी की यात्रा शुरू करें',
      'journeySaved': '{count} चरण सहेजे गए',
      'journeyBody': 'ज़रूरी बातें जानें, स्थानीय जगहें खोजें और जुड़ें',
      'suggestedRoute': 'सुझाया गया मार्ग',
      'suggestedRouteBody': 'आपके लिए चुनी गई स्थानीय सैर',
      'communityTitle': 'अपना समुदाय खोजें',
      'communitySubtitle': 'मिलें, जुड़ें और अपनापन पाएँ',
      'trustedLeads': '{count} विश्वसनीय जानकारी',
      'welcomeDeskTitle': 'नए हैं? स्थानीय स्वागत मार्गदर्शिका से शुरू करें',
      'welcomeDeskBody':
          'लोगों, गतिविधियों और विश्वसनीय जानकारी की आसान मार्गदर्शिका।',
      'browseByInterest': 'रुचि के अनुसार देखें',
      'opportunity': 'अवसर',
      'opportunities': 'अवसर',
      'searchCommunity': 'गतिविधियाँ, समूह या रुचियाँ खोजें',
      'localAdventure': 'आपका स्थानीय सफ़र',
      'explorePrompt': 'आप कहाँ घूमना चाहेंगे?',
      'servicesTagline': 'विश्वास के साथ यहाँ बसें',
      'passportTitle': 'सामुदायिक पासपोर्ट',
      'passportTagline': 'खोजें · स्कैन करें · संग्रह करें',
      'exploreAreaTitle': 'खोजें',
      'exploreAreaSubtitle': 'मानचित्र, मार्ग और स्थानीय स्थान खोजें',
      'understandAreaTitle': 'समझें',
      'understandAreaSubtitle':
          'विश्वसनीय स्थानीय सेवाएँ और नागरिक जानकारी पाएँ',
      'connectAreaTitle': 'जुड़ें',
      'connectAreaSubtitle': 'कार्यक्रम, समूह और भाग लेने के तरीके खोजें',
      'engageAreaTitle': 'भाग लें',
      'engageAreaSubtitle': 'बैज और QR खोजों से अपना सामुदायिक पासपोर्ट बनाएँ',
      'scanDiscover': 'स्कैन करें और खोजें',
      'scanTagline': 'आपका अगला पुरस्कार आपका इंतज़ार कर रहा है',
      'helloName': 'नमस्ते, {name}',
      'profileAdventure': 'कनाडा बे की आपकी यात्रा यहाँ से शुरू होती है',
      'servicesSearch': 'कचरा, पार्किंग, पुस्तकालय या शौचालय खोजें',
      'levelNumber': 'स्तर {number}',
      'home': 'होम',
      'explore': 'खोजें',
      'community': 'समुदाय',
      'services': 'स्थानीय सेवाएँ',
      'passport': 'सामुदायिक पासपोर्ट',
      'scan': 'स्कैन',
      'profile': 'प्रोफ़ाइल',
      'continue': 'आगे बढ़ें',
      'welcomeTitle': 'कनाडा बे को अपना घर बनाएँ',
      'welcomeBody':
          'स्थानीय सेवाएँ, सामुदायिक गतिविधियाँ और उपयोगी स्थान खोजें।',
      'aboutYou': 'हमें बताएँ कि आप यहाँ क्यों आए हैं',
      'interests': 'बसने में आपको किससे मदद मिलेगी?',
      'language': 'भाषा',
      'newResident': 'नए निवासी',
      'student': 'विद्यार्थी',
      'family': 'परिवार',
      'professional': 'युवा पेशेवर',
      'retiree': 'सेवानिवृत्त',
      'communityInterest': 'समुदाय',
      'outdoorsInterest': 'बाहरी गतिविधियाँ',
      'environmentInterest': 'पर्यावरण',
      'foodInterest': 'स्थानीय भोजन',
      'servicesInterest': 'स्थानीय सेवाएँ',
      'weekday1': 'सोमवार',
      'weekday2': 'मंगलवार',
      'weekday3': 'बुधवार',
      'weekday4': 'गुरुवार',
      'weekday5': 'शुक्रवार',
      'weekday6': 'शनिवार',
      'weekday7': 'रविवार',
      'modeTrain': 'ट्रेन',
      'modeBus': 'बस',
      'modeFerry': 'फ़ेरी',
      'modeLightRail': 'लाइट रेल',
      'modeBike': 'साइकिल',
      'modeWalk': 'पैदल',
      'modePublicTransport': 'सार्वजनिक परिवहन',
      'qrInvalidField': 'QR पुरस्कार का आवश्यक फ़ील्ड गायब या अमान्य है।',
      'qrFieldTooLong': 'QR पुरस्कार का एक फ़ील्ड बहुत लंबा है।',
      'qrInvalidNumber': 'QR पुरस्कार की संख्या अमान्य है।',
      'qrInvalidObject': 'QR पुरस्कार की संरचना अमान्य है।',
      'qrInvalidLink': 'QR पुरस्कार लिंक सुरक्षित वेब पता नहीं है।',
      'qrInvalidGeneric': 'यह कोड मान्य पासपोर्ट पुरस्कार नहीं है।',
      'rewardDuplicate':
          '{place} पहले ही स्कैन हो चुका है। कोई पुरस्कार नहीं जोड़ा गया।',
      'rewardBadge': '{badge} बैज खुल गया!',
      'rewardBadgeXp': '{badge} बैज खुल गया! +{xp} XP',
      'rewardProgress': '{place}: {badge} बैज प्रगति {progress}/{target}।',
      'rewardProgressXp':
          '{place} पर +{xp} XP और {badge} बैज प्रगति {progress}/{target}।',
      'rewardXp': '{place} पर +{xp} XP अर्जित।',
      'rewardAdded': '{place} आपके पासपोर्ट में जोड़ा गया।',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
