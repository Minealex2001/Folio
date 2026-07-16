import '../../../l10n/generated/app_localizations.dart';

/// Textos localizados para insertar plantillas en el lienzo.
class CanvasTemplateLabels {
  const CanvasTemplateLabels({
    required this.mindmapCenter,
    required this.mindmapBranch,
    required this.flowStart,
    required this.flowProcess,
    required this.flowDecision,
    required this.flowBranchYes,
    required this.flowEnd,
    required this.flowNo,
    required this.flowEdgeYes,
    required this.flowEdgeNo,
    required this.journeyTitle,
    required this.journeyDiscover,
    required this.journeyConsider,
    required this.journeyBuy,
    required this.journeyRetain,
    required this.swotTitle,
    required this.swotStrengths,
    required this.swotWeaknesses,
    required this.swotOpportunities,
    required this.swotThreats,
  });

  factory CanvasTemplateLabels.fromL10n(AppLocalizations l10n) {
    return CanvasTemplateLabels(
      mindmapCenter: l10n.canvasTplMindmapCenter,
      mindmapBranch: l10n.canvasTplMindmapBranch,
      flowStart: l10n.canvasTplFlowStart,
      flowProcess: l10n.canvasTplFlowProcess,
      flowDecision: l10n.canvasTplFlowDecision,
      flowBranchYes: l10n.canvasTplFlowBranchYes,
      flowEnd: l10n.canvasTplFlowEnd,
      flowNo: l10n.canvasTplFlowNo,
      flowEdgeYes: l10n.canvasTplFlowEdgeYes,
      flowEdgeNo: l10n.canvasTplFlowEdgeNo,
      journeyTitle: l10n.canvasTplJourneyTitle,
      journeyDiscover: l10n.canvasTplJourneyDiscover,
      journeyConsider: l10n.canvasTplJourneyConsider,
      journeyBuy: l10n.canvasTplJourneyBuy,
      journeyRetain: l10n.canvasTplJourneyRetain,
      swotTitle: l10n.canvasTplSwotTitle,
      swotStrengths: l10n.canvasTplSwotStrengths,
      swotWeaknesses: l10n.canvasTplSwotWeaknesses,
      swotOpportunities: l10n.canvasTplSwotOpportunities,
      swotThreats: l10n.canvasTplSwotThreats,
    );
  }

  final String mindmapCenter;
  final String mindmapBranch;
  final String flowStart;
  final String flowProcess;
  final String flowDecision;
  final String flowBranchYes;
  final String flowEnd;
  final String flowNo;
  final String flowEdgeYes;
  final String flowEdgeNo;
  final String journeyTitle;
  final String journeyDiscover;
  final String journeyConsider;
  final String journeyBuy;
  final String journeyRetain;
  final String swotTitle;
  final String swotStrengths;
  final String swotWeaknesses;
  final String swotOpportunities;
  final String swotThreats;
}
