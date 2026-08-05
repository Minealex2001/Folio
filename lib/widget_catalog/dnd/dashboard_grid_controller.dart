import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../config/config_store.dart';
import '../../config/models/dashboard_config.dart';
import '../../config/models/widget_capability_overrides.dart';
import '../../config/models/widget_group_config.dart';
import '../../config/models/widget_instance_config.dart';

const _uuid = Uuid();

/// Dueño en memoria del [DashboardConfig] activo — drag/resize/reorder/
/// grupos de widgets del dashboard. Mismo patrón que
/// `LayoutEngineController` (Fase 2): mutaciones inmediatas en memoria +
/// `ValueNotifier` por instancia (para que arrastrar un widget no
/// reconstruya el dashboard entero) + persistencia debounced a
/// [ConfigStore].
class DashboardGridController extends ChangeNotifier {
  DashboardGridController(
    this._store, {
    required DashboardConfig initialConfig,
    Duration persistDebounce = const Duration(milliseconds: 400),
  }) : _config = initialConfig,
       _persistDebounce = persistDebounce {
    for (final widget in _config.widgets) {
      _instanceNotifiers[widget.instanceId] =
          ValueNotifier<WidgetInstanceConfig?>(widget);
    }
  }

  final ConfigStore _store;
  final Duration _persistDebounce;
  DashboardConfig _config;
  Timer? _persistTimer;

  final Map<String, ValueNotifier<WidgetInstanceConfig?>> _instanceNotifiers =
      {};

  static Future<DashboardGridController> load(
    ConfigStore store, {
    required String id,
    String name = 'Dashboard',
  }) async {
    final loaded = await store.loadDashboard(id);
    return DashboardGridController(
      store,
      initialConfig: loaded ?? DashboardConfig(id: id, name: name),
    );
  }

  DashboardConfig get config => _config;

  /// Expuesto para que quien ya tiene un [DashboardGridController] (p. ej.
  /// `WorkspacePage`) pueda construir un [WidgetPluginContext] sin necesitar
  /// una referencia a [ConfigStore] enhebrada por separado.
  ConfigStore get store => _store;

  WidgetInstanceConfig? instanceFor(String instanceId) =>
      _config.widgets.firstWhereOrNull((w) => w.instanceId == instanceId);

  List<WidgetInstanceConfig> widgetsInRegion(String regionId) =>
      _config.widgets.where((w) => w.regionId == regionId).sortedBy(
        (w) => w.order,
      );

  /// `ValueListenable` de una instancia concreta, para `ValueListenableBuilder`.
  ValueListenable<WidgetInstanceConfig?> listenable(String instanceId) {
    return _instanceNotifiers.putIfAbsent(
      instanceId,
      () => ValueNotifier<WidgetInstanceConfig?>(instanceFor(instanceId)),
    );
  }

  void _setWidgets(List<WidgetInstanceConfig> next) {
    _config = _config.copyWith(widgets: next);
    _reconcileNotifiers(next);
    notifyListeners();
    _schedulePersist();
  }

  /// Reemplaza el [DashboardConfig] completo (widgets, columnas, gap,
  /// grupos), conservando la id del dashboard activo — usado cuando el
  /// dashboard cambia por una vía externa a los métodos de mutación
  /// granular de este controller (ej.
  /// `AppSettings.onWorkspaceHomeDashboardChanged`, Fase 4: cada
  /// toggle/reorder legacy re-deriva un `DashboardConfig` entero desde
  /// `AppSettings`). Mismo principio que
  /// `LayoutEngineController.loadPreset`.
  void replaceConfig(DashboardConfig next) {
    _config = DashboardConfig(
      id: _config.id,
      name: next.name,
      columns: next.columns,
      gap: next.gap,
      widgets: next.widgets,
      groups: next.groups,
    );
    _reconcileNotifiers(next.widgets);
    notifyListeners();
    _schedulePersist();
  }

  /// Sincroniza `_instanceNotifiers` con [next]: notifica cada instancia
  /// tocada y limpia notifiers de instancias que ya no existen, en vez de
  /// dejarlos apuntando a un valor obsoleto.
  void _reconcileNotifiers(List<WidgetInstanceConfig> next) {
    final nextIds = next.map((w) => w.instanceId).toSet();
    for (final widget in next) {
      final notifier = _instanceNotifiers.putIfAbsent(
        widget.instanceId,
        () => ValueNotifier<WidgetInstanceConfig?>(widget),
      );
      notifier.value = widget;
    }
    for (final staleId in _instanceNotifiers.keys
        .where((id) => !nextIds.contains(id))
        .toList()) {
      _instanceNotifiers[staleId]!.value = null;
      _instanceNotifiers[staleId]!.dispose();
      _instanceNotifiers.remove(staleId);
    }
  }

