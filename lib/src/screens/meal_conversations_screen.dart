import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../core/input_validation.dart';
import '../models.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets.dart';
import 'screen_common.dart';

enum _ConversationMode { advisor, idea }

class MealConversationsScreen extends StatefulWidget {
  const MealConversationsScreen({
    super.key,
    this.args = const MealConversationRouteArgs(),
  });

  final MealConversationRouteArgs args;

  @override
  State<MealConversationsScreen> createState() =>
      _MealConversationsScreenState();
}

class _MealConversationsScreenState extends State<MealConversationsScreen> {
  final _advisorController = TextEditingController();
  final _advisorScroll = ScrollController();
  final _ideaController = TextEditingController();
  final _ideaScroll = ScrollController();
  final _picker = ImagePicker();
  final List<_AdvisorMessage> _messages = [];

  AppState? _state;
  late _ConversationMode _mode;
  bool _initialized = false;
  bool _sending = false;
  bool _ideasLoading = false;
  bool _submittingIdea = false;
  Uint8List? _ideaImageBytes;
  String? _ideaImageName;

  static const _starterPrompts = <_StarterPrompt>[
    _StarterPrompt(
        'وجبة خفيفة ومنعشة', 'A light, fresh meal', Icons.eco_outlined),
    _StarterPrompt('وجبة دجاج مشبعة', 'A filling chicken meal',
        Icons.lunch_dining_outlined),
    _StarterPrompt(
        'أفضل عرض اليوم', 'Today’s best offer', Icons.local_offer_outlined),
    _StarterPrompt('خيار ضمن ميزانية', 'An option within a budget',
        Icons.account_balance_wallet_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _mode = widget.args.openIdeas
        ? _ConversationMode.idea
        : _ConversationMode.advisor;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    _state = state;
    if (_initialized) return;

    final firstName = state.currentUser.fullName.trim().split(' ').first;
    _messages.add(_AdvisorMessage(
      ar: state.isAuthenticated
          ? 'أهلًا $firstName 👋\nأخبرني بعدد الأشخاص والميزانية وما تفضله، وسأرتب لك خيارات من المنيو الحالي.'
          : 'أهلًا بك 👋\nأخبرني بعدد الأشخاص والميزانية وما تفضله، وسأرتب لك خيارات من المنيو الحالي.',
      en: state.isAuthenticated
          ? 'Hi $firstName 👋\nTell me your party size, budget, and preferences and I will curate choices from the live menu.'
          : 'Welcome 👋\nTell me your party size, budget, and preferences and I will curate choices from the live menu.',
      fromUser: false,
    ));
    _initialized = true;

    if (_mode == _ConversationMode.idea) {
      if (state.isAuthenticated) {
        _enableIdeaUpdates();
      } else {
        _mode = _ConversationMode.advisor;
      }
    }
  }

  @override
  void dispose() {
    _state?.setMealSuggestionUpdatesEnabled(false);
    _advisorController.dispose();
    _advisorScroll.dispose();
    _ideaController.dispose();
    _ideaScroll.dispose();
    super.dispose();
  }

  void _enableIdeaUpdates() {
    final state = _state;
    if (state == null || !state.isAuthenticated) return;
    state.setMealSuggestionUpdatesEnabled(true);
    _loadIdeas();
  }

  Future<void> _loadIdeas() async {
    final state = _state;
    if (state == null || !state.isAuthenticated || _ideasLoading) return;
    setState(() => _ideasLoading = true);
    try {
      await state.refreshMealSuggestions(throwOnError: true);
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _ideasLoading = false);
    }
  }

  void _selectMode(_ConversationMode mode) {
    final state = AppStateScope.of(context);
    if (mode == _ConversationMode.idea && !state.isAuthenticated) {
      showMessage(
        context,
        tr(
          context,
          ar: 'سجّل الدخول لإرسال فكرة وجبة ومتابعة قرار مدير التواصل.',
          en: 'Sign in to share a meal idea and track the manager response.',
        ),
      );
      return;
    }
    setState(() => _mode = mode);
    state.setMealSuggestionUpdatesEnabled(mode == _ConversationMode.idea);
    if (mode == _ConversationMode.idea) _loadIdeas();
  }

