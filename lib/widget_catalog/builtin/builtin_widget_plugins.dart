import '../widget_catalog_registry.dart';
import 'activity_widget_plugin.dart';
import 'agenda_widget_plugin.dart';
import 'bookmarks_widget_plugin.dart';
import 'books_widget_plugin.dart';
import 'calendar_widget_plugin.dart';
import 'clock_widget_plugin.dart';
import 'create_page_widget_plugin.dart';
import 'daily_brief_widget_plugin.dart';
import 'daily_notes_widget_plugin.dart';
import 'database_view_widget_plugin.dart';
import 'favorite_page_widget_plugin.dart';
import 'folio_cloud_widget_plugin.dart';
import 'github_widget_plugin.dart';
import 'habits_widget_plugin.dart';
import 'mini_stats_widget_plugin.dart';
import 'music_widget_plugin.dart';
import 'onboarding_widget_plugin.dart';
import 'quick_actions_widget_plugin.dart';
import 'recents_widget_plugin.dart';
import 'root_pages_widget_plugin.dart';
import 'rss_widget_plugin.dart';
import 'search_widget_plugin.dart';
import 'tasks_widget_plugin.dart';
import 'tip_widget_plugin.dart';
import 'vault_status_widget_plugin.dart';
import 'weather_widget_plugin.dart';
import 'whats_new_widget_plugin.dart';

/// Registra todos los plugins built-in del catálogo. Llamado una sola vez
/// en el bootstrap de `main.dart`, antes de `runApp()`. Añadir un plugin
/// nuevo es un archivo en `builtin/` + una línea aquí — nunca requiere
/// tocar `workspace_home_view.dart` ni el motor de layout.
void registerBuiltinWidgetPlugins() {
  final r = WidgetCatalogRegistry.instance;

  // Migrados 1:1 de WorkspaceHomeSectionIds.
  r.register(const FolioCloudWidgetPlugin());
  r.register(const VaultStatusWidgetPlugin());
  r.register(const OnboardingWidgetPlugin());
  r.register(const WhatsNewWidgetPlugin());
  r.register(const SearchWidgetPlugin());
  r.register(const RootPagesWidgetPlugin());
  r.register(const MiniStatsWidgetPlugin());
  r.register(const RecentsWidgetPlugin());
  r.register(const TasksWidgetPlugin());
  r.register(const QuickActionsWidgetPlugin());
  r.register(const TipWidgetPlugin());
  r.register(const CreatePageWidgetPlugin());

  // Catálogo nuevo pedido en el brief.
  r.register(const CalendarWidgetPlugin());
  r.register(const AgendaWidgetPlugin());
  r.register(const DailyNotesWidgetPlugin());
  r.register(const HabitsWidgetPlugin());
  r.register(const BooksWidgetPlugin());
  r.register(const MusicWidgetPlugin());
  r.register(const GithubWidgetPlugin());
  r.register(const DatabaseViewWidgetPlugin());
  r.register(const FavoritePageWidgetPlugin());
  r.register(const BookmarksWidgetPlugin());
  r.register(const WeatherWidgetPlugin());
  r.register(const ClockWidgetPlugin());
  r.register(const RssWidgetPlugin());
  r.register(const ActivityWidgetPlugin());
  r.register(const DailyBriefWidgetPlugin());
}
