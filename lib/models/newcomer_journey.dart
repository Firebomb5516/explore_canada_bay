import 'package:flutter/foundation.dart';

enum JourneyTaskKind {
  learn,
  civic,
  explore,
  community;

  static JourneyTaskKind parse(String value) =>
      JourneyTaskKind.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () =>
            throw FormatException('Unknown journey task kind "$value".'),
      );
}

enum JourneyVerification {
  self,
  qr,
  route;

  static JourneyVerification parse(String value) =>
      JourneyVerification.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () =>
            throw FormatException('Unknown journey verification "$value".'),
      );
}

@immutable
class NewcomerJourneyTask {
  const NewcomerJourneyTask({
    required this.id,
    required this.title,
    required this.summary,
    required this.section,
    required this.kind,
    required this.verification,
    required this.actionLabel,
    required this.badgeId,
    required this.xp,
    required this.sortOrder,
    this.officialUrl,
    this.destination,
  });

  factory NewcomerJourneyTask.fromJson(Map<String, dynamic> json) {
    final officialUrl = _optionalString(json, 'officialUrl');
    if (officialUrl != null) {
      final uri = Uri.tryParse(officialUrl);
      if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
        throw FormatException(
          'Journey task "${json['id']}" must use a valid HTTPS officialUrl.',
        );
      }
    }

    final xp = _requiredInt(json, 'xp');
    if (xp < 0 || xp > 200) {
      throw FormatException('Journey task XP must be between 0 and 200.');
    }

    return NewcomerJourneyTask(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      summary: _requiredString(json, 'summary'),
      section: _requiredString(json, 'section'),
      kind: JourneyTaskKind.parse(_requiredString(json, 'kind')),
      verification: JourneyVerification.parse(
        _requiredString(json, 'verification'),
      ),
      actionLabel: _requiredString(json, 'actionLabel'),
      badgeId: _requiredString(json, 'badgeId'),
      xp: xp,
      sortOrder: _requiredInt(json, 'sortOrder'),
      officialUrl: officialUrl,
      destination: _optionalString(json, 'destination'),
    );
  }

  final String id;
  final String title;
  final String summary;
  final String section;
  final JourneyTaskKind kind;
  final JourneyVerification verification;
  final String actionLabel;
  final String badgeId;
  final int xp;
  final int sortOrder;
  final String? officialUrl;
  final String? destination;

  String get activityId => 'journey:$id';
  bool get canSelfComplete => verification == JourneyVerification.self;
}

@immutable
class NewcomerJourneyCatalog {
  const NewcomerJourneyCatalog({
    required this.schemaVersion,
    required this.lastReviewed,
    required this.tasks,
  });

  factory NewcomerJourneyCatalog.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schemaVersion');
    if (schemaVersion != 1) {
      throw FormatException(
        'Unsupported newcomer journey schema version $schemaVersion.',
      );
    }
    final lastReviewed = DateTime.tryParse(
      _requiredString(json, 'lastReviewed'),
    );
    if (lastReviewed == null) {
      throw const FormatException('Journey lastReviewed must be an ISO date.');
    }
    final rawTasks = json['tasks'];
    if (rawTasks is! List || rawTasks.isEmpty) {
      throw const FormatException('Journey catalogue must contain tasks.');
    }
    final tasks = rawTasks.map((raw) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Every journey task must be an object.');
      }
      return NewcomerJourneyTask.fromJson(raw);
    }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final ids = <String>{};
    if (tasks.any((task) => !ids.add(task.id))) {
      throw const FormatException('Journey tasks contain duplicate IDs.');
    }
    return NewcomerJourneyCatalog(
      schemaVersion: schemaVersion,
      lastReviewed: lastReviewed,
      tasks: List.unmodifiable(tasks),
    );
  }

  final int schemaVersion;
  final DateTime lastReviewed;
  final List<NewcomerJourneyTask> tasks;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Journey field "$key" must be text.');
  }
  return value.trim();
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Journey field "$key" must be text.');
  }
  return value.trim();
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Journey field "$key" must be an integer.');
  }
  return value;
}
