final RegExp _arabicLetterPattern = RegExp(
  r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
);

bool containsArabic(String text) => _arabicLetterPattern.hasMatch(text);
