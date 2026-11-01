import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Pinned bottom input bar for sending messages in a chat room or direct message thread.
class SlskdChatComposer extends StatefulWidget {
  const SlskdChatComposer({
    required this.onSend,
    this.hintText = 'Type a message...',
    this.autofocus = false,
    super.key,
  });

  /// Sends [text] and reports whether it went out. The field is cleared only
  /// on success, so a failed send keeps what was typed.
  final Future<bool> Function(String text) onSend;
  final String hintText;
  final bool autofocus;

  @override
  State<SlskdChatComposer> createState() => _SlskdChatComposerState();
}

class _SlskdChatComposerState extends State<SlskdChatComposer> {
  final TextEditingController _controller = TextEditingController();
  bool _canSend = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final canSend = _controller.text.trim().isNotEmpty;
      if (canSend != _canSend) {
        setState(() => _canSend = canSend);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final bool sent = await widget.onSend(text);
    if (!mounted) return;
    setState(() => _sending = false);
    // Anything typed while the send was in flight is a new draft, so clear
    // only if the field still holds what was sent.
    if (sent && _controller.text.trim() == text) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: Insets.xs),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                child: TextField(
                  controller: _controller,
                  autofocus: widget.autofocus,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                  maxLines: 4,
                  minLines: 1,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.outline,
                        ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Insets.xs),
            IconButton.filled(
              icon: const Icon(Icons.send_rounded, size: 18),
              onPressed: _canSend && !_sending ? _submit : null,
              style: IconButton.styleFrom(
                backgroundColor: _canSend ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                foregroundColor: _canSend ? colorScheme.onPrimary : colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
