// Re-export: los IDs canónicos de región viven en el modelo de config
// (`lib/config/models/panel_region_ids.dart`) para que `LayoutConfig` no
// dependa de la capa de widgets. El motor de layout los reexporta aquí para
// que el código que ya importa `layout_engine/` no tenga que saltar a
// `config/` para el vocabulario de IDs.
export '../config/models/panel_region_ids.dart';
