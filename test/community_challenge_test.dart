import 'package:explore_canada_bay/models/community_challenge.dart';
import 'package:explore_canada_bay/models/passport.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPassportStore implements PassportStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _FakeChallengeRepository implements CommunityChallengeRepository {
  final Map<String, String> activities = <String, String>{};
  bool optedIn = false;

  int get points => activities.values.fold(0, (total, kind) {
    return total +
        switch (kind) {
          'discovery' => 10,
          'route' => 25,
          'journey' => 5,
          _ => 15,
        };
  });

  @override
  Future<CommunityChallengeSnapshot> fetchActiveChallenge() async {
    return CommunityChallengeSnapshot.fromJson(<String, dynamic>{
      'id': 'test-challenge',
      'title': 'Together Canada Bay',
      'description': 'Test challenge',
      'reward': 'Test reward',
      'target_points': 100,
      'community_points': points,
      'contributor_count': points == 0 ? 0 : 1,
      'personal_points': points,
      'personal_rank': points == 0 ? null : 1,
      'leaderboard_opt_in': optedIn,
      'leaders': optedIn
          ? <Map<String, dynamic>>[
              <String, dynamic>{
                'position': 1,
                'alias': 'Neighbour TEST',
                'points': points,
              },
            ]
          : <Map<String, dynamic>>[],
    });
  }

  @override
  Future<void> recordActivity({
    required String activityId,
    required String activityKind,
  }) async {
    activities.putIfAbsent(activityId, () => activityKind);
  }

  @override
  Future<void> setLeaderboardOptIn(bool enabled) async {
    optedIn = enabled;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'signed-in Passport activities feed the shared challenge once',
    () async {
      final passport = PassportController(
        store: _MemoryPassportStore(),
        ownerId: 'resident-id',
      );
      await passport.load();
      await passport.recordActivity(
        activityId: 'route-complete:bay-run',
        placeName: 'Bay Run',
        points: 120,
        badgeId: 'foreshore_walker',
      );
      await passport.recordActivity(
        activityId: 'journey:meet-community',
        placeName: 'First 30 Days',
        points: 20,
        badgeId: 'community_participant',
      );

      final repository = _FakeChallengeRepository();
      final controller = CommunityChallengeController(
        passport: passport,
        repository: repository,
        userId: 'resident-id',
      );
      await controller.load();
      await controller.load();

      expect(repository.activities, <String, String>{
        'route-complete:bay-run': 'route',
        'journey:meet-community': 'journey',
      });
      expect(controller.snapshot.personalPoints, 30);
      expect(controller.snapshot.communityPoints, 30);
      controller.dispose();
    },
  );

  test('leaderboard is private until a signed-in person opts in', () async {
    final passport = PassportController(store: _MemoryPassportStore());
    await passport.load();
    final repository = _FakeChallengeRepository();
    final controller = CommunityChallengeController(
      passport: passport,
      repository: repository,
      userId: 'resident-id',
    );
    await controller.load();

    expect(controller.snapshot.leaderboardOptIn, isFalse);
    expect(controller.snapshot.leaders, isEmpty);

    await controller.setLeaderboardOptIn(true);

    expect(controller.snapshot.leaderboardOptIn, isTrue);
    expect(controller.snapshot.leaders.single.alias, 'Neighbour TEST');
    controller.dispose();
  });

  test(
    'guest mode keeps the challenge available without cloud writes',
    () async {
      final passport = PassportController(store: _MemoryPassportStore());
      await passport.load();
      final controller = CommunityChallengeController(passport: passport);

      await controller.load();

      expect(controller.cloudAvailable, isFalse);
      expect(controller.snapshot.title, 'Together Canada Bay');
      expect(controller.snapshot.communityPoints, 0);
      controller.dispose();
    },
  );
}
