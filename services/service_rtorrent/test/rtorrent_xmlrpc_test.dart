import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_rtorrent/service_rtorrent.dart';

String _response(String valueXml) =>
    '<?xml version="1.0"?><methodResponse><params><param>'
    '<value>$valueXml</value></param></params></methodResponse>';

void main() {
  group('buildCall', () {
    test('names the method and wraps each param', () {
      final String xml = XmlRpc.buildCall('d.name', <Object?>['abc']);
      expect(xml, contains('<methodName>d.name</methodName>'));
      expect(xml, contains('<param><value><string>abc</string></value>'));
    });

    test('encodes ints as i8, which is what rTorrent returns', () {
      expect(
        XmlRpc.buildCall('x', <Object?>[42]),
        contains('<i8>42</i8>'),
      );
    });

    test('encodes booleans, doubles and null', () {
      final String xml =
          XmlRpc.buildCall('x', <Object?>[true, false, 1.5, null]);
      expect(xml, contains('<boolean>1</boolean>'));
      expect(xml, contains('<boolean>0</boolean>'));
      expect(xml, contains('<double>1.5</double>'));
      expect(xml, contains('<string></string>'));
    });

    test('encodes bytes as base64, which is how a .torrent is sent', () {
      final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
      expect(
        XmlRpc.buildCall('load.raw_start', <Object?>['', bytes]),
        contains('<base64>${base64Encode(bytes)}</base64>'),
      );
    });

    test('encodes a list as an array', () {
      final String xml = XmlRpc.buildCall('x', <Object?>[
        <Object?>['a', 1],
      ]);
      expect(xml, contains('<array><data>'));
      expect(xml, contains('<string>a</string>'));
      expect(xml, contains('<i8>1</i8>'));
    });

    // system.multicall is the only caller that needs a struct, and rTorrent
    // faults with "could not find expected element struct" without one.
    test('encodes a map as a struct with named members', () {
      final String xml = XmlRpc.buildCall('system.multicall', <Object?>[
        <Object?>[
          <String, Object?>{
            'methodName': 'system.client_version',
            'params': <Object?>[],
          },
        ],
      ]);
      expect(xml, contains('<struct>'));
      expect(xml, contains('<name>methodName</name>'));
      expect(
        xml,
        contains('<string>system.client_version</string>'),
      );
      expect(xml, contains('<name>params</name>'));
    });
  });

  group('parseResponse', () {
    test('reads a string', () {
      expect(
        XmlRpc.parseResponse(_response('<string>0.16.17</string>')),
        '0.16.17',
      );
    });

    test('reads i8, i4 and int alike', () {
      expect(XmlRpc.parseResponse(_response('<i8>90</i8>')), 90);
      expect(XmlRpc.parseResponse(_response('<i4>7</i4>')), 7);
      expect(XmlRpc.parseResponse(_response('<int>3</int>')), 3);
    });

    test('a bare value with no type child is a string', () {
      expect(XmlRpc.parseResponse(_response('plain')), 'plain');
    });

    test('reads nested arrays, which is what a multicall returns', () {
      const String row = '<array><data>'
          '<value><string>name</string></value>'
          '<value><i8>5</i8></value>'
          '</data></array>';
      final Object? parsed = XmlRpc.parseResponse(
        _response('<array><data><value>$row</value></data></array>'),
      );
      expect(parsed, isA<List<Object?>>());
      final List<Object?> rows = parsed! as List<Object?>;
      expect(rows, hasLength(1));
      expect(rows.first, <Object?>['name', 5]);
    });

    test('reads a struct as a map', () {
      const String struct = '<struct>'
          '<member><name>a</name><value><i8>1</i8></value></member>'
          '<member><name>b</name><value><string>two</string></value></member>'
          '</struct>';
      expect(
        XmlRpc.parseResponse(_response(struct)),
        <String, Object?>{'a': 1, 'b': 'two'},
      );
    });

    // Faults arrive inside a perfectly ordinary HTTP 200.
    test('throws XmlRpcFault on a fault body', () {
      const String body = '<?xml version="1.0"?><methodResponse><fault>'
          '<value><struct>'
          '<member><name>faultCode</name><value><i8>-501</i8></value></member>'
          '<member><name>faultString</name>'
          '<value><string>Could not find view.</string></value></member>'
          '</struct></value></fault></methodResponse>';
      expect(
        () => XmlRpc.parseResponse(body),
        throwsA(
          isA<XmlRpcFault>()
              .having((XmlRpcFault f) => f.code, 'code', -501)
              .having(
                (XmlRpcFault f) => f.message,
                'message',
                'Could not find view.',
              ),
        ),
      );
    });

    // A proxy in front of rTorrent answers a misrouted POST with an HTML error
    // page, which must not be mistaken for a response.
    test('throws FormatException on HTML', () {
      expect(
        () => XmlRpc.parseResponse('<html><body>502 Bad Gateway</body></html>'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException on a non-XML body', () {
      expect(
        () => XmlRpc.parseResponse('not xml at all'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
