import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';

class RevoScreen extends ConsumerStatefulWidget {
  const RevoScreen({super.key});

  @override
  ConsumerState<RevoScreen> createState() => _RevoScreenState();
}

class _RevoScreenState extends ConsumerState<RevoScreen> {
  final controller = TextEditingController();
  final scrollController = ScrollController();
  bool sending = false;
  String? localError;
  int lastVisibleItemCount = -1;
  bool nearBottom = true;
  bool forceNextScroll = false;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_trackScrollPosition);
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appControllerProvider).data!;
    final product = context.product;
    final visibleItemCount = data.messages.length + (sending ? 1 : 0);
    if (visibleItemCount != lastVisibleItemCount) {
      lastVisibleItemCount = visibleItemCount;
      final shouldScroll = nearBottom || forceNextScroll;
      forceNextScroll = false;
      if (shouldScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
      }
    }
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  product.pagePadding,
                  product.pagePadding,
                  product.pagePadding,
                  product.compact ? 12 : 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ask REVO',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Your local demo card-strategy assistant.',
                      style: TextStyle(color: product.muted),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final prompts = data.quickPrompts
                            .map(
                              (prompt) => _QuickPromptButton(
                                label: Text(prompt),
                                onPressed: sending
                                    ? null
                                    : () => _submit(prompt),
                              ),
                            )
                            .toList();
                        if (constraints.maxWidth < 600) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (
                                  var index = 0;
                                  index < prompts.length;
                                  index++
                                ) ...[
                                  if (index > 0) const SizedBox(width: 12),
                                  prompts[index],
                                ],
                              ],
                            ),
                          );
                        }
                        return Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          children: prompts,
                        );
                      },
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: product.border),
              Expanded(
                child: ListView.builder(
                  key: const ValueKey('chat-history'),
                  controller: scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.all(product.pagePadding),
                  itemCount: data.messages.length + (sending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == data.messages.length) {
                      return const _ThinkingAnswer();
                    }
                    return _MessageDocument(message: data.messages[index]);
                  },
                ),
              ),
              if (localError != null)
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: product.pagePadding),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: product.danger.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(product.radius * .65),
                    border: Border.all(color: product.danger),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: product.danger),
                      const SizedBox(width: 9),
                      Expanded(child: Text(localError!)),
                      TextButton(
                        onPressed: () => setState(() => localError = null),
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  product.pagePadding,
                  10,
                  product.pagePadding,
                  12,
                ),
                decoration: BoxDecoration(
                  color: product.canvas,
                  border: Border(top: BorderSide(color: product.border)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('revo-composer'),
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 1000,
                        textInputAction: TextInputAction.newline,
                        onTap: () => Future<void>.delayed(
                          const Duration(milliseconds: 250),
                          _scrollToLatest,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Ask about your wallet or next move',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      key: const ValueKey('revo-send'),
                      tooltip: 'Send message',
                      onPressed: sending
                          ? null
                          : () => _submit(controller.text),
                      padding: const EdgeInsets.all(15),
                      icon: sending
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_upward),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(String value) async {
    final prompt = value.trim();
    if (prompt.isEmpty || sending) return;
    controller.clear();
    setState(() {
      sending = true;
      localError = null;
      forceNextScroll = true;
    });
    try {
      await ref.read(appControllerProvider.notifier).sendMessage(prompt);
    } catch (_) {
      if (mounted) {
        setState(
          () => localError =
              'The response failed. Check your connection or try again.',
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _scrollToLatest() {
    if (!mounted || !scrollController.hasClients) return;
    final position = scrollController.position;
    scrollController.animateTo(
      position.maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _trackScrollPosition() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    nearBottom = position.maxScrollExtent - position.pixels < 140;
  }
}

class _MessageDocument extends StatelessWidget {
  const _MessageDocument({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.role == MessageRole.user;
    final product = context.product;
    if (user) {
      final bubbles =
          product.chatTreatment == ChatTreatment.bubbles ||
          product.chatTreatment == ChatTreatment.wallet;
      return Align(
        alignment: bubbles ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: bubbles ? 620 : 760),
          margin: const EdgeInsets.only(bottom: 24),
          padding: bubbles
              ? const EdgeInsets.symmetric(horizontal: 18, vertical: 14)
              : const EdgeInsets.only(bottom: 16),
          decoration: switch (product.chatTreatment) {
            ChatTreatment.bubbles => BoxDecoration(
              color: product.userQuery,
              borderRadius: BorderRadius.circular(product.radius),
            ),
            ChatTreatment.editorial => BoxDecoration(
              border: Border(bottom: BorderSide(color: product.ink, width: 1)),
            ),
            ChatTreatment.console => BoxDecoration(
              color: product.userQuery,
              border: Border.all(color: product.border),
            ),
            ChatTreatment.wallet => BoxDecoration(
              color: product.userQuery,
              borderRadius: BorderRadius.circular(product.radius),
            ),
            ChatTreatment.document => BoxDecoration(
              border: Border(bottom: BorderSide(color: product.border)),
            ),
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!bubbles)
                SizedBox(
                  width: product.chatTreatment == ChatTreatment.console
                      ? 72
                      : 48,
                  child: Text(
                    product.chatTreatment == ChatTreatment.console
                        ? '> USER'
                        : 'YOU',
                    style: TextStyle(
                      color: product.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              Expanded(
                child: SelectableText(
                  message.content,
                  style: TextStyle(color: product.ink, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final assistantDecoration = switch (product.chatTreatment) {
      ChatTreatment.document => null,
      ChatTreatment.bubbles => BoxDecoration(
        color: product.surface,
        borderRadius: BorderRadius.circular(product.radius),
      ),
      ChatTreatment.editorial => BoxDecoration(
        color: product.surface,
        border: Border(left: BorderSide(color: product.secondary, width: 3)),
      ),
      ChatTreatment.console => BoxDecoration(
        color: product.subtle.withValues(alpha: .55),
        border: Border.all(color: product.action.withValues(alpha: .5)),
      ),
      ChatTreatment.wallet => BoxDecoration(
        color: product.surface,
        border: Border.all(color: product.border),
        borderRadius: BorderRadius.circular(product.radius),
        boxShadow: [
          BoxShadow(
            color: product.ink.withValues(alpha: .04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
    };
    return Container(
      constraints: const BoxConstraints(maxWidth: 760),
      margin: EdgeInsets.only(bottom: product.compact ? 24 : 34),
      padding: product.chatTreatment == ChatTreatment.document
          ? const EdgeInsets.symmetric(horizontal: 2)
          : const EdgeInsets.all(16),
      decoration: assistantDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: product.action),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  product.chatTreatment == ChatTreatment.console
                      ? 'REVO::OUTPUT'
                      : product.chatTreatment == ChatTreatment.editorial
                      ? 'RevoCred advisory note'
                      : 'REVO ANSWER',
                  style: TextStyle(
                    color: product.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            message.content,
            style: TextStyle(
              color: product.ink,
              height: 1.6,
              fontSize: product.chatTreatment == ChatTreatment.document
                  ? 16
                  : 14,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 13, color: product.muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Context: demo wallet and deterministic recommendation',
                  style: TextStyle(color: product.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickPromptButton extends StatelessWidget {
  const _QuickPromptButton({required this.label, required this.onPressed});

  final Widget label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: context.product.action,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      shape: const RoundedRectangleBorder(),
    ),
    iconAlignment: IconAlignment.end,
    icon: const Icon(Icons.arrow_outward, size: 14),
    label: label,
  );
}

class _ThinkingAnswer extends StatelessWidget {
  const _ThinkingAnswer();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        const SizedBox(
          width: 17,
          height: 17,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Text(
          'REVO is reviewing your wallet...',
          style: TextStyle(color: context.product.muted),
        ),
      ],
    ),
  );
}
