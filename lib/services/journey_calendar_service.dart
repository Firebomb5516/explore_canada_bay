import '../models/newcomer_journey.dart';
import 'external_link_service.dart';

class JourneyCalendarService {
  const JourneyCalendarService({this.links = const ExternalLinkService()});

  final ExternalLinkService links;

  Uri eventUri({
    required NewcomerJourneyTask task,
    required DateTime journeyStart,
    required int day,
  }) {
    final date = DateTime(
      journeyStart.year,
      journeyStart.month,
      journeyStart.day,
    ).add(Duration(days: day - 1));
    final end = date.add(const Duration(days: 1));
    String compact(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}';
    return Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': 'Explore Canada Bay: ${task.title}',
      'dates': '${compact(date)}/${compact(end)}',
      'details': task.summary,
    });
  }

  Future<bool> addGoal({
    required NewcomerJourneyTask task,
    required DateTime journeyStart,
    required int day,
  }) => links.open(
    eventUri(task: task, journeyStart: journeyStart, day: day).toString(),
  );
}
