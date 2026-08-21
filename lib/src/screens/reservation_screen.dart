import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../core/input_validation.dart';
import '../core/reservation_time.dart';
import '../models.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets.dart';
import 'screen_common.dart';

class ReservationScreen extends StatefulWidget {
  const ReservationScreen({super.key});

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  int? _table;
  late int _hour;
  late int _minute;
  late DayPeriod _period;
  int _seats = 2;
  final _notes = TextEditingController();
  bool _checking = false;
  bool _loadingTables = false;
  bool _catalogRequested = false;
  String? _tableError;
  int _refreshRequestId = 0;

  @override
  void initState() {
    super.initState();
    final initial = defaultReservationTime();
    _hour = initial.hour % 12 == 0 ? 12 : initial.hour % 12;
    _minute = initial.minute;
    _period = initial.hour >= 12 ? DayPeriod.pm : DayPeriod.am;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_catalogRequested) return;
    _catalogRequested = true;
    _refreshTables(isReservationTimeBookable(_dateTime) ? _dateTime : null);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  DateTime get _dateTime {
    return reservationDateTimeForToday(
      hour12: _hour,
      minute: _minute,
      isPm: _period == DayPeriod.pm,
    );
  }

  void _updateTime({int? hour, int? minute, DayPeriod? period}) {
    AppStateScope.of(context).clearConfirmedReservation();
    setState(() {
      _hour = hour ?? _hour;
      _minute = minute ?? _minute;
      _period = period ?? _period;
      _table = null;
      _tableError = null;
    });
    final value = _dateTime;
    if (!isReservationTimeBookable(value)) {
      _refreshRequestId++;
      if (_loadingTables) setState(() => _loadingTables = false);
      return;
    }
    unawaited(_refreshTables(value));
  }

  Future<List<ReservationTable>> _refreshTables(
      [DateTime? reservationTime]) async {
    final requestId = ++_refreshRequestId;
    if (mounted) {
      setState(() {
        _loadingTables = true;
        _tableError = null;
      });
    }
    try {
      final tables = await AppStateScope.of(context).loadReservationTables(
        reservationTime: reservationTime,
      );
      if (requestId != _refreshRequestId) return const [];
      if (_table != null &&
          tables
                  .where((table) => table.number == _table)
                  .firstOrNull
                  ?.isAvailable ==
              false) {
        _table = null;
      }
      return tables;
    } catch (error) {
      if (mounted && requestId == _refreshRequestId) {
        setState(() => _tableError = error is ApiException
            ? error.message
            : 'تعذر تحميل الطاولات الآن.');
      }
      return const [];
    } finally {
      if (mounted && requestId == _refreshRequestId) {
        setState(() => _loadingTables = false);
      }
    }
  }

