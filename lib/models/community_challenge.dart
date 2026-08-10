import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'passport.dart';

@immutable
class CommunityLeader {
  const CommunityLeader({
    required this.position,
    required this.alias,
    required this.points,
  });

  factory CommunityLeader.fromJson(Map<String, dynamic> json) {
    return CommunityLeader(
      position: _asInt(json['position']),
      alias: json['alias']?.toString() ?? 'Neighbour',
      points: _asInt(json['points']),
    );
  }

  final int position;
  final String alias;
  final int points;
}

@immutable
class CommunityChallengeSnapshot {
  const CommunityChallengeSnapshot({
    required this.id,
    required this.title,
    required this.description,
    required this.reward,
    required this.targetPoints,
    required this.communityPoints,
    required this.contributorCount,
    required this.personalPoints,
    required this.personalRank,
    required this.leaderboardOptIn,
    required this.leaders,
    this.endsAt,
  });

  factory CommunityChallengeSnapshot.fromJson(Map<String, dynamic> json) {
    final leadersSource = json['leaders'];
    return CommunityChallengeSnapshot(
      id: json['id']?.toString() ?? 'together-canada-bay',
      title: json['title']?.toString() ?? 'Together Canada Bay',
      description:
          json['description']?.toString() ??
          'Complete meaningful local activities and move the community forward together.',
      reward:
          json['reward']?.toString() ??
          'Unlock the Together Canada Bay digital celebration.',
      targetPoints: _asInt(json['target_points'], fallback: 2000),
      communityPoints: _asInt(json['community_points']),
      contributorCount: _asInt(json['contributor_count']),
      personalPoints: _asInt(json['personal_points']),
      personalRank: _asNullableInt(json['personal_rank']),
      leaderboardOptIn: json['leaderboard_opt_in'] == true,
      leaders: leadersSource is List
          ? leadersSource
                .whereType<Map>()
                .map(
                  (item) =>
                      CommunityLeader.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const <CommunityLeader>[],
      endsAt: DateTime.tryParse(json['ends_at']?.toString() ?? ''),
    );
  }

  static const offline = CommunityChallengeSnapshot(
    id: 'together-canada-bay',
    title: 'Together Canada Bay',
    description:
        'Complete meaningful local activities and move the community forward together.',
    reward: 'Unlock the Together Canada Bay digital celebration.',
    targetPoints: 2000,
    communityPoints: 0,
    contributorCount: 0,
    personalPoints: 0,
    personalRank: null,
    leaderboardOptIn: false,
    leaders: <CommunityLeader>[],
  );

  final String id;
  final String title;
  final String description;
  final String reward;
  final int targetPoints;
  final int communityPoints;
  final int contributorCount;
  final int personalPoints;
  final int? personalRank;
  final bool leaderboardOptIn;
  final List<CommunityLeader> leaders;
  final DateTime? endsAt;

  double get progress =>
      targetPoints <= 0 ? 0 : (communityPoints / targetPoints).clamp(0.0, 1.0);
  int get pointsRemaining =>
      (targetPoints - communityPoints).clamp(0, targetPoints);
  bool get completed => communityPoints >= targetPoints;
}

abstract interface class CommunityChallengeRepository {
  Future<CommunityChallengeSnapshot> fetchActiveChallenge();

  Future<void> recordActivity({
    required String activityId,
    required String activityKind,
  });

  Future<void> setLeaderboardOptIn(bool enabled);
}

class SupabaseCommunityChallengeRepository
    implements CommunityChallengeRepository {
  const SupabaseCommunityChallengeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CommunityChallengeSnapshot> fetchActiveChallenge() async {
    final response = await _client.rpc('get_active_community_challenge');
    if (response is! Map) {
      throw const FormatException(
        'The community challenge response is invalid.',
      );
    }
    return CommunityChallengeSnapshot.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  @override
  Future<void> recordActivity({
    required String activityId,
    required String activityKind,
  }) async {
    await _client.rpc(
      'record_community_activity',
      params: <String, dynamic>{
        'p_activity_id': activityId,
        'p_activity_kind': activityKind,
      },
    );
  }

  @override
  Future<void> setLeaderboardOptIn(bool enabled) async {
    await _client.rpc(
      'set_community_leaderboard_opt_in',
      params: <String, dynamic>{'p_enabled': enabled},
    );
  }
}

class CommunityChallengeController extends ChangeNotifier {
  factory CommunityChallengeController({
    required PassportController passport,
    CommunityChallengeRepository? repository,
    String? userId,
  }) {
    final controller = CommunityChallengeController._(
      passport,
      repository,
      userId,
    );
    passport.addListener(controller._handlePassportChanged);
    return controller;
  }

  CommunityChallengeController._(
    this._passport,
    this._repository,
    this._userId,
  );

  final PassportController _passport;
  final CommunityChallengeRepository? _repository;
  String? _userId;
  CommunityChallengeSnapshot _snapshot = CommunityChallengeSnapshot.offline;
  bool _loading = false;
  bool _syncing = false;
  bool _syncAgain = false;
  String? _error;

  CommunityChallengeSnapshot get snapshot => _snapshot;
  bool get loading => _loading;
  bool get isSignedIn => _userId != null;
  bool get cloudAvailable => _repository != null;
  String? get error => _error;

  Future<void> load() async {
    final repository = _repository;
    if (repository == null) {
      _snapshot = CommunityChallengeSnapshot.offline;
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _snapshot = await repository.fetchActiveChallenge();
      if (isSignedIn) await _syncPassportActivities();
    } on Object catch (error) {
      _error = error.toString();
      debugPrint('Community challenge could not be loaded: $error');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> switchAccount(String? userId) async {
    if (_userId == userId) return;
    _userId = userId;
    _snapshot = CommunityChallengeSnapshot.offline;
    notifyListeners();
    await load();
  }

  Future<void> refresh() => load();

  Future<void> setLeaderboardOptIn(bool enabled) async {
    if (!isSignedIn || _repository == null) return;
    _loading = true;
    notifyListeners();
    try {
      await _repository.setLeaderboardOptIn(enabled);
      _snapshot = await _repository.fetchActiveChallenge();
      _error = null;
    } on Object catch (error) {
      _error = error.toString();
      debugPrint('Leaderboard preference could not be saved: $error');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _handlePassportChanged() {
    if (isSignedIn) unawaited(_syncPassportActivities());
  }

  Future<void> _syncPassportActivities() async {
    final repository = _repository;
    if (repository == null || !isSignedIn) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncAgain = false;
        for (final record in _passport.scanHistory) {
          await repository.recordActivity(
            activityId: record.rewardId,
            activityKind: _kindFor(record),
          );
        }
        _snapshot = await repository.fetchActiveChallenge();
        _error = null;
        notifyListeners();
      } while (_syncAgain);
    } on Object catch (error) {
      _error = error.toString();
      debugPrint('Community contribution sync failed: $error');
      notifyListeners();
    } finally {
      _syncing = false;
    }
  }

  static String _kindFor(PassportScanRecord record) {
    if (record.isQrScan) return 'discovery';
    if (record.rewardId.startsWith('route-complete:')) return 'route';
    if (record.rewardId.startsWith('journey:')) return 'journey';
    return 'community';
  }

  @override
  void dispose() {
    _passport.removeListener(_handlePassportChanged);
    super.dispose();
  }
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _asNullableInt(Object? value) {
  if (value == null) return null;
  return value is int ? value : int.tryParse(value.toString());
}
