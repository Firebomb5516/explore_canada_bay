import 'dart:async';
import 'dart:convert';

import 'package:explore_canada_bay/models/passport.dart';
import 'package:explore_canada_bay/models/settlement_profile.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPassportStore implements PassportStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _DelayedPassportStore extends _MemoryPassportStore {
  String? delayedOwner;
  Completer<void>? readGate;

  @override
  Future<String?> read(String key) async {
    if (delayedOwner != null && key.endsWith(delayedOwner!)) {
      await readGate?.future;
    }
    return super.read(key);
  }
}

const _progressReward =
    '{"namespace":"explore_canada_bay.passport","version":1,'
    '"rewardId":"cabarita-park-01","place":"Cabarita Park","xp":40,'
    '"badge":{"id":"nature_trail","name":"Nature Trail",'
    '"description":"Discover parks, wildlife and native habitats.",'
    '"category":"Nature","icon":"eco","color":"#00B87A",'
    '"target":5,"progress":1}}';

const _educationReward =
    '{"namespace":"explore_canada_bay.passport","version":1,'
    '"rewardId":"powells-creek-learning-01","place":"Powells Creek",'
    '"xp":0,"content":{"title":"Wetland habitat",'
    '"body":"Mangroves and saltmarsh provide habitat for local wildlife.",'
    '"category":"Environment",'
    '"officialUrl":"https://www.canadabay.nsw.gov.au/"}}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Passport QR rewards', () {
    test('a new passport starts at zero XP', () {
      final passport = PassportController(store: _MemoryPassportStore());

      expect(passport.totalXp, 0);
      expect(passport.level, 1);
      expect(passport.totalScans, 0);
    });

    test('loads badge collections from the asset catalogue', () async {
      final passport = PassportController(store: _MemoryPassportStore());

      await passport.load();

      expect(passport.badges.length, greaterThanOrEqualTo(10));
      expect(
        passport.badges.map((badge) => badge.collection).toSet(),
        containsAll({
          'Outdoor Explorer',
          'Local Life',
          'Community Life',
          'Culture and Stories',
          'Settling In',
        }),
      );
      expect(passport.badges.every((badge) => badge.progress == 0), isTrue);
    });

    test('parses a valid self-contained badge-progress reward', () {
      final reward = PassportQrReward.parse(_progressReward);

      expect(reward.rewardId, 'cabarita-park-01');
      expect(reward.placeName, 'Cabarita Park');
      expect(reward.xp, 40);
      expect(reward.badge?.id, 'nature_trail');
      expect(reward.badge?.progress, 1);
    });

    test('rejects codes from another namespace', () {
      const invalid =
          '{"namespace":"another.app","version":1,'
          '"rewardId":"bad-code","place":"Nowhere","xp":20}';

      expect(
        () => PassportQrReward.parse(invalid),
        throwsA(isA<FormatException>()),
      );
    });

    test('parses place-linked educational QR content', () {
      final reward = PassportQrReward.parse(_educationReward);

      expect(reward.content?.title, 'Wetland habitat');
      expect(reward.content?.category, 'Environment');
      expect(reward.content?.officialUrl, contains('canadabay.nsw.gov.au'));
    });

    test('persists educational content for later discovery details', () async {
      final store = _MemoryPassportStore();
      final passport = PassportController(store: store);
      await passport.load();

      await passport.applyQrPayload(_educationReward);

      final restored = PassportController(store: store);
      await restored.load();
      final discovery = restored.scanHistory.single;
      expect(discovery.content?.title, 'Wetland habitat');
      expect(discovery.content?.body, contains('Mangroves'));
      expect(discovery.content?.officialUrl, contains('canadabay.nsw.gov.au'));
    });

    test('rejects unsafe educational links from QR content', () {
      const invalid =
          '{"namespace":"explore_canada_bay.passport","version":1,'
          '"rewardId":"unsafe-link-01","place":"Unknown place","xp":0,'
          '"content":{"title":"Unsafe","body":"Do not open this.",'
          '"category":"Other","officialUrl":"javascript:alert(1)"}}';

      expect(
        () => PassportQrReward.parse(invalid),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects badges outside the trusted catalogue', () async {
      const invalid =
          '{"namespace":"explore_canada_bay.passport","version":1,'
          '"rewardId":"invented-badge-01","place":"Unknown place","xp":10,'
          '"badge":{"id":"invented_badge","name":"Invented Badge",'
          '"description":"Not in badges.json.","category":"Other",'
          '"icon":"star","color":"#FFFFFF","target":1,"progress":1}}';
      final passport = PassportController(store: _MemoryPassportStore());
      await passport.load();

      await expectLater(
        passport.applyQrPayload(invalid),
        throwsA(isA<FormatException>()),
      );
    });

    test('applies a reward once and blocks duplicate claims', () async {
      final passport = PassportController(store: _MemoryPassportStore());

      final first = await passport.applyQrPayload(_progressReward);
      final duplicate = await passport.applyQrPayload(_progressReward);

      expect(first.duplicate, isFalse);
      expect(first.xpAwarded, 40);
      expect(passport.totalXp, PassportController.baselineXp + 40);
      expect(passport.badges.first.progress, 1);
      expect(passport.totalScans, 1);
      expect(duplicate.duplicate, isTrue);
      expect(duplicate.xpAwarded, 0);
      expect(passport.totalXp, PassportController.baselineXp + 40);
    });

    test(
      'English QR badge data resolves through the translated catalogue',
      () async {
        final passport = PassportController(store: _MemoryPassportStore());
        await passport.load();

        final result = await passport.applyQrPayload(_progressReward);

        expect(result.badge?.localizedName('zh'), '自然步道');
        expect(result.badge?.localizedName('ko'), '자연 탐방로');
        expect(result.badge?.localizedName('it'), 'Sentiero natura');
        expect(result.badge?.localizedName('hi'), 'प्रकृति पथ');
        expect(result.badge?.localizedDescription('zh'), contains('加拿大湾'));
      },
    );

    test('supports a QR code that unlocks a badge immediately', () async {
      const unlockReward =
          '{"namespace":"explore_canada_bay.passport","version":1,'
          '"rewardId":"heritage-special-01","place":"Yaralla Estate",'
          '"xp":100,"badge":{"id":"heritage_hunter",'
          '"name":"Heritage Hunter",'
          '"description":"Uncover local landmark stories.",'
          '"category":"Heritage","icon":"museum","color":"#5FA8FF",'
          '"target":4,"progress":1,"unlock":true}}';
      final passport = PassportController(store: _MemoryPassportStore());

      final result = await passport.applyQrPayload(unlockReward);

      expect(result.badgeJustEarned, isTrue);
      expect(result.badge?.earned, isTrue);
      expect(result.badge?.progress, 4);
    });

    test('records in-app learning without inflating QR scan totals', () async {
      final passport = PassportController(store: _MemoryPassportStore());
      await passport.load();

      await passport.recordActivity(
        activityId: 'journey:water-safety',
        placeName: 'Water safety',
        points: 0,
        badgeId: 'water_wise',
      );

      expect(passport.hasActivity('journey:water-safety'), isTrue);
      expect(passport.badgeProgress('water_wise'), 1);
      expect(passport.totalScans, 0);
      expect(passport.scanHistory.single.source, 'activity');
    });

    test('persists stable localization metadata for app activities', () async {
      final store = _MemoryPassportStore();
      final passport = PassportController(store: store);
      await passport.load();

      await passport.recordActivity(
        activityId: 'journey:plan-first-trip',
        placeName: 'Usual transport stop saved',
        points: 0,
        content: const PassportQrContent(
          title: 'Usual transport stop saved',
          body: 'Rhodes is saved as your Train starting point.',
          category: 'Local essentials',
          localizationId: 'journey.practical:plan-first-trip',
          localizationArgs: {'stop': 'Rhodes', 'mode': 'Train'},
        ),
      );

      final restored = PassportController(store: store);
      await restored.load();
      final content = restored.scanHistory.single.content;
      expect(content?.localizationId, 'journey.practical:plan-first-trip');
      expect(content?.localizationArgs, {'stop': 'Rhodes', 'mode': 'Train'});
    });

    test('keeps each account passport in separate storage', () async {
      final store = _MemoryPassportStore();
      final firstAccount = PassportController(
        store: store,
        ownerId: 'alex@example.com',
      );
      await firstAccount.applyQrPayload(_progressReward);

      final secondAccount = PassportController(
        store: store,
        ownerId: 'sam@example.com',
      );
      await secondAccount.load();

      expect(firstAccount.totalXp, 40);
      expect(secondAccount.totalXp, 0);
      expect(secondAccount.totalScans, 0);
    });

    test('can switch passport owners without leaking progress', () async {
      final store = _MemoryPassportStore();
      final passport = PassportController(store: store, ownerId: 'guest');
      await passport.load();
      await passport.applyQrPayload(_progressReward);

      await passport.switchOwner('resident@example.com');
      expect(passport.totalXp, 0);
      expect(passport.totalScans, 0);

      await passport.switchOwner('guest');
      expect(passport.totalXp, 40);
      expect(passport.totalScans, 1);
    });

    test('discards a stale owner load during rapid account switches', () async {
      final store = _DelayedPassportStore();
      final passport = PassportController(store: store, ownerId: 'guest');
      await passport.load();
      await passport.applyQrPayload(_progressReward);

      store.delayedOwner = base64Url
          .encode(utf8.encode('resident@example.com'))
          .replaceAll('=', '');
      store.readGate = Completer<void>();

      final staleSwitch = passport.switchOwner('resident@example.com');
      expect(passport.totalXp, 0);
      expect(passport.totalScans, 0);

      final currentSwitch = passport.switchOwner('guest');
      await currentSwitch;
      expect(passport.totalXp, 40);
      expect(passport.totalScans, 1);

      store.readGate!.complete();
      await staleSwitch;
      expect(passport.totalXp, 40);
      expect(passport.totalScans, 1);
    });

    test('debug tool unlocks badges and featured choices persist', () async {
      final store = _MemoryPassportStore();
      final passport = PassportController(store: store, ownerId: 'developer');
      await passport.load();

      await passport.applyQrPayload(PassportController.debugUnlockAllCode);
      expect(passport.badges.every((badge) => badge.earned), isTrue);

      final rareBadge = passport.badges.firstWhere(
        (badge) => badge.rarity == 'Rare',
      );
      await passport.toggleFeaturedBadge(rareBadge.id);

      final restored = PassportController(store: store, ownerId: 'developer');
      await restored.load();
      expect(restored.featuredBadgeIds, [rareBadge.id]);
    });
  });

  test('blank Council issue type is stored as a stable default ID', () async {
    final settlement = SettlementProfileController.memory();

    await settlement.saveCouncilReport(reference: 'CB-123', type: '  ');

    expect(
      settlement.councilReportType,
      SettlementProfileController.defaultCouncilIssueType,
    );
    expect(
      SettlementProfileController.isDefaultCouncilIssueType('Council issue'),
      isTrue,
      reason: 'legacy saved values remain compatible',
    );
  });
}
