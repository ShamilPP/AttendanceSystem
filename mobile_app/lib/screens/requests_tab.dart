import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance_request.dart';
import '../providers/attendance_provider.dart';
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
      body = const LoadingView(message: 'Loading requests…');
    } else if (provider.requestsError != null && provider.requests.isEmpty) {
      body = ErrorView(
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
              child: const EmptyView(
                icon: Icons.pending_actions_rounded,
                title: 'No requests yet',
                subtitle: 'Use the + button to request a correction '
                    'for a missed check-in/out or leave.',
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: provider.requests.length +
              (provider.requestsLoadingMore ? 1 : 0),
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index >= provider.requests.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              );
            }
            return _RequestTile(request: provider.requests[index]);
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Requests'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final (label, value) = _filters[index];
                final selected = provider.requestsStatusFilter == value;
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) =>
                      provider.setRequestsStatusFilter(value),
                );
              },
            ),
          ),
        ),
      ),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewRequest,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New request'),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});

  final AttendanceRequest request;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AttendanceRequestType.label(request.type),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusChip.request(request.status, dense: true),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'For ${formatDateString(request.date)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (request.requestedCheckIn != null ||
                request.requestedCheckOut != null) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (request.requestedCheckIn != null)
                    'In: ${formatTime(request.requestedCheckIn)}',
                  if (request.requestedCheckOut != null)
                    'Out: ${formatTime(request.requestedCheckOut)}',
                ].join('   ·   '),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 8),
            Text(request.reason,
                style: Theme.of(context).textTheme.bodyMedium),
            if ((request.reviewNote ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Reviewer: ${request.reviewNote}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            if (request.createdAt != null) ...[
              const SizedBox(height: 8),
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
}
