import 'package:bumpbuddy/faq_content.dart';
import 'package:bumpbuddy/models.dart';
import 'package:bumpbuddy/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FAQ content is well-formed and covers twins', () {
    expect(kFaq.length, greaterThan(15));
    expect(faqCategories, contains('Twins'));
    for (final f in kFaq) {
      expect(f.question.trim(), isNotEmpty);
      expect(f.answer.trim().length, greaterThan(30));
    }
  });

  test('saved answers toggle + persist round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();

    expect(store.isAnswerSaved('A20 weighs 400g'), isFalse);
    await store.toggleSavedAnswer('How big?', 'A20 weighs 400g');
    expect(store.isAnswerSaved('A20 weighs 400g'), isTrue);
    expect(store.savedAnswers.single.question, 'How big?');

    // Reload a fresh store from the same prefs — it must survive.
    final reloaded = AppStore();
    await reloaded.load();
    expect(reloaded.isAnswerSaved('A20 weighs 400g'), isTrue);

    await reloaded.toggleSavedAnswer('How big?', 'A20 weighs 400g');
    expect(reloaded.savedAnswers, isEmpty);
  });
}
