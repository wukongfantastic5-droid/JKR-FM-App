import 'package:flutter_test/flutter_test.dart';
import 'package:jkr_fm_guide/data/floor_plan_data.dart';

void main() {
  group('textMatchesAsset EN/BM translation', () {
    const bmDesc =
        'MENERIMA ADUAN BAHAWA LAMPU TANDAS KETIGA DALAM TANDAS WANITA '
        'TIDAK MENYALA HAMPIR 2 MINGGU CORRECTIVE';
    const enDesc = 'WOMEN TOILET LIGHT NOT WORKING';

    test('LAMP instance matches BM description (lampu)', () {
      expect(textMatchesAsset('LAMP', bmDesc), isTrue);
    });

    test('LAMP instance matches EN description (light)', () {
      expect(textMatchesAsset('LAMP', enDesc), isTrue);
    });

    test('LUMINARIES (LIGHTING asset) is NOT hit by a toilet-lamp complaint', () {
      expect(textMatchesAsset('LUMINARIES', bmDesc), isFalse);
      expect(textMatchesAsset('LUMINARIES', enDesc), isFalse);
    });

    test('LIGHTING type is NOT hit by a toilet-lamp complaint', () {
      expect(textMatchesAsset('LIGHTING', bmDesc), isFalse);
    });

    test('TANDAS WANITA matches EN "women toilet"', () {
      expect(textMatchesAsset('TANDAS WANITA', enDesc), isTrue);
    });

    test('TANDAS LELAKI matches EN "men toilet"', () {
      expect(textMatchesAsset('TANDAS LELAKI', 'MEN TOILET LEAK'), isTrue);
    });

    test('TANDAS OKU matches EN "disabled toilet"', () {
      expect(textMatchesAsset('TANDAS OKU', 'DISABLED TOILET LEAK'), isTrue);
    });

    test('generic Toilet asset still matches BM ticket', () {
      expect(
        textMatchesAsset('Toilet',
            'G.15.009- TANDAS WANITA MENERIMA ADUAN LAMPU TANDAS TIDAK MENYALA CORRECTIVE'),
        isTrue,
      );
    });

    test('TOILET BOWL is NOT hit by a lamp-only complaint (stop word)', () {
      expect(textMatchesAsset('TOILET BOWL', bmDesc), isFalse);
    });

    test('EXHAUST FAN is NOT hit by a lamp complaint', () {
      expect(textMatchesAsset('EXHAUST FAN', bmDesc), isFalse);
    });

    test('WASH BASIN is NOT hit by a lamp complaint', () {
      expect(textMatchesAsset('WASH BASIN', bmDesc), isFalse);
    });

    test('HAND DRYER matches BM "pengering tangan" complaint', () {
      expect(
        textMatchesAsset('HAND DRYER',
            'MENERIMA ADUAN BAHAWA PENGERING TANGAN ROSAK TIDAK BERFUNGSI CORRECTIVE'),
        isTrue,
      );
      expect(textMatchesAsset('HAND DRYER', 'HAND DRYER NOT WORKING'), isTrue);
    });

    test('EXHAUST FAN matches BM "kipas" complaint', () {
      expect(
        textMatchesAsset('EXHAUST FAN',
            'MENERIMA ADUAN BAHAWA KIPAS TIDAK BERFUNGSI CORRECTIVE'),
        isTrue,
      );
      expect(
        textMatchesAsset('EXHAUST FAN', 'EXHAUST FAN TIDAK BERFUNGSI'),
        isTrue,
      );
    });

    test('SWITCH matches BM "suis" complaint', () {
      expect(textMatchesAsset('SWITCH', 'SUIS LAMPU ROSAK TIDAK BERFUNGSI'), isTrue);
    });

    test('WASH BASIN matches "sinki"/"sink" complaint', () {
      expect(textMatchesAsset('WASH BASIN', 'SINKI PECAH CORRECTIVE'), isTrue);
      expect(textMatchesAsset('WASH BASIN', 'SINK PECAH'), isTrue);
    });

    test('MIRROR matches "cermin" complaint', () {
      expect(textMatchesAsset('MIRROR', 'CERMIN PECAH CORRECTIVE'), isTrue);
    });

    test('URINAL matches "urinal pecah" complaint', () {
      expect(textMatchesAsset('URINAL', 'URINAL PECAH CORRECTIVE'), isTrue);
    });

    test('TOILET BOWL matches "bowl pecah" complaint', () {
      expect(textMatchesAsset('TOILET BOWL', 'TOILET BOWL PECAH'), isTrue);
      expect(textMatchesAsset('TOILET BOWL', 'BOWL PECAH CORRECTIVE'), isTrue);
    });

    test('WATER TANK matches "tangki" complaint', () {
      expect(textMatchesAsset('WATER TANK', 'TANGKI PECAH CORRECTIVE'), isTrue);
      expect(textMatchesAsset('WATER TANK', 'TANKI AIR ROSAK'), isTrue);
      expect(textMatchesAsset('WATER TANK', 'WATER TANK BOLEH LEAK'), isTrue);
    });

    test('WATER SUPPLY matches "water supply tidak jalan" complaint', () {
      expect(
        textMatchesAsset('WATER SUPPLY', 'WATER SUPPLY TIDAK JALAN CORRECTIVE'),
        isTrue,
      );
    });

    test('SOAP DISPENSER matches "sabun habis" complaint', () {
      expect(textMatchesAsset('SOAP DISPENSER', 'SABUN HABIS'), isTrue);
    });

    test('TILE matches "tile rosak" complaint', () {
      expect(textMatchesAsset('TILE', 'TILE ROSAK CORRECTIVE'), isTrue);
    });

    test('FIRE EXTINGUISHER matches "pemadam api rosak" complaint', () {
      expect(
        textMatchesAsset('FIRE EXTINGUISHER ABC 1', 'PEMADAM API ROSAK CORRECTIVE'),
        isTrue,
      );
    });

    test('BLOWER is NOT hit by a hand-dryer complaint (specificity)', () {
      expect(
        textMatchesAsset('BLOWER',
            'MENERIMA ADUAN BAHAWA PENGERING TANGAN ROSAK TIDAK BERFUNGSI CORRECTIVE'),
        isFalse,
      );
    });
  });

  group('resolveAssetSubject (single-asset pinning)', () {
    test('"suis lampu" resolves to switch, not lamp', () {
      expect(resolveAssetSubject('SUIS LAMPU DI TANDAS OKU NAK TERCABUT ARAS 31'), 'switch');
      expect(resolveAssetSubject('LIGHT SWITCH NOT WORKING'), 'switch');
    });

    test('"lampu tandas" alone resolves to lamp', () {
      expect(resolveAssetSubject('LAMPU TANDAS KETIGA TIDAK MENYALA'), 'lamp');
      expect(resolveAssetSubject('WOMEN TOILET LIGHT NOT WORKING'), 'lamp');
    });

    test('other asset words resolve to their own subject', () {
      expect(resolveAssetSubject('HAND DRYER ROSAK'), 'dryer');
      expect(resolveAssetSubject('PENGERING TANGAN ROSAK'), 'dryer');
      expect(resolveAssetSubject('EXHAUST FAN TIDAK BERFUNGSI'), 'fan');
      expect(resolveAssetSubject('WATER SUPPLY TIDAK JALAN'), 'supply');
      expect(resolveAssetSubject('TOILET BOWL PECAH'), 'bowl');
      expect(resolveAssetSubject('SABUN HABIS'), 'soap');
      expect(resolveAssetSubject('PEMADAM API ROSAK'), 'extinguisher');
      expect(resolveAssetSubject('CERMIN PECAH'), 'mirror');
      expect(resolveAssetSubject('KEDUDUKAN ANGLE BLIND SPOT MIRROR TIDAK TEPAT'),
          'blind spot mirror');
    });

    test('no specific asset named resolves to null', () {
      expect(resolveAssetSubject('MENERIMA ADUAN BAHAWA ADA MASALAH DI TANDAS'), isNull);
    });
  });
}
