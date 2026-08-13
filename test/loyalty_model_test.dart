import 'package:flutter_test/flutter_test.dart';
import 'package:taza041_flutter_customer_mobile/src/app_state.dart';
import 'package:taza041_flutter_customer_mobile/src/models.dart';

void main() {
  test('customer loyalty payload carries the configured tier catalog', () {
    final user = AppUser.fromJson(
      {
        'id': 41,
        'name': 'Loyal Customer',
        'email': 'loyal@example.test',
      },
      loyalty: {
        'points_balance': 725,
        'tier': 'gold',
        'earning_multiplier': 1.8,
        'tier_progress': 8.3,
        'points_to_next_tier': 275,
        'tier_catalog': [
          {
            'key': 'gold',
            'name_ar': 'ذهبي',
            'name_en': 'Gold',
            'minimum_points': 700,
            'earning_multiplier': 1.8,
          },
        ],
      },
    );

    expect(user.loyaltyPoints, 725);
    expect(user.loyaltyTier, 'gold');
    expect(user.loyaltyMultiplier, 1.8);
    expect(user.loyaltyProgress, 8.3);
    expect(user.pointsToNextTier, 275);
    expect(user.loyaltyTiers.single['earning_multiplier'], 1.8);
  });

  test('mobile estimate uses the active server multiplier', () {
    final state = AppState()
      ..currentUser = AppUser(
        fullName: 'Gold Customer',
        email: '',
        phone: '',
        loyaltyPoints: 700,
        loyaltyTier: 'gold',
        loyaltyMultiplier: 1.8,
      );
    addTearDown(state.dispose);

    expect(state.loyaltyPointsForAmount(100), 18);
  });
}
