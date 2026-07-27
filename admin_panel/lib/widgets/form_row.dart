import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Lays form fields out side by side without letting them drift out of line.
///
/// A plain `Row` centres its children, so pairing a field that has helper text
/// with one that does not pushes the taller field's label visibly above its
/// neighbour's — the bug that made the office-settings and employee dialogs
/// look broken. This always top-aligns, and collapses to a single column when
/// there is not enough width for the fields to stay usable.
class FormRow extends StatelessWidget {
  const FormRow({
    super.key,
    required this.children,
    this.flex,
    this.stackBelow = 460,
  });

  final List<Widget> children;

  /// Relative widths, defaulting to equal. Length must match [children].
  final List<int>? flex;

  /// Below this width the fields stack instead of sharing the row.
  final double stackBelow;

  @override
  Widget build(BuildContext context) {
    assert(flex == null || flex!.length == children.length,
        'flex must have one entry per child');

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < stackBelow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              children[i],
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.md),
            Expanded(flex: flex?[i] ?? 1, child: children[i]),
          ],
        ],
      );
    });
  }
}
