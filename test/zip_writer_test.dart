import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:jkr_fm_guide/services/zip_writer.dart';

void main() {
  test('store zip has valid central directory and EOCD', () {
    final bytes = ZipWriter.store({
      'a.txt': utf8.encode('hello'),
      'b/c.json': utf8.encode('{"x":1}'),
    });

    final n = bytes.length;
    // EOCD: 22 bytes at the tail -> sig 0x06054B50
    expect(bytes.sublist(n - 22, n - 18), [0x50, 0x4B, 0x05, 0x06]);
    expect(_le16(bytes, n - 14), 2); // entries on this disk
    expect(_le16(bytes, n - 12), 2); // total entries
    final cdSize = _le32(bytes, n - 10);
    final cdOffset = _le32(bytes, n - 6);
    expect(cdOffset + cdSize, n - 22);

    // central directory starts at cdOffset
    expect(bytes.sublist(cdOffset, cdOffset + 4), [0x50, 0x4B, 0x01, 0x02]);
    var pos = cdOffset;
    var localOffsets = <int>[];
    for (var i = 0; i < 2; i++) {
      final nameLen = _le16(bytes, pos + 28);
      final extraLen = _le16(bytes, pos + 30);
      final commentLen = _le16(bytes, pos + 32);
      final disk = _le16(bytes, pos + 34);
      final intAttr = _le16(bytes, pos + 36);
      final extAttr = _le32(bytes, pos + 38);
      final localOff = _le32(bytes, pos + 42);
      expect(extraLen, 0);
      expect(commentLen, 0);
      expect(disk, 0);
      expect(intAttr, 0);
      expect(extAttr, 0);
      localOffsets.add(localOff);
      final name = utf8.decode(bytes.sublist(pos + 46, pos + 46 + nameLen));
      expect(i == 0 ? 'a.txt' : 'b/c.json', name);
      // next record: 46 + nameLen + extra + comment
      pos += 46 + nameLen + extraLen + commentLen;
    }
    expect(pos, cdOffset + cdSize);

    for (final off in localOffsets) {
      expect(bytes.sublist(off, off + 4), [0x50, 0x4B, 0x03, 0x04]);
    }
  });

  test('store zip data round-trips', () {
    final data = utf8.encode('hello world');
    final bytes = ZipWriter.store({'x.txt': data});
    final n = bytes.length;
    final cdOffset = _le32(bytes, n - 6);
    final nameLen = _le16(bytes, cdOffset + 28);
    final csize = _le32(bytes, cdOffset + 20);
    final contentStart = 30 + nameLen;
    expect(utf8.decode(bytes.sublist(contentStart, contentStart + csize)),
        'hello world');
  });
}

int _le16(List<int> b, int o) => b[o] | (b[o + 1] << 8);
int _le32(List<int> b, int o) =>
    b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);