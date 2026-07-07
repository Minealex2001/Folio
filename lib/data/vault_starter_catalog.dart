import '../l10n/generated/app_localizations.dart';
import '../models/block.dart';
import '../models/folio_page.dart';
import '../models/folio_usage_intent.dart';

/// Identificadores estables de páginas iniciales del catálogo.
enum VaultStarterPageKind {
  home,
  shortcuts,
  notesInbox,
  notesCapture,
  tasksDashboard,
  tasksWeekly,
  projectsHub,
  projectsMeeting,
  knowledgeIndex,
  knowledgeTopic,
  knowledgeReading,
  journalDaily,
  journalMonthly,
  studyCourse,
  studyPlan,
  quill,
}

List<VaultStarterPageKind> starterKindsForIntent(FolioUsageIntent intent) {
  switch (intent) {
    case FolioUsageIntent.notes:
      return const [
        VaultStarterPageKind.notesInbox,
        VaultStarterPageKind.notesCapture,
      ];
    case FolioUsageIntent.tasks:
      return const [
        VaultStarterPageKind.tasksDashboard,
        VaultStarterPageKind.tasksWeekly,
      ];
    case FolioUsageIntent.projects:
      return const [
        VaultStarterPageKind.projectsHub,
        VaultStarterPageKind.projectsMeeting,
      ];
    case FolioUsageIntent.knowledge:
      return const [
        VaultStarterPageKind.knowledgeIndex,
        VaultStarterPageKind.knowledgeTopic,
        VaultStarterPageKind.knowledgeReading,
      ];
    case FolioUsageIntent.journal:
      return const [
        VaultStarterPageKind.journalDaily,
        VaultStarterPageKind.journalMonthly,
      ];
    case FolioUsageIntent.study:
      return const [
        VaultStarterPageKind.studyCourse,
        VaultStarterPageKind.studyPlan,
      ];
  }
}

