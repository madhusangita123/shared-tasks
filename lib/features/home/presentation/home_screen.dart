import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/features/home/domain/entities/home_space.dart';
import 'package:shared_tasks/features/home/domain/entities/member_avatar.dart';
import 'package:shared_tasks/features/home/presentation/providers/home_provider.dart';

/// S-02 — Home screen. Lists every space the signed-in user owns or is a
/// member of, ordered by most recently updated (already sorted by
/// [userSpacesProvider]'s query).
///
/// Presentation only — calls [userSpacesProvider], never Firestore or the
/// repository directly.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacesState = ref.watch(userSpacesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SharedTasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            // push, not go — go replaces the current route with no way
            // back; push adds to the stack so the AppBar's automatic back
            // arrow (and system back gesture) work correctly.
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: spacesState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Something went wrong loading your spaces.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (spaces) {
          if (spaces.isEmpty) return const _EmptyState();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: spaces.length,
            itemBuilder: (context, index) => _SpaceCard(space: spaces[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        // push, not go — same reasoning as the settings icon above.
        onPressed: () => context.push(AppRoutes.createSpace),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Friendly prompt shown when the user has no spaces yet.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No spaces yet',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first space to get started',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// One space in the home list. Shows the name, open task count, a
/// private/shared indicator, and — for shared spaces only — a row of
/// member avatars.
class _SpaceCard extends StatelessWidget {
  const _SpaceCard({required this.space});

  final HomeSpace space;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    space.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(
                  space.isShared ? Icons.people : Icons.lock_outline,
                  size: 18,
                  color: outline,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              space.openTaskCount == 0
                  ? 'No open tasks'
                  : '${space.openTaskCount} open '
                        '${space.openTaskCount == 1 ? 'task' : 'tasks'}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: outline),
            ),
            if (space.isShared && space.memberAvatars.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 28,
                child: Row(
                  children: [
                    for (final member in space.memberAvatars)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _MemberAvatarCircle(member: member),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small member avatar for a shared space's card — the member's photo if
/// present, otherwise the initial letter of their display name.
///
/// Simpler than [SettingsScreen]'s `_ProfileAvatar`: no broken-image
/// fallback state, since card avatars are smaller and lower-stakes.
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
