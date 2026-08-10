import 'package:flutter/widgets.dart';

import '../models/passport.dart';
import '../models/settlement_profile.dart';
import 'journey_localizations.dart';

/// Display copy for an app-authored Journey activity.
///
/// Passport records retain their original text for backwards compatibility,
/// while known Journey IDs are resolved in the active language at render time.
@immutable
class LocalizedJourneyActivity {
  const LocalizedJourneyActivity({required this.placeName, this.content});

  final String placeName;
  final PassportQrContent? content;
}

class JourneyActivityLocalizations {
  const JourneyActivityLocalizations._(this._copy);

  factory JourneyActivityLocalizations.of(BuildContext context) =>
      JourneyActivityLocalizations._(JourneyLocalizations.of(context));

  factory JourneyActivityLocalizations.forLocale(Locale locale) =>
      JourneyActivityLocalizations._(JourneyLocalizations.forLocale(locale));

  final JourneyLocalizations _copy;

  static const _practicalTitleKeys = <String, String>{
    'find-bin-day': 'binActivityTitle',
    'discover-library': 'libraryActivityTitle',
    'plan-first-trip': 'transportActivityTitle',
  };

  static const _canonicalTaskTitles = <String, String>{
    'know-triple-zero': 'Know when to call Triple Zero',
    'use-an-interpreter': 'Know how to ask for an interpreter',
    'find-bin-day': 'Find your bin collection information',
    'plan-first-trip': 'Plan a local public transport trip',
    'discover-library': 'Join your local library',
    'check-medicare': 'Check your Medicare eligibility',
    'know-rental-rights': 'Understand your rights when renting',
    'find-english-support': 'Find free English-learning support',
    'swim-between-flags': 'Understand the beach flags',
    'home-pool-safety': 'Make pools safer for children',
    'complete-local-route': 'Complete a Canada Bay route',
    'join-community-activity': 'Join a community activity',
    'help-local-environment': 'Help care for a local place',
  };

  static const _canonicalTaskSummaries = <String, String>{
    'know-triple-zero':
        'Learn when 000 is appropriate and where to get non-urgent police or NSW SES help.',
    'use-an-interpreter':
        'Learn how to request language support when contacting government and essential services.',
    'find-bin-day':
        'Check collection days and learn what belongs in each household bin.',
    'plan-first-trip':
        'Use the official Trip Planner to understand nearby train, bus and ferry options.',
    'discover-library':
        'Explore free membership, find your nearest branch and save a safe card reference in your Passport.',
    'check-medicare':
        'Understand who can enrol, which documents are needed and how to apply through myGov.',
    'know-rental-rights':
        'Learn the basics of leases, bonds, repairs, rent payments and getting help with a tenancy problem.',
    'find-english-support':
        'Check whether the Adult Migrant English Program, online learning or a local conversation group suits you.',
    'swim-between-flags':
        'Red and yellow flags mark the supervised swimming area. Learn the other warnings before entering the water.',
    'home-pool-safety':
        'Learn active supervision, closed self-latching gates, compliant fencing and why CPR skills matter.',
    'complete-local-route':
        'Choose a mapped GPX route and experience the foreshore, parks and neighbourhoods on foot.',
    'join-community-activity':
        'Attend a library program, local event, club activity or welcoming community session.',
    'help-local-environment':
        'Discover Bushcare, Love Your Place or another supervised environmental volunteering opportunity.',
  };

  LocalizedJourneyActivity resolve(
    PassportScanRecord record, {
    SettlementProfileController? settlement,
  }) {
    if (record.source != 'activity' ||
        !record.rewardId.startsWith('journey:')) {
      return LocalizedJourneyActivity(
        placeName: record.placeName,
        content: record.content,
      );
    }

    final taskId = record.rewardId.substring('journey:'.length);
    final content = record.content;
    final localizationId = content?.localizationId;
    final practical =
        localizationId == 'journey.practical:$taskId' ||
        (localizationId == null &&
            _practicalTitleKeys.containsKey(taskId) &&
            content?.officialUrl == null);

    if (practical) {
      return _resolvePractical(taskId, record: record, settlement: settlement);
    }

    if (!_copy.hasTask(taskId)) {
      return LocalizedJourneyActivity(
        placeName: record.placeName,
        content: content,
      );
    }

    final title =
        _copy.titleForTaskId(taskId) ??
        _canonicalTaskTitles[taskId] ??
        record.placeName;
    if (content == null) {
      return LocalizedJourneyActivity(placeName: title);
    }
    return LocalizedJourneyActivity(
      placeName: title,
      content: PassportQrContent(
        title: title,
        body:
            _copy.summaryForTaskId(taskId) ??
            _canonicalTaskSummaries[taskId] ??
            content.body,
        category: _copy.sectionForTaskId(taskId) ?? content.category,
        officialUrl: content.officialUrl,
        localizationId: 'journey.task:$taskId',
        localizationArgs: content.localizationArgs,
      ),
    );
  }

  LocalizedJourneyActivity _resolvePractical(
    String taskId, {
    required PassportScanRecord record,
    required SettlementProfileController? settlement,
  }) {
    final content = record.content;
    final titleKey = _practicalTitleKeys[taskId];
    final title = titleKey == null ? record.placeName : _copy.ui(titleKey);
    if (content == null) {
      return LocalizedJourneyActivity(placeName: title);
    }

    final args = content.localizationArgs;
    var body = content.body;
    switch (taskId) {
      case 'find-bin-day':
        final weekday =
            int.tryParse(args['weekday'] ?? '') ??
            settlement?.binCollectionWeekday;
        if (weekday != null) {
          body = _copy.message('binActivityBody', {
            'day': _copy.weekday(weekday),
          });
        }
        break;
      case 'discover-library':
        body = _copy.ui('libraryActivityBody');
        break;
      case 'plan-first-trip':
        final stop = args['stop'] ?? settlement?.transportStop;
        final mode = args['mode'] ?? settlement?.transportMode;
        if (stop != null && mode != null) {
          body = _copy.message('transportActivityBody', {
            'stop': stop,
            'mode': _copy.transportMode(mode),
          });
        }
        break;
    }

    return LocalizedJourneyActivity(
      placeName: title,
      content: PassportQrContent(
        title: title,
        body: body,
        category: _copy.ui('localEssentials'),
        officialUrl: content.officialUrl,
        localizationId: 'journey.practical:$taskId',
        localizationArgs: args,
      ),
    );
  }
}
