import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_state.dart';
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
  DateTime _date = DateTime.now();
  TimeOfDay? _time;
  int _seats = 2;
  final _notes = TextEditingController();
  bool _checking = false;
  bool _loadingTables = false;
  bool _catalogRequested = false;
  String? _tableError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_catalogRequested) return;
    _catalogRequested = true;
    _refreshTables();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  DateTime? get _dateTime {
    final time = _time;
    if (time == null) return null;
    return DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _table = null;
      });
      await _refreshTables(_dateTime);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 20, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _time = picked;
        _table = null;
      });
      await _refreshTables(_dateTime);
    }
  }

  Future<List<ReservationTable>> _refreshTables(
      [DateTime? reservationTime]) async {
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
      if (mounted) {
        setState(() => _tableError = error is ApiException
            ? error.message
            : 'تعذر تحميل الطاولات الآن.');
      }
      return const [];
    } finally {
      if (mounted) setState(() => _loadingTables = false);
    }
  }

  Future<void> _confirm() async {
    final value = _dateTime;
    if (_table == null || value == null) {
      showMessage(
          context,
          tr(context,
              ar: 'اختر الطاولة والتاريخ والوقت أولًا',
              en: 'Choose a table, date, and time first'));
      return;
    }
    final now = DateTime.now();
    if (!value.isAfter(now) ||
        value.isAfter(now.add(const Duration(days: 1)))) {
      showMessage(
          context,
          tr(context,
              ar: 'الحجز متاح خلال الساعات الـ 24 القادمة فقط',
              en: 'Reservations are available only within the next 24 hours'));
      return;
    }
    setState(() => _checking = true);
    final state = AppStateScope.of(context);
    try {
      final tables = await _refreshTables(value);
      final table = tables.where((item) => item.number == _table).firstOrNull;
      if (table == null || table.isAvailable != true) {
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
                  final unavailable = table.isAvailable == false;
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
                          : () => setState(() {
                                _table = table.number;
                                if (_seats > table.maxSeats) {
                                  _seats = table.maxSeats;
                                }
                              }),
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
                              table.isAvailable == null
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
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                            '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.access_time_rounded),
                        label: Text(_time?.format(context) ??
                            tr(context, ar: 'الوقت', en: 'Time')),
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
                  onChanged: (value) => setState(() => _seats = value ?? 2),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.timelapse_rounded, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tr(context,
                          ar: 'مدة الحجز المعتمدة 60 دقيقة، والحجز متاح ضمن 24 ساعة.',
                          en: 'The reservation duration is 60 minutes and booking is available within 24 hours.')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
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
