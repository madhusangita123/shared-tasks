import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/widgets/app_button.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/invite/domain/entities/invite.dart';
import 'package:shared_tasks/features/invite/presentation/providers/invite_provider.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';

/// S-06 — Space settings. Shows the space's name, its member list, and a
/// Share entry point (issue #31): the current invite link plus a Share
/// button that opens the native share sheet (issue #30's `shareInviteLink`).
/// The owner additionally sees a Regenerate link control; non-owner members
/// do not (UI-level gate — the real enforcement lives in the Cloud
/// Function/Firestore rules behind `regenerateInviteProvider`).
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
    final spaceState = ref.watch(spaceProvider(spaceId));
    final spaceName = spaceState.valueOrNull?.name;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          spaceName != null && spaceName.isNotEmpty
              ? spaceName
              : 'Space settings',
        ),
      ),
      body: spaceState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Something went wrong loading this space.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (space) {
          if (space == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'This space could not be found.',
                  textAlign: TextAlign.center,
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Members', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              membersState.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                // Enrichment, not critical — skip silently rather than
                // blocking the rest of the screen on a member-avatar fetch
                // failure.
                error: (error, stackTrace) => const SizedBox.shrink(),
                data: (members) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final member in members)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            _MemberAvatarCircle(member: member),
                            const SizedBox(width: 12),
                            Text(member.displayName),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Share', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(invite.shareableLink),
              ),
              const SizedBox(height: 12),
              // Builder, not the outer `context`, so `findRenderObject()`
              // resolves to this button's own RenderBox — share_plus's
              // documented pattern for `sharePositionOrigin`. Without it,
              // iOS's `UIActivityViewController.popoverPresentationController`
              // is non-nil even on iPhone on current iOS versions, and
              // share_plus's native side then errors out instead of
              // presenting anything — the share sheet silently never
              // appears.
              Builder(
                builder: (buttonContext) => AppButton(
                  label: 'Share',
                  icon: Icons.share,
                  onPressed: () {
                    final box =
                        buttonContext.findRenderObject() as RenderBox?;
                    shareInviteLink(
                      invite,
                      sharePositionOrigin: box == null
                          ? null
                          : box.localToGlobal(Offset.zero) & box.size,
                    );
                  },
                ),
              ),
              if (isOwner) ...[
                const SizedBox(height: 12),
                AppButton(
                  label: 'Regenerate link',
                  isLoading: regenerateState.isLoading,
                  onPressed: () => ref
                      .read(regenerateInviteProvider.notifier)
                      .regenerate(spaceId),
                ),
                if (regenerateState.hasError) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage(regenerateState.error),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Small member avatar for the members section — the member's photo if
/// present, otherwise the initial letter of their display name. Mirrors
/// HomeScreen's `_MemberAvatarCircle` visual logic, kept as its own private
/// widget here rather than imported (that one is private to home_screen.dart).
class _MemberAvatarCircle extends StatelessWidget {
  const _MemberAvatarCircle({required this.member});

  final MemberAvatar member;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = member.photoUrl != null && member.photoUrl!.isNotEmpty;

    return CircleAvatar(
      radius: 14,
      backgroundImage: hasPhoto ? NetworkImage(member.photoUrl!) : null,
      child: hasPhoto
          ? null
          : Text(
              member.displayName.isNotEmpty
                  ? member.displayName[0].toUpperCase()
                  : '?',
              style: Theme.of(context).textTheme.labelSmall,
            ),
    );
  }
}
