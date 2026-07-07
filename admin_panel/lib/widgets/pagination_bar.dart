import 'package:flutter/material.dart';

import '../models/pagination.dart';

/// Prev/next pager with a "Page X of Y · N total" readout.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.pagination,
    required this.onPageChanged,
  });

  final Pagination? pagination;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final p = pagination;
    if (p == null || p.total == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${p.total} record${p.total == 1 ? '' : 's'} · Page ${p.page} of ${p.totalPages}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Previous page',
            icon: const Icon(Icons.chevron_left),
            onPressed: p.hasPrev ? () => onPageChanged(p.page - 1) : null,
          ),
          IconButton(
            tooltip: 'Next page',
            icon: const Icon(Icons.chevron_right),
            onPressed: p.hasNext ? () => onPageChanged(p.page + 1) : null,
          ),
        ],
      ),
    );
  }
}
