import 'package:flutter_test/flutter_test.dart';
import 'package:jkr_fm_guide/services/contractor_service.dart';

void main() {
  test('contractor login accepts email type usernames', () async {
    await ContractorService.load();
    expect(ContractorService.contractorLogin('HITACHI@gmail.com', '123456'), isNotNull);
    expect(ContractorService.contractorLogin('hitachi@gmail.com', '123456'), isNotNull);
    expect(ContractorService.contractorLogin('KAMARIZA FAIRUS@gmail.com', '123456'), isNull);
    expect(ContractorService.contractorLogin('HITACHI@gmail.com', 'wrong'), isNull);
    expect(ContractorService.contractorLogin('CARRIER@gmail.com', '123456'), isNotNull);
  });
}