import 'package:flutter/material.dart';

/// Wraps a [DataTable] in two-axis scrolling with visible scrollbars so wide
/// tables scroll inside their own container instead of overflowing.
class TableWrapper extends StatefulWidget {
  const TableWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<TableWrapper> createState() => _TableWrapperState();
}

class _TableWrapperState extends State<TableWrapper> {
  final ScrollController _vertical = ScrollController();
  final ScrollController _horizontal = ScrollController();

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Scrollbar(
        controller: _vertical,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _vertical,
          child: Scrollbar(
            controller: _horizontal,
            thumbVisibility: true,
            notificationPredicate: (notification) => notification.depth == 1,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