  /// Mueve [instanceId] a [newRegionId] (una columna), en la posición
  /// [insertAtOrder] (al final si es null). Renumera el orden de la
  /// columna origen y destino a `0..n-1` contiguo.
  void moveToColumn(
    String instanceId,
    String newRegionId, {
    int? insertAtOrder,
  }) {
    final instance = instanceFor(instanceId);
    if (instance == null) return;
    final oldRegionId = instance.regionId;

    final rest = _config.widgets
        .where((w) => w.instanceId != instanceId)
        .toList();

    final destList = rest
        .where((w) => w.regionId == newRegionId)
        .sortedBy((w) => w.order);
    final insertIndex = (insertAtOrder ?? destList.length).clamp(
      0,
      destList.length,
    );
    destList.insert(insertIndex, instance.copyWith(regionId: newRegionId));
    final renumberedDest = [
      for (var i = 0; i < destList.length; i++) destList[i].copyWith(order: i),
    ];

    var renumberedOrigin = <WidgetInstanceConfig>[];
    if (oldRegionId != newRegionId) {
      final originList = rest
          .where((w) => w.regionId == oldRegionId)
          .sortedBy((w) => w.order);
      renumberedOrigin = [
        for (var i = 0; i < originList.length; i++)
          originList[i].copyWith(order: i),
      ];
    }

    final untouched = rest
        .where((w) => w.regionId != newRegionId && w.regionId != oldRegionId)
        .toList();

    _setWidgets([...untouched, ...renumberedOrigin, ...renumberedDest]);
  }

