/// Utility class to convert numbers to Arabic words
class ArabicNumberToWords {
  static const List<String> ones = [
    '',
    'واحد',
    'اثنان',
    'ثلاثة',
    'أربعة',
    'خمسة',
    'ستة',
    'سبعة',
    'ثمانية',
    'تسعة',
    'عشرة',
    'أحد عشر',
    'اثنا عشر',
    'ثلاثة عشر',
    'أربعة عشر',
    'خمسة عشر',
    'ستة عشر',
    'سبعة عشر',
    'ثمانية عشر',
    'تسعة عشر',
  ];

  static const List<String> tens = [
    '',
    '',
    'عشرون',
    'ثلاثون',
    'أربعون',
    'خمسون',
    'ستون',
    'سبعون',
    'ثمانون',
    'تسعون',
  ];

  static const List<String> hundreds = [
    '',
    'مائة',
    'مائتان',
    'ثلاثمائة',
    'أربعمائة',
    'خمسمائة',
    'ستمائة',
    'سبعمائة',
    'ثمانمائة',
    'تسعمائة',
  ];

  static String convert(double number, String currencyName) {
    if (number == 0) {
      return 'صفر $currencyName لا غير';
    }

    final parts = number.toString().split('.');
    final wholePart = int.parse(parts[0]);
    final decimalPart = parts.length > 1 ? int.parse(parts[1].padRight(2, '0').substring(0, 2)) : 0;

    String result = _convertNumber(wholePart);
    result += ' $currencyName';

    if (decimalPart > 0) {
      final decimalWords = _convertNumber(decimalPart);
      if (decimalWords.isNotEmpty) {
        result += ' و $decimalWords من مائة';
      }
    }

    result += ' لا غير';

    return result;
  }

  static String _convertNumber(int number) {
    if (number == 0) return '';
    if (number < 20) return ones[number];

    String result = '';

    // Handle thousands
    if (number >= 1000) {
      final thousands = number ~/ 1000;
      if (thousands == 1) {
        result += 'ألف';
      } else if (thousands == 2) {
        result += 'ألفان';
      } else if (thousands >= 3 && thousands <= 10) {
        result += ones[thousands] + ' آلاف';
      } else if (thousands < 100) {
        result += _convertNumber(thousands) + ' ألف';
      } else {
        result += _convertNumber(thousands) + ' ألف';
      }
      number %= 1000;
      if (number > 0) result += ' و ';
    }

    // Handle hundreds
    if (number >= 100) {
      final hundredsDigit = number ~/ 100;
      result += hundreds[hundredsDigit];
      number %= 100;
      if (number > 0) result += ' و ';
    }

    // Handle tens and ones
    if (number >= 20) {
      final tensDigit = number ~/ 10;
      final onesDigit = number % 10;
      if (onesDigit > 0) {
        result += ones[onesDigit] + ' و ' + tens[tensDigit];
      } else {
        result += tens[tensDigit];
      }
    } else if (number > 0) {
      result += ones[number];
    }

    return result;
  }
}