FolioPage buildStarterPage(
  VaultStarterPageKind kind,
  AppLocalizations l10n, {
  required FolioUsageIntent primaryIntent,
}) {
  switch (kind) {
    case VaultStarterPageKind.home:
      return _buildHomePage(l10n, primaryIntent);
    case VaultStarterPageKind.shortcuts:
      return _buildShortcutsPage(l10n);
    case VaultStarterPageKind.notesInbox:
      return _buildSimplePage(
        id: 'starter_notes_inbox',
        title: l10n.vaultStarterNotesInboxTitle,
        heading: l10n.vaultStarterNotesInboxHeading,
        intro: l10n.vaultStarterNotesInboxIntro,
        section: l10n.vaultStarterNotesInboxSection,
        bullets: [
          l10n.vaultStarterNotesInboxBullet1,
          l10n.vaultStarterNotesInboxBullet2,
          l10n.vaultStarterNotesInboxBullet3,
        ],
        todos: [
          l10n.vaultStarterNotesInboxTodo1,
          l10n.vaultStarterNotesInboxTodo2,
        ],
        callout: l10n.vaultStarterNotesInboxCallout,
        icon: '💡',
      );
    case VaultStarterPageKind.notesCapture:
      return _buildSimplePage(
        id: 'starter_notes_capture',
        title: l10n.vaultStarterNotesCaptureTitle,
        heading: l10n.vaultStarterNotesCaptureHeading,
        intro: l10n.vaultStarterNotesCaptureIntro,
        section: l10n.vaultStarterNotesCaptureSection,
        bullets: [
          l10n.vaultStarterNotesCaptureBullet1,
          l10n.vaultStarterNotesCaptureBullet2,
          l10n.vaultStarterNotesCaptureBullet3,
        ],
        todos: [
          l10n.vaultStarterNotesCaptureTodo1,
          l10n.vaultStarterNotesCaptureTodo2,
        ],
        callout: l10n.vaultStarterNotesCaptureCallout,
        icon: '⚡',
      );
    case VaultStarterPageKind.tasksDashboard:
      return _buildSimplePage(
        id: 'starter_tasks_dashboard',
        title: l10n.vaultStarterTasksDashboardTitle,
        heading: l10n.vaultStarterTasksDashboardHeading,
        intro: l10n.vaultStarterTasksDashboardIntro,
        section: l10n.vaultStarterTasksDashboardSection,
        bullets: [
          l10n.vaultStarterTasksDashboardBullet1,
          l10n.vaultStarterTasksDashboardBullet2,
          l10n.vaultStarterTasksDashboardBullet3,
        ],
        todos: [
          l10n.vaultStarterTasksDashboardTodo1,
          l10n.vaultStarterTasksDashboardTodo2,
        ],
        callout: l10n.vaultStarterTasksDashboardCallout,
        icon: '✅',
      );
    case VaultStarterPageKind.tasksWeekly:
      return _buildSimplePage(
        id: 'starter_tasks_weekly',
        title: l10n.vaultStarterTasksWeeklyTitle,
        heading: l10n.vaultStarterTasksWeeklyHeading,
        intro: l10n.vaultStarterTasksWeeklyIntro,
        section: l10n.vaultStarterTasksWeeklySection,
        bullets: [
          l10n.vaultStarterTasksWeeklyBullet1,
          l10n.vaultStarterTasksWeeklyBullet2,
          l10n.vaultStarterTasksWeeklyBullet3,
        ],
        todos: [
          l10n.vaultStarterTasksWeeklyTodo1,
          l10n.vaultStarterTasksWeeklyTodo2,
        ],
        callout: l10n.vaultStarterTasksWeeklyCallout,
        icon: '📅',
      );
    case VaultStarterPageKind.projectsHub:
      return _buildSimplePage(
        id: 'starter_projects_hub',
        title: l10n.vaultStarterProjectsHubTitle,
        heading: l10n.vaultStarterProjectsHubHeading,
        intro: l10n.vaultStarterProjectsHubIntro,
        section: l10n.vaultStarterProjectsHubSection,
        bullets: [
          l10n.vaultStarterProjectsHubBullet1,
          l10n.vaultStarterProjectsHubBullet2,
          l10n.vaultStarterProjectsHubBullet3,
        ],
        todos: [
          l10n.vaultStarterProjectsHubTodo1,
          l10n.vaultStarterProjectsHubTodo2,
        ],
        callout: l10n.vaultStarterProjectsHubCallout,
        icon: '📁',
      );
    case VaultStarterPageKind.projectsMeeting:
      return _buildSimplePage(
        id: 'starter_projects_meeting',
        title: l10n.vaultStarterProjectsMeetingTitle,
        heading: l10n.vaultStarterProjectsMeetingHeading,
        intro: l10n.vaultStarterProjectsMeetingIntro,
        section: l10n.vaultStarterProjectsMeetingSection,
        bullets: [
          l10n.vaultStarterProjectsMeetingBullet1,
          l10n.vaultStarterProjectsMeetingBullet2,
          l10n.vaultStarterProjectsMeetingBullet3,
        ],
        todos: [
          l10n.vaultStarterProjectsMeetingTodo1,
          l10n.vaultStarterProjectsMeetingTodo2,
        ],
        callout: l10n.vaultStarterProjectsMeetingCallout,
        icon: '📝',
      );
    case VaultStarterPageKind.knowledgeIndex:
      return _buildSimplePage(
        id: 'starter_knowledge_index',
        title: l10n.vaultStarterKnowledgeIndexTitle,
        heading: l10n.vaultStarterKnowledgeIndexHeading,
        intro: l10n.vaultStarterKnowledgeIndexIntro,
        section: l10n.vaultStarterKnowledgeIndexSection,
        bullets: [
          l10n.vaultStarterKnowledgeIndexBullet1,
          l10n.vaultStarterKnowledgeIndexBullet2,
          l10n.vaultStarterKnowledgeIndexBullet3,
        ],
        todos: [
          l10n.vaultStarterKnowledgeIndexTodo1,
          l10n.vaultStarterKnowledgeIndexTodo2,
        ],
        callout: l10n.vaultStarterKnowledgeIndexCallout,
        icon: '🗺️',
      );
    case VaultStarterPageKind.knowledgeTopic:
      return _buildSimplePage(
        id: 'starter_knowledge_topic',
        title: l10n.vaultStarterKnowledgeTopicTitle,
        heading: l10n.vaultStarterKnowledgeTopicHeading,
        intro: l10n.vaultStarterKnowledgeTopicIntro,
        section: l10n.vaultStarterKnowledgeTopicSection,
        bullets: [
          l10n.vaultStarterKnowledgeTopicBullet1,
          l10n.vaultStarterKnowledgeTopicBullet2,
          l10n.vaultStarterKnowledgeTopicBullet3,
        ],
        todos: [
          l10n.vaultStarterKnowledgeTopicTodo1,
          l10n.vaultStarterKnowledgeTopicTodo2,
        ],
        callout: l10n.vaultStarterKnowledgeTopicCallout,
        icon: '📚',
      );
    case VaultStarterPageKind.knowledgeReading:
      return _buildSimplePage(
        id: 'starter_knowledge_reading',
        title: l10n.vaultStarterKnowledgeReadingTitle,
        heading: l10n.vaultStarterKnowledgeReadingHeading,
        intro: l10n.vaultStarterKnowledgeReadingIntro,
        section: l10n.vaultStarterKnowledgeReadingSection,
        bullets: [
          l10n.vaultStarterKnowledgeReadingBullet1,
          l10n.vaultStarterKnowledgeReadingBullet2,
          l10n.vaultStarterKnowledgeReadingBullet3,
        ],
        todos: [
          l10n.vaultStarterKnowledgeReadingTodo1,
          l10n.vaultStarterKnowledgeReadingTodo2,
        ],
        callout: l10n.vaultStarterKnowledgeReadingCallout,
        icon: '📖',
      );
    case VaultStarterPageKind.journalDaily:
      return _buildSimplePage(
        id: 'starter_journal_daily',
        title: l10n.vaultStarterJournalDailyTitle,
        heading: l10n.vaultStarterJournalDailyHeading,
        intro: l10n.vaultStarterJournalDailyIntro,
        section: l10n.vaultStarterJournalDailySection,
        bullets: [
          l10n.vaultStarterJournalDailyBullet1,
          l10n.vaultStarterJournalDailyBullet2,
          l10n.vaultStarterJournalDailyBullet3,
        ],
        todos: [
          l10n.vaultStarterJournalDailyTodo1,
          l10n.vaultStarterJournalDailyTodo2,
        ],
        callout: l10n.vaultStarterJournalDailyCallout,
        icon: '🌅',
      );
    case VaultStarterPageKind.journalMonthly:
      return _buildSimplePage(
        id: 'starter_journal_monthly',
        title: l10n.vaultStarterJournalMonthlyTitle,
        heading: l10n.vaultStarterJournalMonthlyHeading,
        intro: l10n.vaultStarterJournalMonthlyIntro,
        section: l10n.vaultStarterJournalMonthlySection,
        bullets: [
          l10n.vaultStarterJournalMonthlyBullet1,
          l10n.vaultStarterJournalMonthlyBullet2,
          l10n.vaultStarterJournalMonthlyBullet3,
        ],
        todos: [
          l10n.vaultStarterJournalMonthlyTodo1,
          l10n.vaultStarterJournalMonthlyTodo2,
        ],
        callout: l10n.vaultStarterJournalMonthlyCallout,
        icon: '🌙',
      );
    case VaultStarterPageKind.studyCourse:
      return _buildSimplePage(
        id: 'starter_study_course',
        title: l10n.vaultStarterStudyCourseTitle,
        heading: l10n.vaultStarterStudyCourseHeading,
        intro: l10n.vaultStarterStudyCourseIntro,
        section: l10n.vaultStarterStudyCourseSection,
        bullets: [
          l10n.vaultStarterStudyCourseBullet1,
          l10n.vaultStarterStudyCourseBullet2,
          l10n.vaultStarterStudyCourseBullet3,
        ],
        todos: [
          l10n.vaultStarterStudyCourseTodo1,
          l10n.vaultStarterStudyCourseTodo2,
        ],
        callout: l10n.vaultStarterStudyCourseCallout,
        icon: '🎓',
      );
    case VaultStarterPageKind.studyPlan:
      return _buildSimplePage(
        id: 'starter_study_plan',
        title: l10n.vaultStarterStudyPlanTitle,
        heading: l10n.vaultStarterStudyPlanHeading,
        intro: l10n.vaultStarterStudyPlanIntro,
        section: l10n.vaultStarterStudyPlanSection,
        bullets: [
          l10n.vaultStarterStudyPlanBullet1,
          l10n.vaultStarterStudyPlanBullet2,
          l10n.vaultStarterStudyPlanBullet3,
        ],
        todos: [
          l10n.vaultStarterStudyPlanTodo1,
          l10n.vaultStarterStudyPlanTodo2,
        ],
        callout: l10n.vaultStarterStudyPlanCallout,
        icon: '📆',
      );
    case VaultStarterPageKind.quill:
      return _buildQuillPage(l10n);
  }
}

