import '../../l10n/generated/app_localizations.dart';
import '../../models/folio_usage_intent.dart';

/// Headline personalizado para el pitch de Folio Cloud según el perfil de uso.
String folioCloudOnboardingPitchHeadline(
  AppLocalizations l10n,
  FolioUsageIntent? primary,
) {
  switch (primary ?? FolioUsageIntent.notes) {
    case FolioUsageIntent.notes:
      return l10n.onboardingFolioCloudPitchForNotes;
    case FolioUsageIntent.journal:
      return l10n.onboardingFolioCloudPitchForJournal;
    case FolioUsageIntent.tasks:
      return l10n.onboardingFolioCloudPitchForTasks;
    case FolioUsageIntent.projects:
      return l10n.onboardingFolioCloudPitchForProjects;
    case FolioUsageIntent.knowledge:
      return l10n.onboardingFolioCloudPitchForKnowledge;
    case FolioUsageIntent.study:
      return l10n.onboardingFolioCloudPitchForStudy;
  }
}

/// Índice de la tarjeta de feature a destacar (0=backup, 1=AI, 2=web).
int folioCloudHighlightFeatureIndex(FolioUsageIntent? primary) {
  switch (primary ?? FolioUsageIntent.notes) {
    case FolioUsageIntent.notes:
    case FolioUsageIntent.journal:
      return 0;
    case FolioUsageIntent.tasks:
    case FolioUsageIntent.projects:
      return 2;
    case FolioUsageIntent.knowledge:
    case FolioUsageIntent.study:
      return 1;
  }
}
