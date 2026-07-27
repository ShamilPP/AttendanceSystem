import 'package:flutter/material.dart';

import '../router/routes.dart';
import '../widgets/page_scaffold.dart';
import 'catalog_screen.dart';
import 'employees_screen.dart';

enum PeopleTab { employees, catalog }

/// Employee records and the catalogs that classify them.
///
/// Departments and designations only exist to be assigned to employees, so
/// they belong beside them rather than as their own nav entries. (The old nav
/// also labelled this screen "Departments" while it contained both.)
class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key, required this.tab});

  final PeopleTab tab;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'People',
      description: switch (tab) {
        PeopleTab.employees =>
          'Add, edit, import and export your employee records.',
        PeopleTab.catalog =>
          'Departments and designations available when assigning employees.',
      },
      currentRoute: switch (tab) {
        PeopleTab.employees => Routes.peopleEmployees,
        PeopleTab.catalog => Routes.peopleCatalog,
      },
      tabs: const [
        SectionTab(
          label: 'Employees',
          icon: Icons.people_alt_outlined,
          route: Routes.peopleEmployees,
        ),
        SectionTab(
          label: 'Departments & roles',
          icon: Icons.account_tree_outlined,
          route: Routes.peopleCatalog,
        ),
      ],
      child: switch (tab) {
        PeopleTab.employees => const EmployeesScreen(),
        PeopleTab.catalog => const CatalogScreen(),
      },
    );
  }
}