FolioPage _buildHomePage(AppLocalizations l10n, FolioUsageIntent primary) {
  final intro = _homeIntroFor(l10n, primary);
  final todos = _homeTodosFor(l10n, primary);
  return FolioPage(
    id: 'starter_home',
    title: l10n.vaultStarterHomeTitle,
    blocks: [
      FolioBlock(id: 'starter_home_b0', type: 'h1', text: l10n.vaultStarterHomeHeading),
      FolioBlock(id: 'starter_home_b1', type: 'paragraph', text: intro),
      FolioBlock(
        id: 'starter_home_b2',
        type: 'callout',
        text: l10n.vaultStarterHomeCallout,
        icon: '💡',
      ),
      FolioBlock(
        id: 'starter_home_b3',
        type: 'h2',
        text: l10n.vaultStarterHomeSectionTips,
      ),
      FolioBlock(
        id: 'starter_home_b4',
        type: 'bullet',
        text: l10n.vaultStarterHomeBulletSlash,
      ),
      FolioBlock(
        id: 'starter_home_b5',
        type: 'bullet',
        text: l10n.vaultStarterHomeBulletSidebar,
      ),
      FolioBlock(
        id: 'starter_home_b6',
        type: 'bullet',
        text: l10n.vaultStarterHomeBulletSettings,
      ),
      FolioBlock(id: 'starter_home_b7', type: 'divider', text: ''),
      FolioBlock(
        id: 'starter_home_b8',
        type: 'todo',
        text: todos.$1,
        checked: false,
      ),
      FolioBlock(
        id: 'starter_home_b9',
        type: 'todo',
        text: todos.$2,
        checked: false,
      ),
      FolioBlock(
        id: 'starter_home_b10',
        type: 'todo',
        text: todos.$3,
        checked: false,
      ),
    ],
  );
}

