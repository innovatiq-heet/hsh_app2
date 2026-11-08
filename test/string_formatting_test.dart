import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/core/utils/string_formatting.dart';

void main() {
  group('formatPersonName', () {
    test('Capitalizes fully uppercase names into proper Title Case', () {
      expect(
        formatPersonName('PATEL HARSHIL MAHESHBHAI'),
        'Patel Harshil Maheshbhai',
      );
      expect(formatPersonName('SHAH MEET'), 'Shah Meet');
    });

    test('Capitalizes fully lowercase names into proper Title Case', () {
      expect(
        formatPersonName('patel harshil maheshbhai'),
        'Patel Harshil Maheshbhai',
      );
      expect(formatPersonName('shah meet'), 'Shah Meet');
    });

    test('Fixes mixed / irregular casing and collapses multiple spaces', () {
      expect(
        formatPersonName('  pAtEl    hArShIl   mAhEsHbHaI  '),
        'Patel Harshil Maheshbhai',
      );
      expect(formatPersonName('rAmEsH'), 'Ramesh');
    });

    test('Handles single-word names and initials with dots', () {
      expect(formatPersonName('a'), 'A');
      expect(formatPersonName('A.B. PATEL'), 'A.B. Patel');
      expect(formatPersonName('A. B. patel'), 'A. B. Patel');
    });

    test('Handles hyphens, apostrophes, and parentheses', () {
      expect(formatPersonName('MARY-JANE'), 'Mary-Jane');
      expect(formatPersonName('o\'connor'), 'O\'Connor');
      expect(formatPersonName('HARSH (MUNNA) PATEL'), 'Harsh (Munna) Patel');
      expect(formatPersonName('RAM-PRASAD SHARMA'), 'Ram-Prasad Sharma');
    });

    test('Returns empty string on null or whitespace', () {
      expect(formatPersonName(null), '');
      expect(formatPersonName(''), '');
      expect(formatPersonName('   '), '');
    });
  });
}
