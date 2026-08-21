DateTime reservationDateTimeForToday({
  required int hour12,
  required int minute,
  required bool isPm,
  DateTime? now,
}) {
  assert(hour12 >= 1 && hour12 <= 12);
  assert(minute >= 0 && minute <= 59);

  final current = now ?? DateTime.now();
  final hour24 = (hour12 % 12) + (isPm ? 12 : 0);
  return DateTime(
    current.year,
    current.month,
    current.day,
    hour24,
    minute,
  );
}

bool isReservationTimeBookable(DateTime value, {DateTime? now}) {
  final current = now ?? DateTime.now();
  return value.isAfter(current) &&
      !value.isAfter(current.add(const Duration(days: 1)));
}

DateTime defaultReservationTime({DateTime? now}) {
  final current = now ?? DateTime.now();
  final candidate = current.add(const Duration(minutes: 5));
  final rounded = DateTime(
    candidate.year,
    candidate.month,
    candidate.day,
    candidate.hour,
    ((candidate.minute + 4) ~/ 5) * 5,
  );

  if (rounded.year == current.year &&
      rounded.month == current.month &&
      rounded.day == current.day) {
    return rounded;
  }

  // لا يوجد موعد كامل بخطوات خمس دقائق متبقٍ في هذا اليوم.
  return DateTime(current.year, current.month, current.day, 23, 55);
}