FolioPage _buildShortcutsPage(AppLocalizations l10n) {
  return FolioPage(
    id: 'starter_shortcuts',
    title: l10n.vaultStarterShortcutsTitle,
    blocks: [
      FolioBlock(
        id: 'starter_shortcuts_b0',
        type: 'h2',
        text: l10n.vaultStarterShortcutsSectionMain,
      ),
      FolioBlock(
        id: 'starter_shortcuts_b1',
        type: 'bullet',
        text: l10n.vaultStarterShortcutsBullet1,
      ),
      FolioBlock(
        id: 'starter_shortcuts_b2',
        type: 'bullet',
        text: l10n.vaultStarterShortcutsBullet2,
      ),
      FolioBlock(
        id: 'starter_shortcuts_b3',
        type: 'bullet',
        text: l10n.vaultStarterShortcutsBullet3,
      ),
      FolioBlock(
        id: 'starter_shortcuts_b4',
        type: 'h2',
        text: l10n.vaultStarterShortcutsSectionKeys,
      ),
      FolioBlock(
        id: 'starter_shortcuts_b5',
        type: 'bullet',
        text: l10n.vaultStarterShortcutsKeyN,
      ),
      FolioBlock(
        id: 'starter_shortcuts_b6',
        type: 'bullet',
        text: l10n.vaultStarterShortcutsKeySearch,
      ),
      FolioBlock(
        id: 'starter_shortcuts_b7',
        type: 'bullet',
        text: l10n.vaultStarterShortcutsKeySettings,
      ),
      FolioBlock(
        id: 'starter_shortcuts_b8',
        type: 'callout',
        text: l10n.vaultStarterShortcutsCallout,
        icon: '⌨️',
      ),
    ],
  );
}

