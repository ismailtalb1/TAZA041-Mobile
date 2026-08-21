import 'package:flutter_test/flutter_test.dart';
import 'package:taza041_flutter_customer_mobile/src/models.dart';

void main() {
  test('meal suggestion parses review status and manager note', () {
    final suggestion = MealSuggestion.fromJson({
      'id': 41,
      'suggestion_text': 'وجبة موسمية جديدة',
      'image_url': '/storage/meal-suggestions/example.webp',
      'status': 'reviewed',
      'status_label': 'تمت المراجعة',
      'admin_note': 'الفكرة مناسبة للموسم القادم',
      'created_at': '2026-08-21T12:00:00Z',
      'updated_at': '2026-08-21T13:00:00Z',
    });

    expect(suggestion.id, '41');
    expect(suggestion.status, MealSuggestionStatus.reviewed);
    expect(suggestion.adminNote, 'الفكرة مناسبة للموسم القادم');
    expect(suggestion.imageUrl, contains('/storage/meal-suggestions/'));
  });

  test('notification exposes linked meal suggestion separately from catalog',
      () {
    final notification = NotificationItem.fromJson({
      'id': 8,
      'type': 'system_announcement',
      'title': 'تمت مراجعة اقتراحك',
      'message': 'افتح الفكرة لمشاهدة الرد',
      'data': {'suggestion_id': 41},
      'is_read': false,
    });

    expect(notification.isMealSuggestionUpdate, isTrue);
    expect(notification.isCatalogUpdate, isFalse);
    expect(notification.linkedSuggestionId, '41');
  });
}
