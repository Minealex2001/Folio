/// Decide si es seguro mover localmente una libreta a la papelera porque su
/// tombstone llegó desde la nube, o si hay que avisar antes por si este
/// dispositivo tiene cambios sin sincronizar que se perderían de la vista.
///
/// Seguro cuando este dispositivo ya confirmó (ack) un rev igual o posterior
/// al que tenía la libreta cuando se mandó a la papelera — es decir, no hay
/// contenido local más nuevo que el que ya se sincronizó.
bool shouldAutoTrashVaultOnRemoteTombstone({
  required int localAckedRev,
  required int remoteTrashedRev,
}) => localAckedRev >= remoteTrashedRev;