FolioPage _buildQuillPage(AppLocalizations l10n) {
  return FolioPage(
    id: 'starter_quill',
    title: l10n.vaultStarterQuillTitle,
    blocks: [
      FolioBlock(
        id: 'starter_quill_b0',
        type: 'h2',
        text: l10n.vaultStarterQuillSectionWhat,
      ),
      FolioBlock(
        id: 'starter_quill_b1',
        type: 'bullet',
        text: l10n.vaultStarterQuillBullet1,
      ),
      FolioBlock(
        id: 'starter_quill_b2',
        type: 'bullet',
        text: l10n.vaultStarterQuillBullet2,
      ),
      FolioBlock(
        id: 'starter_quill_b3',
        type: 'bullet',
        text: l10n.vaultStarterQuillBullet3,
      ),
      FolioBlock(
        id: 'starter_quill_b4',
        type: 'h2',
        text: l10n.vaultStarterQuillSectionPrivacy,
      ),
      FolioBlock(
        id: 'starter_quill_b5',
        type: 'paragraph',
        text: l10n.vaultStarterQuillPrivacyBody,
      ),
      FolioBlock(
        id: 'starter_quill_b6',
        type: 'callout',
        text: l10n.vaultStarterQuillBackupCallout,
        icon: '🔐',
      ),
    ],
  );
}

FolioPage _buildSimplePage({
  required String id,
  required String title,
  required String heading,
  required String intro,
  required String section,
  required List<String> bullets,
  required List<String> todos,
  required String callout,
  required String icon,
}) {
  final blocks = <FolioBlock>[
    FolioBlock(id: '${id}_b0', type: 'h1', text: heading),
    FolioBlock(id: '${id}_b1', type: 'paragraph', text: intro),
    FolioBlock(id: '${id}_b2', type: 'h2', text: section),
  ];
  var blockIndex = 3;
  for (final bullet in bullets) {
    blocks.add(
      FolioBlock(
        id: '${id}_b$blockIndex',
        type: 'bullet',
        text: bullet,
      ),
    );
    blockIndex++;
  }
  blocks.add(
    FolioBlock(
      id: '${id}_b$blockIndex',
      type: 'callout',
      text: callout,
      icon: icon,
    ),
  );
  blockIndex++;
  blocks.add(FolioBlock(id: '${id}_b$blockIndex', type: 'divider', text: ''));
  blockIndex++;
  for (final todo in todos) {
    blocks.add(
      FolioBlock(
        id: '${id}_b$blockIndex',
        type: 'todo',
        text: todo,
        checked: false,
      ),
    );
    blockIndex++;
  }
  return FolioPage(id: id, title: title, blocks: blocks);
}

String _homeIntroFor(AppLocalizations l10n, FolioUsageIntent intent) {
  switch (intent) {
    case FolioUsageIntent.notes:
      return l10n.vaultStarterHomeIntroNotes;
    case FolioUsageIntent.tasks:
      return l10n.vaultStarterHomeIntroTasks;
    case FolioUsageIntent.projects:
      return l10n.vaultStarterHomeIntroProjects;
    case FolioUsageIntent.knowledge:
      return l10n.vaultStarterHomeIntroKnowledge;
    case FolioUsageIntent.journal:
      return l10n.vaultStarterHomeIntroJournal;
    case FolioUsageIntent.study:
      return l10n.vaultStarterHomeIntroStudy;
  }
}

(String, String, String) _homeTodosFor(
  AppLocalizations l10n,
  FolioUsageIntent intent,
) {
  switch (intent) {
    case FolioUsageIntent.notes:
      return (
        l10n.vaultStarterHomeTodoNotes1,
        l10n.vaultStarterHomeTodoNotes2,
        l10n.vaultStarterHomeTodoNotes3,
      );
    case FolioUsageIntent.tasks:
      return (
        l10n.vaultStarterHomeTodoTasks1,
        l10n.vaultStarterHomeTodoTasks2,
        l10n.vaultStarterHomeTodoTasks3,
      );
    case FolioUsageIntent.projects:
      return (
        l10n.vaultStarterHomeTodoProjects1,
        l10n.vaultStarterHomeTodoProjects2,
        l10n.vaultStarterHomeTodoProjects3,
      );
    case FolioUsageIntent.knowledge:
      return (
        l10n.vaultStarterHomeTodoKnowledge1,
        l10n.vaultStarterHomeTodoKnowledge2,
        l10n.vaultStarterHomeTodoKnowledge3,
      );
    case FolioUsageIntent.journal:
      return (
        l10n.vaultStarterHomeTodoJournal1,
        l10n.vaultStarterHomeTodoJournal2,
        l10n.vaultStarterHomeTodoJournal3,
      );
    case FolioUsageIntent.study:
      return (
        l10n.vaultStarterHomeTodoStudy1,
        l10n.vaultStarterHomeTodoStudy2,
        l10n.vaultStarterHomeTodoStudy3,
      );
  }
}
