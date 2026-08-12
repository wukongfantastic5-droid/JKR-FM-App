import 'dart:convert';
import 'dart:typed_data';

/// Shared STORE-only ZIP writer used by the docx/xlsx services and the
/// database backup. Verified against .NET ZipFile and MS Office.
class ZipWriter {
  static Uint8List store(Map<String, List<int>> files) {
    final local = BytesBuilder();
    final central = BytesBuilder();
    var offset = 0;
    final crcTable = _crcTable();

    for (final e in files.entries) {
      final name = utf8.encode(e.key);
      final data = e.value;
      int crc = 0xFFFFFFFF;
      for (final b in data) {
        crc = crcTable[(crc ^ b) & 0xFF] ^ (crc >> 8);
      }
      crc = crc ^ 0xFFFFFFFF;
      final n = name.length;
      local.add(le32(0x04034B50));
      local.add(le16(20));
      local.add(le16(0));
      local.add(le16(0));
      local.add(le16(0x21));
      local.add(le16(0x4E31));
      local.add(le32(crc));
      local.add(le32(data.length));
      local.add(le32(data.length));
      local.add(le16(n));
      local.add(le16(0));
      local.add(name);
      local.add(data);

      central.add(le32(0x02014B50));
      central.add(le16(20));
      central.add(le16(20));
      central.add(le16(0));
      central.add(le16(0));
      central.add(le16(0x21));
      central.add(le16(0x4E31));
      central.add(le32(crc));
      central.add(le32(data.length));
      central.add(le32(data.length));
      central.add(le16(n));
      central.add(le16(0));
      central.add(le16(0));
      central.add(le16(0));
      central.add(le16(0));
      central.add(le32(0));
      central.add(le32(offset));
      central.add(name);

      offset += 30 + n + data.length;
    }

    final out = BytesBuilder();
    final localBytes = local.takeBytes();
    out.add(localBytes);
    final cd = central.takeBytes();
    out.add(cd);
    out.add(le32(0x06054B50));
    out.add(le16(0));
    out.add(le16(0));
    out.add(le16(files.length));
    out.add(le16(files.length));
    out.add(le32(cd.length));
    out.add(le32(localBytes.length));
    out.add(le16(0));
    return Uint8List.fromList(out.toBytes());
  }

  static List<int> _crcTable() {
    final t = List<int>.filled(256, 0);
    for (var i = 0; i < 256; i++) {
      var c = i;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
      }
      t[i] = c & 0xFFFFFFFF;
    }
    return t;
  }

  static List<int> le16(int v) {
    final b = ByteData(2)..setUint16(0, v, Endian.little);
    return b.buffer.asUint8List();
  }

  static List<int> le32(int v) {
    final b = ByteData(4)..setUint32(0, v & 0xFFFFFFFF, Endian.little);
    return b.buffer.asUint8List();
  }
}