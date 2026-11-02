import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  test('catalog has 40 uniquely named garments', () {
    expect(products, hasLength(40));
    expect(products.map((item) => item.name).toSet(), hasLength(40));
  });
}
