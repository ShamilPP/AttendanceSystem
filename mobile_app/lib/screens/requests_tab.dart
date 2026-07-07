import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance_request.dart';
import '../providers/attendance_provider.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';
import '../widgets/async_states.dart';
import '../widgets/status_chip.dart';
import 'new_request_screen.dart';

/// The employee's own attendance-regularization requests.
class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  final ScrollController _scrollController = ScrollController();

  static const _filters = <(String label, String? value)>[
    ('All', null),
    ('Pending', AttendanceRequestStatus.pending),
    ('Approved', AttendanceRequestStatus.approved),
    ('Rejected', AttendanceRequestStatus.rejected),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AttendanceProvider>();
      if (!provider.requestsLoaded) provider.loadRequests();
    });
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      context.read<AttendanceProvider>().loadMoreRequests();
    }
  }

  Future<void> _openNewRequest() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NewRequestScreen()),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted for review.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();

    Widget body;
    if (provider.requestsLoading && !provider.requestsLoaded) {
      body = const LoadingState(message: 'Loading requests…');
    } else if (provider.requestsError != null && provider.requests.isEmpty) {
      body = ErrorState(
        message: provider.requestsError!,
        onRetry: () => provider.loadRequests(refresh: true),
      );
    } else if (provider.requests.isEmpty) {
      body = RefreshIndicator(
        onRefresh: () => provider.loadRequests(refresh: true),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: const EmptyState(
                icon: Icons.pending_actions_rounded,
                title: 'No requests yet',
                message: 'Tap the button below to request a correction for a '
                    'missed check-in/out or leave.',
              ),
            ),
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => provider.loadRequests(refresh: true),
        child: ListView.separated(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
          itemCount: provider.requests.length +
              (provider.requestsLoadingMore ? 1 : 0),
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            if (index >= provider.requests.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              );
            }
            return _RequestCard(request: provider.requests[index]);
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Requests')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: _filters.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final (label, value) = _filters[index];
                final selected = provider.requestsStatusFilter == value;
                return Center(
                  child: FilterChip(
                    label: Text(label),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) => provider.setRequestsStatusFilter(value),
                  ),
                );
              },
            ),
          ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewRequest,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New request'),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final AttendanceRequest request;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_iconFor(request.type),
                      size: 22, color: scheme.onSecondaryContainer),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AttendanceRequestType.label(request.type),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'For ${formatDateString(request.date)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                StatusChip.request(request.status, dense: true),
              ],
            ),
            if (request.requestedCheckIn != null ||
                request.requestedCheckOut != null) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  if (request.requestedCheckIn != null)
                    StatusChip(
                      label: 'In ${formatTime(request.requestedCheckIn)}',
                      color: scheme.primary,
                      icon: Icons.login_rounded,
                      dense: true,
                    ),
                  if (request.requestedCheckOut != null)
                    StatusChip(
                      label: 'Out ${formatTime(request.requestedCheckOut)}',
                      color: scheme.primary,
                      icon: Icons.logout_rounded,
                      dense: true,
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(request.reason,
                style: Theme.of(context).textTheme.bodyMedium),
            if ((request.reviewNote ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: AppRadius.fieldR,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.rate_review_outlined,
                        size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        request.reviewNote!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (request.createdAt != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Submitted ${formatDateTime(request.createdAt)}',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case AttendanceRequestType.missedCheckIn:
        return Icons.login_rounded;
      case AttendanceRequestType.missedCheckOut:
        return Icons.logout_rounded;
      case AttendanceRequestType.fullDay:
        return Icons.today_rounded;
      case AttendanceRequestType.leave:
        return Icons.beach_access_rounded;
      default:
        return Icons.event_note_rounded;
    }
  }
}
