import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_fab.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/list_screen_shortcuts.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/password_field.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'user_model.dart';
import 'users_provider.dart';

const _pageSize = 20;

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        body: Column(
          children: [
            Container(
              color: AppPalette.card,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppPalette.primary,
                unselectedLabelColor: AppPalette.textSecondary,
                indicatorColor: AppPalette.primary,
                tabs: [Tab(text: 'Users'), Tab(text: 'Roles')],
              ),
            ),
            const Expanded(child: TabBarView(children: [_UsersTab(), _RolesTab()])),
          ],
        ),
      ),
    );
  }
}

// ---------- Users ----------

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    void openCreate() => showDialog(context: context, builder: (_) => const _UserDialog());
    void refresh() => ref.invalidate(usersProvider);

    return ListScreenShortcuts(
      tabIndex: 0,
      onRefresh: refresh,
      onNew: openCreate,
      child: Scaffold(
        floatingActionButton: AppFab(onPressed: openCreate, tooltip: 'New User (Ctrl+N)', label: 'New User'),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Users & Roles',
                subtitle: 'Manage staff logins and their access levels',
                actions: [
                  OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: usersAsync.when(
                  data: (users) => AppListCard(
                    emptyMessage: 'No users yet.',
                    emptyIcon: Icons.admin_panel_settings_outlined,
                    columns: const [
                      AppListColumn('Full Name', flex: 3),
                      AppListColumn('Username', flex: 3),
                      AppListColumn('Role', flex: 2),
                      AppListColumn('Status', flex: 2),
                      AppListColumn('', flex: 1),
                    ],
                    itemCount: users.length,
                    itemsPerPage: _pageSize,
                    currentPage: _page,
                    onPageChange: (p) => setState(() => _page = p),
                    cellsBuilder: (context, i) {
                      final u = users[i];
                      return [
                        Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(u.username, style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                        Text(u.roleName, style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                        u.isActive ? StatusPill.success('Active') : StatusPill.cancelled('Inactive'),
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => showDialog(context: context, builder: (_) => _UserDialog(existing: u))),
                      ];
                    },
                  ),
                  loading: () => Card(child: SkeletonTableRows(columns: 5)),
                  error: (e, _) => Center(child: Text('Failed to load users: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserDialog extends ConsumerStatefulWidget {
  final AppUser? existing;
  const _UserDialog({this.existing});

  @override
  ConsumerState<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends ConsumerState<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  String? _roleId;
  bool _isActive = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    if (u != null) {
      _username.text = u.username;
      _fullName.text = u.fullName;
      _roleId = u.roleId;
      _isActive = u.isActive;
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_roleId == null) {
      setState(() => _error = 'Choose a role.');
      return;
    }
    if (widget.existing == null && _password.text.isEmpty) {
      setState(() => _error = 'Password is required for a new user.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final result = widget.existing == null
        ? await api.post<Map<String, dynamic>>(
            '/api/users',
            (json) => json as Map<String, dynamic>,
            body: {'username': _username.text.trim(), 'password': _password.text, 'fullName': _fullName.text.trim(), 'roleId': _roleId},
          )
        : await api.put<Map<String, dynamic>>(
            '/api/users/${widget.existing!.id}',
            (json) => json as Map<String, dynamic>,
            body: {'fullName': _fullName.text.trim(), 'roleId': _roleId, 'isActive': _isActive},
          );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(usersProvider);
        Navigator.of(context).pop();
      case ApiFailure(message: final msg):
        setState(() {
          _saving = false;
          _error = msg;
        });
      case ApiNetworkError(message: final msg):
        setState(() {
          _saving = false;
          _error = 'Could not reach the Host: $msg';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(rolesProvider);
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit User' : 'New User'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _username,
              enabled: !isEdit,
              decoration: const InputDecoration(labelText: 'Username *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Username is required' : null,
            ),
            if (!isEdit) ...[
              const SizedBox(height: 8),
              PasswordField(controller: _password),
            ],
            const SizedBox(height: 8),
            TextFormField(
              controller: _fullName,
              decoration: const InputDecoration(labelText: 'Full Name *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Full Name is required' : null,
            ),
            const SizedBox(height: 8),
            rolesAsync.when(
              data: (roles) => DropdownButtonFormField<String>(
                initialValue: _roleId,
                decoration: const InputDecoration(labelText: 'Role *'),
                items: roles.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
                onChanged: (v) => setState(() => _roleId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Could not load roles.'),
            ),
            if (isEdit)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v ?? true),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}

// ---------- Roles ----------

class _RolesTab extends ConsumerWidget {
  const _RolesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(rolesProvider);

    return ListScreenShortcuts(
      tabIndex: 1,
      onRefresh: () => ref.invalidate(rolesProvider),
      child: rolesAsync.when(
        data: (roles) => ListView(
          children: roles.map((r) => _RoleCard(role: r)).toList(),
        ),
        loading: () => Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [for (var i = 0; i < 4; i++) const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: SkeletonBox(height: 56))]),
        ),
        error: (e, _) => Center(child: Text('Failed to load roles: $e')),
      ),
    );
  }
}

class _RoleCard extends ConsumerStatefulWidget {
  final AppRole role;
  const _RoleCard({required this.role});

  @override
  ConsumerState<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends ConsumerState<_RoleCard> {
  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.role.permissions.toSet();
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final api = ref.read(apiClientProvider);
    final result = await api.put<void>(
      '/api/roles/${widget.role.id}/permissions',
      (_) {},
      body: {'permissionKeys': _selected.toList()},
    );

    if (!mounted) return;
    setState(() => _saving = false);

    switch (result) {
      case ApiSuccess():
        ref.invalidate(rolesProvider);
        AppToast.success('Permissions saved.');
      case ApiFailure(message: final msg):
        AppToast.error(msg);
      case ApiNetworkError(message: final msg):
        AppToast.error('Could not reach the Host: $msg');
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissionsAsync = ref.watch(permissionsCatalogProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        title: Text(widget.role.name),
        subtitle: Text('${_selected.length} permissions granted'),
        children: [
          permissionsAsync.when(
            data: (permissions) {
              final byModule = <String, List<AppPermission>>{};
              for (final p in permissions) {
                byModule.putIfAbsent(p.module, () => []).add(p);
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    ...byModule.entries.map((entry) => ExpansionTile(
                          title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                          initiallyExpanded: true,
                          children: entry.value
                              .map((p) => CheckboxListTile(
                                    dense: true,
                                    title: Text(p.key),
                                    subtitle: p.description == null ? null : Text(p.description!),
                                    value: _selected.contains(p.key),
                                    onChanged: (v) => setState(() {
                                      if (v == true) {
                                        _selected.add(p.key);
                                      } else {
                                        _selected.remove(p.key);
                                      }
                                    }),
                                  ))
                              .toList(),
                        )),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Save Permissions'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('Failed to load permissions: $e')),
          ),
        ],
      ),
    );
  }
}
