import 'package:flutter/material.dart';

import '../models.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets.dart';

class AiSuggestionScreen extends StatefulWidget {
  const AiSuggestionScreen({super.key});

  @override
  State<AiSuggestionScreen> createState() => _AiSuggestionScreenState();
}

class _AiSuggestionScreenState extends State<AiSuggestionScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      textAr: 'أهلًا وسهلًا بك 👋\nما الوجبة التي تريد أن تقترحها اليوم؟',
      textEn: 'Welcome 👋\nWhat meal would you like to suggest today?',
      fromUser: false,
    ),
  ];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(_ChatMessage(textAr: text, textEn: text, fromUser: true));
      _controller.clear();
      _sending = true;
    });
    _scrollToBottom();
    try {
      final response = await AppStateScope.of(context).sendAiMessage(text);
      final reply = (response['reply'] ?? '').toString();
      final suggestions = response['suggested_items'];
      String? productId;
      if (suggestions is List &&
          suggestions.isNotEmpty &&
          suggestions.first is Map) {
        final first = Map<String, dynamic>.from(suggestions.first as Map);
        productId = (first['reference_id'] ?? first['id'])?.toString();
      }
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(
            textAr: reply,
            textEn: reply,
            fromUser: false,
            linkedProductId: productId,
          )));
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('ApiException: ', '');
      setState(() => _messages.add(_ChatMessage(
            textAr: message,
            textEn: message,
            fromUser: false,
            isError: true,
          )));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return TazaShell(
      titleAr: 'اقتراح وجبة',
      titleEn: 'Suggest a meal',
      registered: state.isAuthenticated,
      showBack: true,
      body: Column(
        children: [
          TazaCard(
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0x2216C784),
                  child:
                      Icon(Icons.smart_toy_outlined, color: TazaColors.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TAZA AI',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900)),
                      Text(tr(context,
                          ar: 'متصل بقائمة المطعم واقتراحاته',
                          en: 'Connected to the restaurant catalog and suggestions')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TazaCard(
              child: ListView.separated(
                controller: _scrollController,
                itemCount: _messages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return Align(
                    alignment: message.fromUser
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .76),
                      child: Column(
                        crossAxisAlignment: message.fromUser
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: message.isError
                                  ? TazaColors.danger.withValues(alpha: .12)
                                  : message.fromUser
                                      ? TazaColors.accent.withValues(alpha: .18)
                                      : Theme.of(context)
                                          .colorScheme
                                          .surface
                                          .withValues(alpha: .58),
                              borderRadius: BorderRadius.circular(19),
                            ),
                            child: Text(isArabic(context)
                                ? message.textAr
                                : message.textEn),
                          ),
                          if (message.linkedProductId != null) ...[
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                AppRoutes.menu,
                                arguments: MenuRouteArgs(
                                  orderType: OrderType.ordinary,
                                  highlightProductId: message.linkedProductId,
                                ),
                              ),
                              icon: const Icon(Icons.restaurant_menu_rounded),
                              label: Text(tr(context,
                                  ar: 'عرض في المنيو', en: 'View in menu')),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: tr(context,
                        ar: 'اكتب الوجبة التي تريد اقتراحها...',
                        en: 'Type the meal you want to suggest...'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.textAr,
    required this.textEn,
    required this.fromUser,
    this.linkedProductId,
    this.isError = false,
  });

  final String textAr;
  final String textEn;
  final bool fromUser;
  final String? linkedProductId;
  final bool isError;
}