  Future<void> _sendAdvisor([String? value]) async {
    final text = (value ?? _advisorController.text).trim();
    if (text.isEmpty || _sending) return;
    if (!CustomerInputValidation.isSafeText(
      text,
      required: true,
      min: 2,
      max: 1000,
    )) {
      showMessage(
        context,
        tr(
          context,
          ar: 'اكتب طلباً واضحاً بين حرفين و1000 حرف.',
          en: 'Enter a clear request between 2 and 1000 characters.',
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _messages.add(_AdvisorMessage(ar: text, en: text, fromUser: true));
      _advisorController.clear();
      _sending = true;
    });
    _scrollAdvisorToBottom();

    try {
      final response = await AppStateScope.of(context).sendAiMessage(text);
      final reply = (response['reply'] ?? '').toString().trim();
      if (!mounted) return;
      setState(() => _messages.add(_AdvisorMessage(
            ar: reply.isEmpty
                ? 'أحتاج معلومة إضافية لأرتب لك أفضل الخيارات.'
                : reply,
            en: reply.isEmpty
                ? 'I need one more detail to curate the best options.'
                : reply,
            fromUser: false,
            suggestions: _parseSuggestions(response['suggested_items']),
            quickReplies: _parseQuickReplies(response['quick_replies']),
          )));
    } catch (error) {
      if (!mounted) return;
      final technical = error.toString().replaceFirst('ApiException: ', '');
      setState(() => _messages.add(_AdvisorMessage(
            ar: 'تعذر الوصول إلى المستشار الآن. أعد المحاولة.\n$technical',
            en: 'The advisor is unavailable right now. Please retry.\n$technical',
            fromUser: false,
            isError: true,
            retryText: text,
          )));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollAdvisorToBottom();
    }
  }

  List<_MenuSuggestion> _parseSuggestions(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final data = Map<String, dynamic>.from(item);
          return _MenuSuggestion(
            id: (data['reference_id'] ?? data['id'])?.toString(),
            ar: (data['name_ar'] ?? data['name'] ?? 'اقتراح من المنيو')
                .toString(),
            en: (data['name_en'] ?? data['name'] ?? 'Menu suggestion')
                .toString(),
            price: num.tryParse(
              '${data['offer_price'] ?? data['price'] ?? data['final_price'] ?? ''}',
            )?.toDouble(),
          );
        })
        .take(3)
        .toList(growable: false);
  }

  List<_QuickReply> _parseQuickReplies(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final data = Map<String, dynamic>.from(item);
          final value = (data['value'] ?? data['label'] ?? '').toString();
          return _QuickReply(
            label: (data['label'] ?? value).toString(),
            value: value,
          );
        })
        .where((item) => item.value.trim().isNotEmpty)
        .take(4)
        .toList(growable: false);
  }

  void _scrollAdvisorToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_advisorScroll.hasClients) return;
      _advisorScroll.animateTo(
        _advisorScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _openMenuSuggestion(_MenuSuggestion suggestion) {
    Navigator.pushNamed(
      context,
      AppRoutes.menu,
      arguments: MenuRouteArgs(
        orderType: OrderType.ordinary,
        highlightProductId: suggestion.id,
      ),
    );
  }

  Future<void> _pickIdeaImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 2400,
    );
    if (image == null) return;
    final extension = image.name.split('.').last.toLowerCase();
    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      if (mounted) {
        showMessage(
          context,
          tr(context,
              ar: 'اختر صورة JPG أو PNG أو WebP.',
              en: 'Choose a JPG, PNG, or WebP image.'),
        );
      }
      return;
    }
    final bytes = await image.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (mounted) {
        showMessage(
          context,
          tr(context,
              ar: 'حجم الصورة يجب ألا يتجاوز 5 ميغابايت.',
              en: 'The image must be no larger than 5 MB.'),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _ideaImageBytes = bytes;
      _ideaImageName = image.name;
    });
  }

  Future<void> _submitIdea() async {
    final text = _ideaController.text.trim();
    if (_submittingIdea ||
        !CustomerInputValidation.isSafeText(
          text,
          required: true,
          min: 10,
          max: 1000,
        )) {
      showMessage(
        context,
        tr(context,
            ar: 'اكتب فكرة واضحة من 10 أحرف على الأقل.',
            en: 'Enter a clear idea of at least 10 characters.'),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _submittingIdea = true);
    try {
      await AppStateScope.of(context).submitMealSuggestion(
        text: text,
        imageBytes: _ideaImageBytes,
        imageFilename: _ideaImageName,
      );
      if (!mounted) return;
      setState(() {
        _ideaController.clear();
        _ideaImageBytes = null;
        _ideaImageName = null;
      });
      showMessage(
        context,
        tr(context,
            ar: 'وصل اقتراحك إلى مدير التواصل.',
            en: 'Your idea reached the communication manager.'),
      );
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _submittingIdea = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return TazaShell(
      titleAr: 'محادثات الوجبة',
      titleEn: 'Meal conversations',
      registered: state.isAuthenticated,
      showBack: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      body: Column(
        children: [
          _ModeSwitch(mode: _mode, onChanged: _selectMode),
          const SizedBox(height: 10),
          Expanded(
            child: _mode == _ConversationMode.advisor
                ? _buildAdvisor(state)
                : _buildIdeas(state),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisor(AppState state) {
    return Column(
      children: [
        _ConversationHeader(
          icon: Icons.auto_awesome_rounded,
          title: tr(context, ar: 'المستشار الرقمي', en: 'Digital advisor'),
          subtitle: tr(context,
              ar: 'محادثة متدرجة مع المنيو الحي',
              en: 'A guided conversation connected to the live menu'),
          isOnline: state.isOnline,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _starterPrompts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final prompt = _starterPrompts[index];
              return ActionChip(
                avatar: Icon(prompt.icon, size: 18),
                label: Text(isArabic(context) ? prompt.ar : prompt.en),
                onPressed: _sending
                    ? null
                    : () => _sendAdvisor(
                          isArabic(context) ? prompt.ar : prompt.en,
                        ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TazaCard(
            padding: const EdgeInsets.all(10),
            child: ListView.separated(
              controller: _advisorScroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: _messages.length + (_sending ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == _messages.length) return const _TypingBubble();
                final message = _messages[index];
                return _AdvisorBubble(
                  message: message,
                  onSuggestion: _openMenuSuggestion,
                  onQuickReply: _sendAdvisor,
                  onRetry: message.retryText == null
                      ? null
                      : () => _sendAdvisor(message.retryText),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        _AdvisorComposer(
          controller: _advisorController,
          sending: _sending,
          onSend: _sendAdvisor,
        ),
      ],
    );
  }

  Widget _buildIdeas(AppState state) {
    final ideas = state.mealSuggestions;
    return Column(
      children: [
        _ConversationHeader(
          icon: Icons.lightbulb_outline_rounded,
          title: tr(context,
              ar: 'من فكرتك إلى قائمتنا', en: 'From your idea to our menu'),
          subtitle: tr(context,
              ar: 'أرسل الفكرة وتابع رد مدير التواصل',
              en: 'Send an idea and track the manager response'),
          isOnline: state.isOnline,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadIdeas,
            child: ListView(
              controller: _ideaScroll,
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                if (_ideasLoading && ideas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (ideas.isEmpty)
                  const EmptyStateCard(
                    icon: Icons.lightbulb_outline_rounded,
                    titleAr: 'ابدأ بأول فكرة وجبة',
                    titleEn: 'Start with your first meal idea',
                    bodyAr: 'صف الوجبة التي تتمناها وأضف صورة إن رغبت.',
                    bodyEn:
                        'Describe the meal you wish for and optionally add an image.',
                  )
                else
                  ...ideas.map((idea) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _IdeaCard(
                          idea: idea,
                          highlighted: widget.args.suggestionId == idea.id,
                        ),
                      )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _IdeaComposer(
          controller: _ideaController,
          imageBytes: _ideaImageBytes,
          imageName: _ideaImageName,
          busy: _submittingIdea,
          onPickImage: _pickIdeaImage,
          onRemoveImage: () => setState(() {
            _ideaImageBytes = null;
            _ideaImageName = null;
          }),
          onSubmit: _submitIdea,
        ),
      ],
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final _ConversationMode mode;
  final ValueChanged<_ConversationMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeButton(
            selected: mode == _ConversationMode.advisor,
            icon: Icons.auto_awesome_rounded,
            label: tr(context, ar: 'المستشار الرقمي', en: 'Digital advisor'),
            onTap: () => onChanged(_ConversationMode.advisor),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeButton(
            selected: mode == _ConversationMode.idea,
            icon: Icons.lightbulb_outline_rounded,
            label: tr(context, ar: 'فكرة وجبة', en: 'Meal idea'),
            onTap: () => onChanged(_ConversationMode.idea),
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? TazaColors.accent.withValues(alpha: .18)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  selected ? TazaColors.accent : Theme.of(context).dividerColor,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? TazaColors.accent : null),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isOnline,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [
          TazaColors.accent.withValues(alpha: .22),
          TazaColors.success.withValues(alpha: .08),
        ]),
        border: Border.all(color: TazaColors.accent.withValues(alpha: .20)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: TazaColors.accent.withValues(alpha: .16),
            child: Icon(icon, color: TazaColors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.circle,
              size: 9,
              color: isOnline ? TazaColors.success : TazaColors.warning),
        ],
      ),
    );
  }
}

class _AdvisorBubble extends StatelessWidget {
  const _AdvisorBubble({
    required this.message,
    required this.onSuggestion,
    required this.onQuickReply,
    this.onRetry,
  });

  final _AdvisorMessage message;
  final ValueChanged<_MenuSuggestion> onSuggestion;
  final ValueChanged<String> onQuickReply;
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
          const SizedBox(width: 7),
        ],
        Flexible(
          child: Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .78),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: message.isError
                  ? TazaColors.warning.withValues(alpha: .12)
                  : message.fromUser
                      ? TazaColors.accent.withValues(alpha: .20)
                      : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isArabic(context) ? message.ar : message.en),
                if (message.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...message.suggestions.map((suggestion) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: TazaColors.accent.withValues(alpha: .09),
                          borderRadius: BorderRadius.circular(13),
                          child: ListTile(
                            dense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 9),
                            leading: const Icon(Icons.restaurant_menu_rounded,
                                size: 19, color: TazaColors.accent),
                            title: Text(isArabic(context)
                                ? suggestion.ar
                                : suggestion.en),
                            trailing: suggestion.price == null
                                ? const Icon(Icons.arrow_forward_ios_rounded,
                                    size: 13)
                                : Text(formatCurrency(suggestion.price!),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                            onTap: () => onSuggestion(suggestion),
                          ),
                        ),
                      )),
                ],
                if (message.quickReplies.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: message.quickReplies
                        .map((reply) => ActionChip(
                              label: Text(reply.label),
                              onPressed: () => onQuickReply(reply.value),
                            ))
                        .toList(growable: false),
                  ),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: 8),
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

class _IdeaCard extends StatelessWidget {
  const _IdeaCard({required this.idea, required this.highlighted});

  final MealSuggestion idea;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final status = _statusPresentation(context, idea.status);
    return Container(
      decoration: highlighted
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: TazaColors.accent.withValues(alpha: .22),
                  blurRadius: 18,
                )
              ],
            )
          : null,
      child: TazaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    color: TazaColors.accent),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(idea.text,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            if (idea.imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: TazaImage(
                  imageUrl: idea.imageUrl,
                  labelAr: 'صورة فكرة الوجبة',
                  labelEn: 'Meal idea image',
                  height: 145,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(status.icon, size: 15, color: status.color),
                      const SizedBox(width: 5),
                      Text(status.label,
                          style: TextStyle(
                              color: status.color,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                if (idea.createdAt.isNotEmpty)
                  Text(idea.createdAt.replaceFirst('T', ' ').split('.').first,
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: .5),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      tr(context,
                          ar: 'مدير التواصل', en: 'Communication manager'),
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(idea.adminNote.trim().isNotEmpty
                      ? idea.adminNote
                      : status.fallbackMessage),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvisorComposer extends StatelessWidget {
  const _AdvisorComposer({
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
            onSubmitted: sending ? null : (_) => onSend(),
            decoration: InputDecoration(
              counterText: '',
              hintText: tr(context,
                  ar: 'مثلاً: وجبة لشخصين ضمن ميزانية',
                  en: 'Try: a meal for two within a budget'),
            ),
          ),
        ),
        const SizedBox(width: 7),
        IconButton.filled(
          tooltip: tr(context, ar: 'إرسال', en: 'Send'),
          onPressed: sending ? null : () => onSend(),
          icon: const Icon(Icons.send_rounded),
        ),
      ],
    );
  }
}

class _IdeaComposer extends StatelessWidget {
  const _IdeaComposer({
    required this.controller,
    required this.imageBytes,
    required this.imageName,
    required this.busy,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final Uint8List? imageBytes;
  final String? imageName;
  final bool busy;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return TazaCard(
      padding: const EdgeInsets.all(9),
      child: Column(
        children: [
          TextField(
            controller: controller,
            inputFormatters: CustomerInputValidation.limited(1000),
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            enabled: !busy,
            decoration: InputDecoration(
              counterText: '',
              hintText: tr(context,
                  ar: 'صف الوجبة أو المكونات أو النكهة...',
                  en: 'Describe the meal, ingredients, or flavor...'),
            ),
          ),
          if (imageBytes != null) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.memory(imageBytes!,
                      width: 48, height: 48, fit: BoxFit.cover),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(imageName ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  onPressed: busy ? null : onRemoveImage,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ],
          const SizedBox(height: 7),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : onPickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(tr(context, ar: 'صورة', en: 'Image')),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: busy ? null : onSubmit,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                  label: Text(
                      tr(context, ar: 'إرسال الاقتراح', en: 'Send suggestion')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Text(tr(context, ar: 'أرتّب لك الخيارات...', en: 'Curating picks...')),
      ],
    );
  }
}

_StatusPresentation _statusPresentation(
  BuildContext context,
  MealSuggestionStatus status,
) =>
    switch (status) {
      MealSuggestionStatus.reviewed => _StatusPresentation(
          label: tr(context, ar: 'تمت المراجعة', en: 'Reviewed'),
          fallbackMessage: tr(context,
              ar: 'تمت مراجعة الفكرة، وسيظهر تعليق المدير هنا.',
              en: 'The idea was reviewed. The manager note will appear here.'),
          color: TazaColors.info,
          icon: Icons.fact_check_outlined,
        ),
      MealSuggestionStatus.implemented => _StatusPresentation(
          label: tr(context, ar: 'تم التطبيق', en: 'Implemented'),
          fallbackMessage: tr(context,
              ar: 'تم اعتماد الفكرة وتطبيقها.',
              en: 'The idea was accepted and implemented.'),
          color: TazaColors.success,
          icon: Icons.verified_outlined,
        ),
      MealSuggestionStatus.rejected => _StatusPresentation(
          label: tr(context, ar: 'لن تطبق حالياً', en: 'Not planned now'),
          fallbackMessage: tr(context,
              ar: 'شكراً لفكرتك. لن نتمكن من تطبيقها حالياً.',
              en: 'Thank you. The idea cannot be implemented right now.'),
          color: TazaColors.warning,
          icon: Icons.info_outline_rounded,
        ),
      MealSuggestionStatus.pending => _StatusPresentation(
          label: tr(context, ar: 'قيد المراجعة', en: 'Under review'),
          fallbackMessage: tr(context,
              ar: 'وصلت الفكرة إلى مدير التواصل وهي بانتظار المراجعة.',
              en: 'The idea reached the manager and awaits review.'),
          color: TazaColors.accent,
          icon: Icons.hourglass_top_rounded,
        ),
    };

class _StatusPresentation {
  const _StatusPresentation({
    required this.label,
    required this.fallbackMessage,
    required this.color,
    required this.icon,
  });

  final String label;
  final String fallbackMessage;
  final Color color;
  final IconData icon;
}

class _AdvisorMessage {
  const _AdvisorMessage({
    required this.ar,
    required this.en,
    required this.fromUser,
    this.suggestions = const [],
    this.quickReplies = const [],
    this.isError = false,
    this.retryText,
  });

  final String ar;
  final String en;
  final bool fromUser;
  final List<_MenuSuggestion> suggestions;
  final List<_QuickReply> quickReplies;
  final bool isError;
  final String? retryText;
}

class _MenuSuggestion {
  const _MenuSuggestion({
    required this.id,
    required this.ar,
    required this.en,
    required this.price,
  });

  final String? id;
  final String ar;
  final String en;
  final double? price;
}

class _QuickReply {
  const _QuickReply({required this.label, required this.value});

  final String label;
  final String value;
}

class _StarterPrompt {
  const _StarterPrompt(this.ar, this.en, this.icon);

  final String ar;
  final String en;
  final IconData icon;
}