  Future<void> _confirm() async {
    final value = _dateTime;
    final now = DateTime.now();
    if (!isReservationTimeBookable(value, now: now)) {
      showMessage(
          context,
          tr(context,
              ar: 'اختر وقتًا لاحقًا من اليوم؛ الوقت المحدد مضى',
              en: 'Choose a later time today; the selected time has passed'));
      return;
    }
    if (_table == null) {
      showMessage(context,
          tr(context, ar: 'اختر الطاولة أولًا', en: 'Choose a table first'));
      return;
    }
    if (!CustomerInputValidation.isSafeText(_notes.text, min: 2, max: 500)) {
      showMessage(
          context,
          tr(context,
              ar: 'تحقق من صيغة ملاحظات الحجز',
              en: 'Check the reservation notes'));
      return;
    }
    setState(() => _checking = true);
    final state = AppStateScope.of(context);
    final selectedTableNumber = _table!;
    try {
      if (!isReservationTimeBookable(value)) {
        throw const ApiException('وقت الحجز المحدد مضى. اختر وقتًا لاحقًا.');
      }
      final table = state.reservationTables
          .where((item) => item.number == selectedTableNumber)
          .firstOrNull;
      if (table == null) {
        throw const ApiException('تعذر العثور على الطاولة المحددة.');
      }
      final available = await state.tableIsAvailable(
        tableNumber: selectedTableNumber,
        reservationTime: value,
        durationMinutes: table.durationMinutes,
      );
      if (_dateTime != value || _table != selectedTableNumber) {
        throw const ApiException(
            'تغيرت بيانات الحجز أثناء التحقق. تحقق منها مرة أخرى.');
      }
      if (!isReservationTimeBookable(value)) {
        throw const ApiException('وقت الحجز المحدد مضى. اختر وقتًا لاحقًا.');
      }
      if (!available) {
        unawaited(_refreshTables(value));
        throw const ApiException(
            'الطاولة محجوزة في هذا الموعد. اختر وقتًا أو طاولة أخرى.');
      }
      if (_seats > table.maxSeats) {
        throw ApiException('الحد الأقصى لهذه الطاولة ${table.maxSeats} مقاعد.');
      }
      state.confirmReservation(
        tableNumber: table.number,
        isVip: table.isVip,
        reservationTime: value.toIso8601String(),
        seatsCount: _seats,
        durationMinutes: table.durationMinutes,
        notes: _notes.text.trim(),
      );
      if (mounted) {
        showMessage(
            context,
            tr(context,
                ar: 'تم تأكيد توفر الطاولة وإضافة بيانات الحجز',
                en: 'Table availability and reservation details confirmed'));
      }
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final tables = state.reservationTables;
    final selectedTable =
        tables.where((table) => table.number == _table).firstOrNull;
    final timeIsBookable = isReservationTimeBookable(_dateTime);
    return TazaShell(
      titleAr: 'حجز طاولة',
      titleEn: 'Table reservation',
      registered: state.isAuthenticated,
      showBack: true,
      bottomContent: _ReservationBottomBar(state: state),
      body: ListView(
        children: [
          const SectionHeader(
            titleAr: 'اختر طاولتك قبل الوصول',
            titleEn: 'Choose your table before arrival',
            subtitleAr: 'حدد الطاولة والوقت والمقاعد ثم تحقق من التوفر.',
            subtitleEn:
                'Pick a table, time, and seats, then verify availability.',
          ),
          const SizedBox(height: 14),
          if (_loadingTables && tables.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_tableError != null && tables.isEmpty)
            EmptyStateCard(
              icon: Icons.table_restaurant_outlined,
              titleAr: 'تعذر تحميل الطاولات',
              titleEn: 'Unable to load tables',
              bodyAr: _tableError!,
              bodyEn: 'Check your connection and try again.',
              action: ElevatedButton.icon(
                onPressed:
                    _loadingTables ? null : () => _refreshTables(_dateTime),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(tr(context, ar: 'إعادة المحاولة', en: 'Retry')),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) => GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tables.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.maxWidth >= 420 ? 3 : 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (context, index) {
                  final table = tables[index];
                  final selected = _table == table.number;
                  final unavailable =
                      !timeIsBookable || table.isAvailable == false;
                  final color = unavailable
                      ? TazaColors.danger
                      : table.isVip
                          ? TazaColors.warning
                          : TazaColors.success;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: unavailable
                          ? null
                          : () {
                              state.clearConfirmedReservation();
                              setState(() {
                                _table = table.number;
                                if (_seats > table.maxSeats) {
                                  _seats = table.maxSeats;
                                }
                              });
                            },
                      child: Ink(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: color.withValues(
                              alpha:
                                  unavailable ? .07 : (selected ? .22 : .11)),
                          border: Border.all(
                            color: color.withValues(alpha: selected ? 1 : .38),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(table.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w900)),
                                ),
                                if (selected)
                                  const Icon(Icons.check_circle_rounded,
                                      color: TazaColors.success),
                              ],
                            ),
                            const Spacer(),
                            Text(
                                table.isVip
                                    ? 'VIP'
                                    : tr(context, ar: 'عادية', en: 'Standard'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                            Text(
                              !timeIsBookable
                                  ? tr(context,
                                      ar: 'الوقت المحدد مضى',
                                      en: 'Selected time has passed')
                                  : table.isAvailable == null
                                      ? tr(context,
                                          ar: 'حدد الوقت لعرض التوفر',
                                          en: 'Select time for availability')
                                      : unavailable
                                          ? tr(context,
                                              ar: 'محجوزة في هذا الوقت',
                                              en: 'Reserved at this time')
                                          : tr(context,
                                              ar: 'متاحة في هذا الوقت',
                                              en: 'Available at this time'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          TazaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(context, ar: 'تفاصيل الحجز', en: 'Reservation details'),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _hour,
                        decoration: InputDecoration(
                          labelText: tr(context, ar: 'الساعة', en: 'Hour'),
                        ),
                        items: List.generate(12, (index) => index + 1)
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text('$value'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) _updateTime(hour: value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _minute,
                        decoration: InputDecoration(
                          labelText: tr(context, ar: 'الدقيقة', en: 'Minute'),
                        ),
                        items: List.generate(12, (index) => index * 5)
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.toString().padLeft(2, '0')),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) _updateTime(minute: value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<DayPeriod>(
                        initialValue: _period,
                        decoration: InputDecoration(
                          labelText: tr(context, ar: 'الفترة', en: 'Period'),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: DayPeriod.am,
                            child: Text('am'),
                          ),
                          DropdownMenuItem(
                            value: DayPeriod.pm,
                            child: Text('pm'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) _updateTime(period: value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _seats,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.chair_alt_outlined),
                    labelText: tr(context, ar: 'عدد المقاعد', en: 'Seats'),
                  ),
                  items: List.generate(
                          selectedTable?.maxSeats ?? 10, (index) => index + 1)
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    state.clearConfirmedReservation();
                    setState(() => _seats = value ?? 2);
                  },
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: _SeatingPreview(
                    key: ValueKey(_seats),
                    seats: _seats,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.timelapse_rounded, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tr(context,
                          ar: 'مدة الحجز 60 دقيقة. اختر وقتًا لاحقًا من اليوم؛ الأوقات الماضية غير متاحة.',
                          en: 'Reservations last 60 minutes. Choose a later time today; past times are unavailable.')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  onChanged: (_) => state.clearConfirmedReservation(),
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    hintText: tr(context,
                        ar: 'ملاحظات خاصة بالحجز (اختياري)',
                        en: 'Reservation notes (optional)'),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _checking ? null : _confirm,
                    icon: _checking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.event_available_rounded),
                    label: Text(tr(context,
                        ar: 'التحقق وتأكيد الحجز',
                        en: 'Check and confirm reservation')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TazaCard(
            child: Column(
              children: [
                _summaryLine(
                    context,
                    tr(context, ar: 'الطاولة', en: 'Table'),
                    state.selectedTableNumber == null
                        ? '—'
                        : '${state.selectedTableIsVip ? 'VIP' : tr(context, ar: 'عادية', en: 'Regular')} #${state.selectedTableNumber}'),
                _summaryLine(
                    context,
                    tr(context, ar: 'رسوم الحجز', en: 'Reservation fee'),
                    formatCurrency(state.reservationExtra)),
                const Divider(),
                _summaryLine(context, tr(context, ar: 'الإجمالي', en: 'Total'),
                    formatCurrency(state.orderGrandTotal),
                    bold: true),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _summaryLine(BuildContext context, String label, String value,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                color: bold ? TazaColors.accent : null,
              )),
        ],
      ),
    );
  }
}

class _SeatingPreview extends StatelessWidget {
  const _SeatingPreview({super.key, required this.seats});

  final int seats;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: tr(
        context,
        ar: 'رسم طاولة محاطة بـ $seats مقاعد',
        en: 'Table surrounded by $seats seats',
      ),
      child: Container(
        height: 210,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: .16),
              TazaColors.accent.withValues(alpha: .06),
            ],
          ),
          border: Border.all(color: color.withValues(alpha: .24)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const chairSize = 38.0;
            final centerX = constraints.maxWidth / 2;
            final centerY = constraints.maxHeight / 2;
            final radiusX = math.max(58.0, centerX - chairSize - 18);
            const radiusY = 72.0;
            return Stack(
              children: [
                Positioned(
                  left: centerX - 47,
                  top: centerY - 47,
                  child: Container(
                    width: 94,
                    height: 94,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).cardColor,
                      border: Border.all(color: color, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .14),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.table_restaurant_rounded),
                        Text(
                          '$seats',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
                for (var index = 0; index < seats; index++)
                  Positioned(
                    left: centerX +
                        math.cos((2 * math.pi * index / seats) - math.pi / 2) *
                            radiusX -
                        chairSize / 2,
                    top: centerY +
                        math.sin((2 * math.pi * index / seats) - math.pi / 2) *
                            radiusY -
                        chairSize / 2,
                    child: Transform.rotate(
                      angle: (2 * math.pi * index / seats),
                      child: Container(
                        width: chairSize,
                        height: chairSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: .28),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.chair_alt_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReservationBottomBar extends StatelessWidget {
  const _ReservationBottomBar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final ready = state.selectedTableNumber != null &&
        state.selectedReservationTime != null;
    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).cardColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(context, ar: 'الإجمالي', en: 'Total')),
                    Text(formatCurrency(state.orderGrandTotal),
                        style: const TextStyle(
                            color: TazaColors.accent,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: ready
                    ? () => Navigator.pushNamed(context, AppRoutes.payment)
                    : null,
                child: Text(tr(context, ar: 'إلى الدفع', en: 'Payment')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
