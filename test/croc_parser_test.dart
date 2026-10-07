import 'package:flutter_test/flutter_test.dart';
import 'package:gator/core/constants.dart';
import 'package:gator/models/gator_settings.dart';
import 'package:gator/services/croc_parser.dart';

void main() {
  test('pins bundled croc 11.5.4', () {
    expect(crocVersion, '11.5.4');
  });