  /// Reordena dentro de la misma columna [regionId] — misma convención de
  /// índices que `ReorderableListView.onReorder` (newIndex ya ajustado por
  /// el caller si es necesario, ver `_reorderStringList` en
  /// `workspace_home_view.dart` para el mismo patrón).
  void reorderWithinColumn(String regionId, int oldIndex, int newIndex) {
    final list = widgetsInRegion(regionId);
    if (oldIndex < 0 ||
        oldIndex >= list.length ||
        newIndex < 0 ||
        newIndex > list.length) {
      return;
    }
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, moved);
    final renumbered = [
      for (var i = 0; i < list.length; i++) list[i].copyWith(order: i),
    ];
    final others = _config.widgets
        .where((w) => w.regionId != regionId)
        .toList();
    _setWidgets([...others, ...renumbered]);
  }

  void resizeInstance(String instanceId, {double? width, double? height}) {
    final instance = instanceFor(instanceId);
    if (instance == null) return;
    final next = instance.copyWith(width: width, height: height);
    _setWidgets([
      for (final w in _config.widgets)
        if (w.instanceId == instanceId) next else w,
    ]);
  }

  void setInstanceVisible(String instanceId, bool visible) {
    final instance = instanceFor(instanceId);
    if (instance == null || instance.visible == visible) return;
    final next = instance.copyWith(visible: visible);
    _setWidgets([
      for (final w in _config.widgets)
        if (w.instanceId == instanceId) next else w,
    ]);
  }

  void setInstanceSettings(String instanceId, Map<String, dynamic> settings) {
    final instance = instanceFor(instanceId);
    if (instance == null) return;
    final next = instance.copyWith(settings: settings);
    _setWidgets([
      for (final w in _config.widgets)
        if (w.instanceId == instanceId) next else w,
    ]);
  }

  /// Override por-instancia de `FolioWidgetPlugin.capabilities` (Fase 13).
  void setInstanceCapabilityOverrides(
    String instanceId,
    WidgetCapabilityOverrides? overrides,
  ) {
    final instance = instanceFor(instanceId);
    if (instance == null) return;
    final next = WidgetInstanceConfig(
      schemaVersion: instance.schemaVersion,
      instanceId: instance.instanceId,
      pluginId: instance.pluginId,
      regionId: instance.regionId,
      order: instance.order,
      width: instance.width,
      height: instance.height,
      visible: instance.visible,
      groupId: instance.groupId,
      settings: instance.settings,
      capabilityOverrides: overrides,
    );
    _setWidgets([
      for (final w in _config.widgets)
        if (w.instanceId == instanceId) next else w,
    ]);
  }

  /// Añade una nueva instancia de [pluginId] al final de [regionId].
  /// Devuelve la id de la instancia creada.
  String addInstance(
    String pluginId,
    String regionId, {
    Map<String, dynamic> settings = const {},
  }) {
    final instanceId = _uuid.v4();
    final order = widgetsInRegion(regionId).length;
    final instance = WidgetInstanceConfig(
      instanceId: instanceId,
      pluginId: pluginId,
      regionId: regionId,
      order: order,
      settings: settings,
    );
    _setWidgets([..._config.widgets, instance]);
    return instanceId;
  }

  /// Duplica [instanceId] (mismo plugin/settings/tamaño) justo después del
  /// original en la misma columna. Devuelve la id de la copia.
  String duplicateInstance(String instanceId) {
    final source = instanceFor(instanceId);
    if (source == null) {
      throw ArgumentError('No instance with id "$instanceId" to duplicate.');
    }
    final newId = _uuid.v4();
    final copy = WidgetInstanceConfig(
      instanceId: newId,
      pluginId: source.pluginId,
      regionId: source.regionId,
      order: source.order + 1,
      width: source.width,
      height: source.height,
      visible: source.visible,
      settings: Map<String, dynamic>.from(source.settings),
    );
    final list = widgetsInRegion(source.regionId);
    final insertIndex = list.indexWhere((w) => w.instanceId == instanceId) + 1;
    list.insert(insertIndex, copy);
    final renumbered = [
      for (var i = 0; i < list.length; i++) list[i].copyWith(order: i),
    ];
    final others = _config.widgets
        .where((w) => w.regionId != source.regionId)
        .toList();
    _setWidgets([...others, ...renumbered]);
    return newId;
  }

  void removeInstance(String instanceId) {
    final instance = instanceFor(instanceId);
    if (instance == null) return;
    final remainingInRegion = widgetsInRegion(
      instance.regionId,
    ).where((w) => w.instanceId != instanceId).toList();
    final renumbered = [
      for (var i = 0; i < remainingInRegion.length; i++)
        remainingInRegion[i].copyWith(order: i),
    ];
    final others = _config.widgets
        .where((w) => w.regionId != instance.regionId)
        .toList();
    var groups = _config.groups;
    if (instance.groupId != null) {
      groups = _pruneEmptyGroups(renumbered, others, groups);
    }
    _config = _config.copyWith(groups: groups);
    _setWidgets([...others, ...renumbered]);
  }

  // ── Grupos ──────────────────────────────────────────────────────────

  /// Agrupa [instanceIds] bajo un nuevo grupo (o [groupId] si se provee).
  /// Devuelve la id del grupo.
  String createGroup(List<String> instanceIds, {String? groupId, String? label}) {
    final id = groupId ?? _uuid.v4();
    final next = [
      for (final w in _config.widgets)
        if (instanceIds.contains(w.instanceId)) w.copyWith(groupId: id) else w,
    ];
    _config = _config.copyWith(
      groups: [
        ..._config.groups.where((g) => g.id != id),
        WidgetGroupConfig(id: id, label: label),
      ],
    );
    _setWidgets(next);
    return id;
  }

  void ungroup(String groupId) {
    final next = [
      for (final w in _config.widgets)
        if (w.groupId == groupId) w.copyWith(clearGroupId: true) else w,
    ];
    _config = _config.copyWith(
      groups: _config.groups.where((g) => g.id != groupId).toList(),
    );
    _setWidgets(next);
  }

  List<WidgetGroupConfig> _pruneEmptyGroups(
    List<WidgetInstanceConfig> a,
    List<WidgetInstanceConfig> b,
    List<WidgetGroupConfig> groups,
  ) {
    final remainingGroupIds = {
      ...a.map((w) => w.groupId),
      ...b.map((w) => w.groupId),
    }..removeWhere((id) => id == null);
    return groups.where((g) => remainingGroupIds.contains(g.id)).toList();
  }

  // ── Persistencia ────────────────────────────────────────────────────

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, () {
      unawaited(persist());
    });
  }

  Future<void> persist() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    await _store.saveDashboard(_config);
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    if (_persistTimer != null) {
      unawaited(_store.saveDashboard(_config));
    }
    for (final notifier in _instanceNotifiers.values) {
      notifier.dispose();
    }
    super.dispose();
  }
}
