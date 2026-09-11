import '../config/models/dashboard_config.dart';
import 'builtin/developer_template.dart';
import 'builtin/gaming_template.dart';
import 'builtin/planning_template.dart';
import 'builtin/research_template.dart';
import 'builtin/student_template.dart';
import 'builtin/writer_template.dart';

/// Metadatos + factory de una plantilla de dashboard intercambiable (Fase
/// 30, punto 5 del brief) — refleja `builtin_visual_packs.dart` (Fase 8):
/// una lista de registro, cada entrada un factory tipado, no JSON assets.
class DashboardTemplateEntry {
  const DashboardTemplateEntry({
    required this.id,
    required this.displayName,
    required this.build,
  });

  final String id;
  final String displayName;
  final DashboardConfig Function() build;
}

final List<DashboardTemplateEntry> kBuiltinDashboardTemplates = [
  DashboardTemplateEntry(
    id: 'template-developer',
    displayName: 'Developer',
    build: developerDashboardTemplate,
  ),
  DashboardTemplateEntry(
    id: 'template-writer',
    displayName: 'Writer',
    build: writerDashboardTemplate,
  ),
  DashboardTemplateEntry(
    id: 'template-research',
    displayName: 'Research',
    build: researchDashboardTemplate,
  ),
  DashboardTemplateEntry(
    id: 'template-student',
    displayName: 'Student',
    build: studentDashboardTemplate,
  ),
  DashboardTemplateEntry(
    id: 'template-planning',
    displayName: 'Planning',
    build: planningDashboardTemplate,
  ),
  DashboardTemplateEntry(
    id: 'template-gaming',
    displayName: 'Gaming',
    build: gamingDashboardTemplate,
  ),
];

DashboardTemplateEntry? dashboardTemplateById(String id) {
  for (final entry in kBuiltinDashboardTemplates) {
    if (entry.id == id) return entry;
  }
  return null;
}
