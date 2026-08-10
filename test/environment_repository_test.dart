import 'package:explore_canada_bay/models/environmental_story.dart';
import 'package:explore_canada_bay/services/environment_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'environment repository resolves the requested content locale',
    () async {
      final stories = await const EnvironmentRepository().loadStories(
        locale: const Locale('zh'),
      );

      expect(stories, hasLength(6));
      expect(stories.first.id, 'powells_creek_badu_mangroves');
      expect(stories.first.name, '鲍威尔斯溪与巴杜红树林');
      expect(stories.first.description, contains('城市湿地廊道'));
      expect(stories.first.officialUrl, startsWith('https://'));
    },
  );

  test('environment story falls back to canonical English content', () {
    final story = EnvironmentalStory.fromJson(const {
      'id': 'fixture',
      'name': 'Fixture habitat',
      'category': 'Habitat',
      'description': 'English description',
      'learningPrompt': 'English prompt',
      'lat': -33.8,
      'lng': 151.1,
      'officialUrl': 'https://example.com',
      'sourceLabel': 'Official source',
    });

    expect(story.localized(const Locale('ko')).name, 'Fixture habitat');
    expect(
      story.localized(const Locale('hi')).description,
      'English description',
    );
  });
}
