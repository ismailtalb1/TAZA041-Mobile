import 'package:flutter/material.dart';

import '../models.dart';
import '../core/input_validation.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets.dart';
import 'screen_common.dart';

class AiSuggestionScreen extends StatefulWidget {
  const AiSuggestionScreen({super.key});

  @override
  State<AiSuggestionScreen> createState() => _AiSuggestionScreenState();
}

class _AiSuggestionScreenState extends State<AiSuggestionScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _initialized = false;
  bool _sending = false;

  static const _quickPrompts = <_QuickPrompt>[
    _QuickPrompt('أريد وجبة خفيفة ومنعشة', 'I want a light, fresh meal',
        Icons.eco_outlined),
    _QuickPrompt('اقترح وجبة دجاج مشبعة', 'Suggest a filling chicken meal',
        Icons.lunch_dining_outlined),
    _QuickPrompt('ما أفضل عرض اليوم؟', 'What is today’s best offer?',
        Icons.local_offer_outlined),
    _QuickPrompt('ساعدني في اختيار طاولة', 'Help me choose a table',
        Icons.table_restaurant_outlined),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final state = AppStateScope.of(context);
    final firstName = state.currentUser.fullName.trim().split(' ').first;
    _messages.add(_ChatMessage(
      textAr: state.isAuthenticated
          ? 'أهلًا $firstName 👋\nخلّينا نختار شيئًا يناسب مزاجك، شهيتك وميزانيتك اليوم.'
          : 'أهلًا بك 👋\nصف لي مزاجك أو شهيتك أو ميزانيتك، وسأقترح لك خيارًا من المنيو الحالي.',
      textEn: state.isAuthenticated
          ? 'Hi $firstName 👋\nLet’s find something that fits your mood, appetite, and budget today.'
          : 'Welcome 👋\nTell me your mood, appetite, or budget and I’ll match you with the live menu.',
      fromUser: false,
    ));
    _initialized = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? value]) async {
    final text = (value ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;
    if (!CustomerInputValidation.isSafeText(text,
        required: true, min: 2, max: 1000)) {
      showMessage(
          context,
          tr(context,
              ar: 'اكتب طلباً واضحاً بين حرفين و1000 حرف',
              en: 'Enter a clear request between 2 and 1000 characters'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _messages.add(_ChatMessage(textAr: text, textEn: text, fromUser: true));
      _controller.clear();
      _sending = true;
    });
    _scrollToBottom();
    try {
      final response = await AppStateScope.of(context).sendAiMessage(text);
      final reply = (response['reply'] ?? '').toString().trim();
      final intent = (response['intent'] ?? 'general').toString();
      final suggestions = _parseSuggestions(response['suggested_items']);
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(
            textAr: _replyWithFollowUp(reply, intent, arabic: true),
            textEn: _replyWithFollowUp(reply, intent, arabic: false),
            fromUser: false,
            suggestions: suggestions,
          )));
    } catch (error) {
      if (!mounted) return;
      final technical = error.toString().replaceFirst('ApiException: ', '');
      setState(() => _messages.add(_ChatMessage(
            textAr:
                'الاتصال تعثّر هذه المرة، لكن فكرتك ما زالت معنا. تحقق من الإنترنت ثم أعد المحاولة، أو افتح المنيو واختر مباشرةً.\n$technical',
            textEn:
                'The connection paused this round, but your idea is still here. Check your connection and retry, or browse the menu directly.\n$technical',
            fromUser: false,
            isError: true,
            retryText: text,
          )));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  List<_AiSuggestion> _parseSuggestions(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final data = Map<String, dynamic>.from(item);
          return _AiSuggestion(
            id: (data['reference_id'] ?? data['id'])?.toString(),
            nameAr: (data['name_ar'] ?? data['name'] ?? 'اقتراح من المنيو')
                .toString(),
            nameEn: (data['name_en'] ?? data['name'] ?? 'Menu suggestion')
                .toString(),
            price: num.tryParse(
                    '${data['offer_price'] ?? data['price'] ?? data['final_price'] ?? ''}')
                ?.toDouble(),
          );
        })
        .take(3)
        .toList(growable: false);
  }

  String _replyWithFollowUp(String reply, String intent,
      {required bool arabic}) {
    final safeReply = reply.isEmpty
        ? (arabic
            ? 'وجدت لك أكثر من طريق للاختيار من المنيو الحالي.'
            : 'I found a few useful directions from the live menu.')
        : reply;
    final followUp = switch (intent) {
      'meal_suggestion' => arabic
          ? 'تحبها أخف، أشبع، أم ضمن ميزانية محددة؟'
          : 'Would you like it lighter, more filling, or within a budget?',
      'offers_inquiry' => arabic
          ? 'هل أفتح لك العرض في المنيو؟'
          : 'Would you like to open the offer in the menu?',
      'price_inquiry' => arabic
          ? 'أعطني ميزانيتك وسأضيّق الخيارات لك.'
          : 'Give me your budget and I’ll narrow the choices.',
      'reservation_inquiry' => arabic
          ? 'أخبرني بعدد الأشخاص والوقت المناسب.'
          : 'Tell me your party size and preferred time.',
      _ => arabic
          ? 'جرّب أن تذكر النكهة، عدد الأشخاص أو الميزانية لأعطيك اختيارًا أدق.'
          : 'Mention a flavor, party size, or budget for a sharper match.',
    };
    return '$safeReply\n\n$followUp';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _openSuggestion(_AiSuggestion suggestion) {
    Navigator.pushNamed(
      context,
      AppRoutes.menu,
      arguments: MenuRouteArgs(
        orderType: OrderType.ordinary,
        highlightProductId: suggestion.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return TazaShell(
      titleAr: 'محادثة النموذج الرقمي',
      titleEn: 'Digital model chat',
      registered: state.isAuthenticated,
      showBack: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      body: Column(
        children: [
          _AiHeader(isOnline: state.isOnline),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickPrompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final prompt = _quickPrompts[index];
                return ActionChip(
                  avatar: Icon(prompt.icon, size: 18),
                  label: Text(isArabic(context) ? prompt.ar : prompt.en),
                  onPressed: _sending
                      ? null
                      : () => _send(isArabic(context) ? prompt.ar : prompt.en),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TazaCard(
              padding: const EdgeInsets.all(12),
              child: ListView.separated(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: _messages.length + (_sending ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return const _TypingBubble();
                  }
                  final message = _messages[index];
                  return TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 260),
                    tween: Tween(begin: 0, end: 1),
                    builder: (_, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 8 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: _MessageBubble(
                      message: message,
                      onRetry: message.retryText == null
                          ? null
                          : () => _send(message.retryText),
                      onSuggestion: _openSuggestion,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          _Composer(
            controller: _controller,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _AiHeader extends StatelessWidget {
  const _AiHeader({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            TazaColors.accent.withValues(alpha: .24),
            TazaColors.success.withValues(alpha: .10),
          ],
        ),
        border: Border.all(color: TazaColors.accent.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: TazaColors.accent.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: TazaColors.accent2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TAZA Meal Guide',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  tr(context,
                      ar: 'اختيارات من المنيو الحي حسب ذوقك',
                      en: 'Live-menu picks matched to your taste'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: (isOnline ? TazaColors.success : TazaColors.warning)
                  .withValues(alpha: .14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle,
                    size: 8,
                    color: isOnline ? TazaColors.success : TazaColors.warning),
                const SizedBox(width: 5),
                Text(
                  isOnline
                      ? tr(context, ar: 'متصل', en: 'Live')
                      : tr(context, ar: 'محلي', en: 'Offline'),
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onSuggestion,
    this.onRetry,
  });

  final _ChatMessage message;
  final ValueChanged<_AiSuggestion> onSuggestion;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment:
          message.fromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!message.fromUser) ...[
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0x22FF8728),
            child: Icon(Icons.auto_awesome_rounded,
                size: 17, color: TazaColors.accent),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .76),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: message.isError
                  ? TazaColors.warning.withValues(alpha: .12)
                  : message.fromUser
                      ? TazaColors.accent.withValues(alpha: .20)
                      : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadiusDirectional.only(
                topStart: const Radius.circular(20),
                topEnd: const Radius.circular(20),
                bottomStart: Radius.circular(message.fromUser ? 20 : 6),
                bottomEnd: Radius.circular(message.fromUser ? 6 : 20),
              ),
              border: Border.all(
                color: message.isError
                    ? TazaColors.warning.withValues(alpha: .25)
                    : Theme.of(context).dividerColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isArabic(context) ? message.textAr : message.textEn),
                if (message.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...message.suggestions.map((suggestion) => Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Material(
                          color: TazaColors.accent.withValues(alpha: .09),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => onSuggestion(suggestion),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 9),
                              child: Row(
                                children: [
                                  const Icon(Icons.restaurant_menu_rounded,
                                      size: 18, color: TazaColors.accent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(isArabic(context)
                                        ? suggestion.nameAr
                                        : suggestion.nameEn),
                                  ),
                                  if (suggestion.price != null)
                                    Text(formatCurrency(suggestion.price!),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                  const SizedBox(width: 5),
                                  const Icon(Icons.arrow_forward_ios_rounded,
                                      size: 13),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(tr(context, ar: 'إعادة المحاولة', en: 'Retry')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 16,
          backgroundColor: Color(0x22FF8728),
          child: Icon(Icons.auto_awesome_rounded,
              size: 17, color: TazaColors.accent),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(tr(context,
                  ar: 'أرتّب لك الخيارات...', en: 'Curating picks...')),
            ],
          ),
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final Future<void> Function([String? value]) onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            inputFormatters: CustomerInputValidation.limited(1000),
            minLines: 1,
            maxLines: 4,
            maxLength: 1000,
            textInputAction: TextInputAction.send,
            onSubmitted: sending ? null : (_) => onSend(),
            decoration: InputDecoration(
              counterText: '',
              prefixIcon: const Icon(Icons.restaurant_rounded),
              hintText: tr(context,
                  ar: 'مثلاً: أريد وجبة خفيفة بميزانية محددة',
                  en: 'Try: a light meal within a budget'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [TazaColors.accent, TazaColors.accent2]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: IconButton(
            tooltip: tr(context, ar: 'إرسال', en: 'Send'),
            onPressed: sending ? null : () => onSend(),
            color: const Color(0xFF211209),
            icon: const Icon(Icons.send_rounded),
          ),
        ),
      ],
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.textAr,
    required this.textEn,
    required this.fromUser,
    this.suggestions = const [],
    this.isError = false,
    this.retryText,
  });

  final String textAr;
  final String textEn;
  final bool fromUser;
  final List<_AiSuggestion> suggestions;
  final bool isError;
  final String? retryText;
}

class _AiSuggestion {
  const _AiSuggestion({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.price,
  });

  final String? id;
  final String nameAr;
  final String nameEn;
  final double? price;
}

class _QuickPrompt {
  const _QuickPrompt(this.ar, this.en, this.icon);

  final String ar;
  final String en;
  final IconData icon;
}
