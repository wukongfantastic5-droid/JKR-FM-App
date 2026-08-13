/// Shared floor definitions for the asset inventory (me_assets.json).
///
/// Asset floors are keys L37..L1 (tower), LP1 (podium plaza), LM (mezzanine
/// band), LB1/LB2 (basement carparks). The zone labels reflect the parking
/// zone naming used in the asset register (e.g. aras P is subdivided into
/// zones P1/P1A/P2/P2A, aras M into P3/P3A/P4/P4A/MEZZ, and so on).
library;

const List<String> assetFloorOrder = [
  'L37', 'L36', 'L35', 'L34', 'L33', 'L32', 'L31', 'L30',
  'L29', 'L28', 'L27', 'L26', 'L25', 'L24', 'L23', 'L22', 'L21', 'L20',
  'L19', 'L18', 'L17', 'L16', 'L15', 'L14', 'L13', 'L12', 'L11', 'L10',
  'L9', 'L8', 'L7', 'L6', 'L5', 'L4', 'L3', 'L2', 'L1',
  'LP1', 'LM', 'LB1', 'LB2',
];

/// Short core label shown prominently, e.g. LB1 -> 'B1'.
String assetFloorCore(String key) {
  switch (key) {
    case 'LB1': return 'B1';
    case 'LB2': return 'B2';
    case 'LP1': return 'P';
    case 'LM': return 'M';
    case 'LG': return 'G';
    default: return key.replaceAll('L', '');
  }
}

/// Zone hint appended to the label, e.g. LP1 -> 'Plaza - Zon P1/P1A/P2/P2A'.
String assetFloorZone(String key) {
  switch (key) {
    case 'LB1':
    case 'LB2':
      return 'Zon parking bawah tanah';
    case 'LP1':
      return 'Plaza - Zon P1/P1A/P2/P2A';
    case 'LM':
      return 'Zon P3/P3A/P4/P4A/MEZZ';
    case 'L1':
      return 'Zon P5/P5A/P6/P6A';
    case 'L2':
      return 'Zon P7/P7A';
    case 'L3':
      return 'Zon P8/Kafe';
    default:
      return '';
  }
}

/// Full label for filter chips, e.g. 'B1 · Zon parking bawah tanah'.
String assetFloorLabel(String key) {
  final z = assetFloorZone(key);
  return '${assetFloorCore(key)}${z.isEmpty ? '' : ' · $z'}';
}