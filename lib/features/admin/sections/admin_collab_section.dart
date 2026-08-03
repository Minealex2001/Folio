import 'package:flutter/material.dart';

import '../../../app/widgets/folio_skeletons.dart';
import '../../../services/admin/admin_collab_api.dart';
import '../widgets/admin_paginated_list.dart';

class AdminCollabSection extends StatelessWidget {
  const AdminCollabSection({super.key});

  @override
  Widget build(BuildContext context) {
    const api = AdminCollabApi();
    return AdminPaginatedList(
      searchable: false,
      emptyLabel: 'Sin salas de colaboración.',
      fetch: (page, limit, query) => api.list(page: page, limit: limit),
      itemBuilder: (context, item) => ListTile(
        leading: const Icon(Icons.groups_2_outlined),
        title: Text((item['title']?.toString().trim().isNotEmpty ?? false) ? item['title'].toString() : '(sin título)'),
        subtitle: Text('owner: ${item['ownerUid']} · ${item['memberCount'] ?? 0} miembros · ${item['updatedAt'] ?? ''}'),
        onTap: () => showDialog<void>(
          context: context,
          builder: (ctx) => _RoomDetailDialog(id: item['id']?.toString() ?? '', api: api),
        ),
      ),
    );
  }
}

class _RoomDetailDialog extends StatefulWidget {
  const _RoomDetailDialog({required this.id, required this.api});

  final String id;
  final AdminCollabApi api;

  @override
  State<_RoomDetailDialog> createState() => _RoomDetailDialogState();
}

class _RoomDetailDialogState extends State<_RoomDetailDialog> {
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    widget.api.detail(widget.id).then((d) {
      if (mounted) setState(() => _detail = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final members = (_detail?['members'] as List?) ?? const [];
    return AlertDialog(
      title: const Text('Sala de colaboración'),
      content: SizedBox(
        width: 420,
        height: 320,
        child: _detail == null
            ? const Center(child: FolioLoadingIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('id: ${_detail!['id']}'),
                  Text('owner: ${_detail!['ownerUid']}'),
                  Text('contentVersion: ${_detail!['contentVersion']}'),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (context, i) {
                        final m = members[i] as Map;
                        return ListTile(
                          dense: true,
                          title: Text(m['memberUid']?.toString() ?? ''),
                          subtitle: Text('joined: ${m['joinedAt'] ?? '—'}'),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
    );
  }
}
