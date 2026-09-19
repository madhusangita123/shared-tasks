import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_text_styles.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';

/// The inline "Add a task..." row that sits at both the top and the bottom
/// of [TaskListScreen]'s list — issue #55. Replaces the old floating action
/// button + modal "add" flow entirely: adding a task never leaves the list.
///
/// Two visual states, both 40px tall so swapping between them doesn't shift
/// the rows around it:
///
/// * placeholder — a dashed-free 20x20 `+` ring and muted "Add a task..."
///   label, the whole row tappable;
/// * editing — an autofocused, undecorated [TextField] that looks like the
///   same row turned into an input.
///
/// A [ConsumerStatefulWidget] rather than a [ConsumerWidget] — owns the
/// [TextEditingController], the [FocusNode] and the placeholder/editing
/// flag, none of which belong in a provider (they're pure local UI state,
/// and there are two independent instances of this widget on screen at
/// once).
class InlineAddTaskRow extends ConsumerStatefulWidget {
  const InlineAddTaskRow({required this.spaceId, super.key});

  final String spaceId;

  @override
  ConsumerState<InlineAddTaskRow> createState() => _InlineAddTaskRowState();
}

class _InlineAddTaskRowState extends ConsumerState<InlineAddTaskRow> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  /// `true` once the row has been tapped and swapped itself for the text
  /// field. Reverts to `false` on blur, but only while the field is empty —
  /// half-typed text is never thrown away just because focus moved.
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    // Keeps [addTaskProvider] (an autoDispose notifier) alive for this
    // widget's whole lifetime. Nothing here watches it — this row branches on
    // addTask's return value, not on provider state — but the notifier
    // assigns to its own `state` across the await inside addTask, and doing
    // that after an auto-dispose throws. Without a listener there's nothing
    // holding it alive for the duration of an in-flight write.
    ref.listenManual(addTaskProvider, (previous, next) {});
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) return;
    // Blur with nothing typed → back to the placeholder row. Blur with text
    // still in the field leaves the field in place, so the user can come
    // back to it.
    if (_controller.text.trim().isEmpty && _isEditing) {
      setState(() => _isEditing = false);
    }
  }

  void _startEditing() {
    setState(() => _isEditing = true);
    _focusNode.requestFocus();
  }

  Future<void> _onSubmitted(String value) async {
    final title = value.trim();
    if (title.isEmpty) {
      // Nothing to add — but keep focus so a stray Enter doesn't kick the
      // user out of the field.
      _focusNode.requestFocus();
      return;
    }

    // Flutter unfocuses the field on submit by default, so focus is
    // re-requested both here (immediately, so the keyboard never drops) and
    // again after the write resolves.
    _focusNode.requestFocus();

    // Branch on what THIS call returned, never on addTaskProvider's state:
    // the provider is shared with the other add row on screen, so its state
    // may already describe that row's write by the time this one resumes.
    final failure = await ref
        .read(addTaskProvider.notifier)
        .addTask(spaceId: widget.spaceId, title: title);

    // The widget can be disposed mid-await (the user navigating away while
    // the write is in flight), which makes both `ref` and `context` unsafe.
    if (!mounted) return;

    if (failure != null) {
      // Typed text is deliberately left in the field — the user's words are
      // the one thing that can't be recovered if this is dropped.
      //
      // Every failure is reported here, including a NetworkFailure: addTask
      // suppresses the global offline SnackBar (announce: false) precisely so
      // this is the single place an add failure is announced. A repository
      // NetworkFailure — a socket error on a write that passed the offline
      // pre-check — reaches this same line, so it can't go unreported either.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }

    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 40,
        child: _isEditing
            ? _buildField(colors, styles)
            : _buildPlaceholder(colors, styles),
      ),
    );
  }

  Widget _buildPlaceholder(AppColors colors, AppTextStyles styles) {
    return InkWell(
      onTap: _startEditing,
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.borderStrong, width: 1.5),
            ),
            child: Text(
              '+',
              style: TextStyle(
                fontSize: 14,
                height: 1,
                color: colors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Add a task...',
            style: styles.bodyMedium.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildField(AppColors colors, AppTextStyles styles) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.borderStrong, width: 1.5),
          ),
          child: Text(
            '+',
            style: TextStyle(fontSize: 14, height: 1, color: colors.textMuted),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            textInputAction: TextInputAction.done,
            // Both off so the IME stops marking a composing region, which is
            // what draws the underline under the word being typed. There's no
            // separate switch for that underline.
            autocorrect: false,
            enableSuggestions: false,
            style: styles.bodyMedium.copyWith(color: colors.textPrimary),
            // No border, no fill, no content padding — the row itself is
            // the visual container; this should read as the placeholder row
            // having become typable, not as a form field appearing.
            decoration: InputDecoration(
              isDense: true,
              // AppTheme's global inputDecorationTheme fills every field with
              // `surface`; opted out here so the row stays flat against the
              // page instead of showing a grey box.
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: 'Add a task...',
              hintStyle: styles.bodyMedium.copyWith(color: colors.textMuted),
            ),
            onSubmitted: _onSubmitted,
          ),
        ),
      ],
    );
  }
}
