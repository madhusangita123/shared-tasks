import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_text_styles.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/invite/domain/entities/invite.dart';
import 'package:shared_tasks/features/invite/presentation/providers/invite_provider.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';
import 'package:shared_tasks/features/spaces/presentation/widgets/invite_link_box.dart';
import 'package:shared_tasks/features/spaces/presentation/widgets/member_row.dart';

/// S-06 — Space settings. Shows the space's member roster and the invite
/// link, with a "Send invite" button directly below it (issue #58's
/// redesign of issues #30/#31).
///
/// The owner additionally sees a Regenerate link control; non-owner members
/// do not. That is a UI-level gate only. The enforcement behind it is
/// `InviteRemoteDatasource.regenerateInvite`'s own `ownerUid == callerUid`
/// check, which covers every in-app path — but it is client-side:
/// `firestore.rules` allows ANY member to update a space document
/// (`allow update: if request.auth.uid in resource.data.memberUids`), and
/// there is no Cloud Function for regenerate. A member writing to Firestore
/// directly could still rotate the token.
///
/// A [ConsumerWidget] — no local mutable state needed, everything comes from
/// [spaceProvider], [spaceMembersProvider], [authStateProvider], and
/// [regenerateInviteProvider].
class SpaceSettingsScreen extends ConsumerWidget {
  const SpaceSettingsScreen({required this.spaceId, super.key});

  final String spaceId;

  /// Same no-modal inline-error convention as [SettingsScreen]'s
  /// `_errorMessage` — duplicated here since it's not shared across screens.
  String _errorMessage(Object? error) {
    if (error is AppFailure) return error.message;
    return 'Could not regenerate the link. Try again.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A non-null Invite is the success signal: build() returns null while
    // pristine, so this can't fire on first load. There is only one
    // regenerate control on this screen, so the shared-provider-state races
    // seen on the task list/detail screens don't apply.
    ref.listen<AsyncValue<Invite?>>(regenerateInviteProvider, (previous, next) {
      if (next.isLoading || next.hasError) return;
      if (next.valueOrNull == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'New invite link generated — the old one no longer works',
          ),
        ),
      );
    });

    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final spaceState = ref.watch(spaceProvider(spaceId));
    final spaceName = spaceState.valueOrNull?.name;
    final headerName = spaceName != null && spaceName.isNotEmpty
        ? spaceName
        : 'Space settings';

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: spaceState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Something went wrong loading this space.',
                textAlign: TextAlign.center,
                style: styles.bodyMedium.copyWith(color: colors.textSecondary),
              ),
            ),
          ),
          data: (space) {
            if (space == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'This space could not be found.',
                    textAlign: TextAlign.center,
                    style: styles.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              );
            }

            final invite = Invite(
              spaceId: space.id,
              token: space.inviteToken,
              expiresAt: space.inviteExpiresAt,
            );
            final currentUid = ref.watch(authStateProvider).valueOrNull?.id;
            final isOwner = currentUid != null && currentUid == space.ownerUid;
            final regenerateState = ref.watch(regenerateInviteProvider);
            final membersState = ref.watch(spaceMembersProvider(spaceId));

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BackLink(label: headerName),
                        const SizedBox(height: 12),
                        Text(
                          'Space settings',
                          style: styles.headingMedium.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        // Only when there's a real name to show — otherwise
                        // headerName's fallback would repeat the title
                        // verbatim as its own subtitle.
                        if (space.name.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            space.name,
                            style: styles.bodySmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          'MEMBERS',
                          style: styles.label.copyWith(color: colors.textMuted),
                        ),
                        const SizedBox(height: 4),
                        membersState.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          // Enrichment, not critical — skip silently rather
                          // than blocking the rest of the screen on a
                          // member-avatar fetch failure.
                          error: (error, stackTrace) => const SizedBox.shrink(),
                          data: (members) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final member in members)
                                MemberRow(
                                  member: member,
                                  isOwner: member.uid == space.ownerUid,
                                ),
                            ],
                          ),
                        ),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(vertical: 16),
                          color: colors.border,
                        ),
                        Text(
                          'INVITE LINK',
                          style: styles.label.copyWith(color: colors.textMuted),
                        ),
                        const SizedBox(height: 8),
                        InviteLinkBox(link: invite.shareableLink),
                        if (isOwner) ...[
                          const SizedBox(height: 12),
                          _RegenerateButton(
                            isLoading: regenerateState.isLoading,
                            onPressed: () => ref
                                .read(regenerateInviteProvider.notifier)
                                .regenerate(spaceId),
                          ),
                          if (regenerateState.hasError) ...[
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage(regenerateState.error),
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.danger,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                        const SizedBox(height: 12),
                        // Builder, not the outer `context`, so
                        // `findRenderObject()` resolves to this button's own
                        // RenderBox — share_plus's documented pattern for
                        // `sharePositionOrigin`. Without it, iOS's
                        // `UIActivityViewController.popoverPresentationController`
                        // is non-nil even on iPhone on current iOS versions,
                        // and share_plus's native side then errors out
                        // instead of presenting anything — the share sheet
                        // silently never appears.
                        Builder(
                          builder: (buttonContext) => _ShareButton(
                            onPressed: () {
                              final box =
                                  buttonContext.findRenderObject()
                                      as RenderBox?;
                              shareInviteLink(
                                invite,
                                sharePositionOrigin: box == null
                                    ? null
                                    : box.localToGlobal(Offset.zero) & box.size,
                              );
                            },
                          ),
                        ),
                      ],
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

/// `← {space name}` back link. A real arrow icon, not a "←" text glyph —
/// on-device testing in issue #57 showed the glyph renders nearly
/// invisibly.
class _BackLink extends StatelessWidget {
  const _BackLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return InkWell(
      onTap: () =>
          context.canPop() ? context.pop() : context.go(AppRoutes.home),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_rounded, size: 20, color: colors.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: styles.bodyMedium.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owner-only outlined "Regenerate link" button.
class _RegenerateButton extends StatelessWidget {
  const _RegenerateButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Semantics(
      button: true,
      enabled: !isLoading,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: isLoading ? null : onPressed,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: colors.primary, width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  : Text(
                      'Regenerate link',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The primary "Send invite" button, in normal content flow directly after
/// the invite link (and after Regenerate, for owners).
class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Semantics(
      button: true,
      child: Material(
        color: colors.primary,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Center(
              child: Text(
                'Send invite',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
