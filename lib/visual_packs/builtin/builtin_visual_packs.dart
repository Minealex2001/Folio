import '../visual_pack.dart';
import 'cozy_pack.dart';
import 'cyberpunk_pack.dart';
import 'glass_pack.dart';
import 'macos_pack.dart';
import 'material3_pack.dart';
import 'minimal_pack.dart';
import 'notion_pack.dart';
import 'obsidian_pack.dart';
import 'paper_pack.dart';
import 'retro_pack.dart';

/// Los 10 packs visuales builtin (Fase 8) — cada uno es una función pura
/// que construye un [VisualPack] tipado (tema + layout + dashboard), no un
/// archivo JSON de assets: da seguridad de tipos en tiempo de compilación y
/// el mismo pack sigue siendo exportable como el JSON idéntico que produce
/// `VisualPackExport` para un pack creado por el usuario — no hay dos
/// formatos distintos, solo dos formas de producir el mismo shape.
List<VisualPack> builtinVisualPacks() => [
  buildMaterial3Pack(),
  buildMinimalPack(),
  buildCozyPack(),
  buildPaperPack(),
  buildMacosPack(),
  buildObsidianPack(),
  buildNotionPack(),
  buildGlassPack(),
  buildRetroPack(),
  buildCyberpunkPack(),
];
