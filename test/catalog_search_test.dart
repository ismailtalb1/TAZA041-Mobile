import 'package:flutter_test/flutter_test.dart';
import 'package:taza041_flutter_customer_mobile/src/core/catalog_search.dart';
import 'package:taza041_flutter_customer_mobile/src/models.dart';

void main() {
  const crispy = Product(
    id: '1',
    nameAr: 'دجاج مقرمش',
    nameEn: 'Crispy Chicken',
    descriptionAr: 'وجبة دجاج شهية',
    descriptionEn: 'Crunchy chicken meal',
    category: ProductCategory.meal,
    price: 250,
    rating: 4.8,
    ratingCount: 12,
  );
  const burger = Product(
    id: '2',
    nameAr: 'برغر لحم',
    nameEn: 'Beef Burger',
    descriptionAr: 'برغر مشوي',
    descriptionEn: 'Grilled burger',
    category: ProductCategory.sandwich,
    price: 300,
    rating: 4.4,
    ratingCount: 8,
  );

  group('CatalogSearch', () {
    test('normalizes Arabic letter variants and diacritics', () {
      expect(CatalogSearch.normalize('دَجَاج مَقْرَمِش'), 'دجاج مقرمش');
      expect(CatalogSearch.normalize('وجبة لذيذة'), 'وجبه لذيذه');
    });

    test('recovers from an English typo and suggests the closest name', () {
      final matches = CatalogSearch.rank(const [burger, crispy], 'krispe');

      expect(matches, isNotEmpty);
      expect(matches.first.product.id, crispy.id);
      expect(
        CatalogSearch.bestCorrection(matches, 'krispe', arabic: false),
        crispy.nameEn,
      );
    });

    test('keeps direct Arabic matches ahead of unrelated products', () {
      final matches = CatalogSearch.rank(const [burger, crispy], 'دجاج');

      expect(matches.first.product.id, crispy.id);
      expect(matches.first.fuzzy, isFalse);
    });
  });
}
