import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_client.dart';

/// Server-backed employee search dropdown (`GET /employees?search=`).
/// Reports the picked employee (or null when cleared) via [onSelected].
class EmployeeAutocomplete extends StatefulWidget {
  const EmployeeAutocomplete({
    super.key,
    required this.onSelected,
    this.initial,
    this.label = 'Employee',
    this.hint = 'Search by name, email or ID',
  });

  final ValueChanged<User?> onSelected;
  final User? initial;
  final String label;
  final String hint;

  @override
  State<EmployeeAutocomplete> createState() => _EmployeeAutocompleteState();
}

class _EmployeeAutocompleteState extends State<EmployeeAutocomplete> {
  static String _display(User u) =>
      '${u.employeeId.isEmpty ? '' : '${u.employeeId} · '}${u.name}';

  Future<Iterable<User>> _search(TextEditingValue value) async {
    try {
      final result = await ApiClient.instance.get('/employees', query: {
        'search': value.text.trim(),
        'limit': '20',
      });
      return result.dataList.map(User.fromJson).toList();
    } on ApiException {
      return const Iterable<User>.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<User>(
      displayStringForOption: _display,
      initialValue: widget.initial == null
          ? null
          : TextEditingValue(text: _display(widget.initial!)),
      optionsBuilder: _search,
      onSelected: widget.onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onSubmitted: (_) => onFieldSubmitted(),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.person_search_outlined, size: 20),
            suffixIcon: IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                controller.clear();
                widget.onSelected(null);
              },
            ),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 420),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final user = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(_display(user)),
                    subtitle: Text(
                      '${user.departmentName} · ${user.email}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onSelected(user),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
