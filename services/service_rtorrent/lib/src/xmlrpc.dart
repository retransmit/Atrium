import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

/// A fault returned inside an XML-RPC `methodResponse`.
///
/// XML-RPC signals failure in the body, not the HTTP status, so a fault
/// arrives as a perfectly ordinary 200. rTorrent uses negative codes, e.g.
/// -501 for an unknown method and -500 for bad parameters.
class XmlRpcFault implements Exception {
  const XmlRpcFault(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'XML-RPC fault $code: $message';
}

/// Minimal XML-RPC codec, covering exactly what rTorrent speaks.
///
/// Deliberately not a general implementation: rTorrent only ever hands back
/// strings, integers, doubles, arrays and (for faults) one struct, so the
/// decoder handles those and nothing else.
abstract final class XmlRpc {
  /// Builds a `methodCall` document.
  ///
  /// [params] may contain String, int, double, bool, `Uint8List` (encoded as
  /// base64, which is how a `.torrent` is handed to `load.raw*`), and nested
  /// lists.
  static String buildCall(String method, List<Object?> params) {
    final XmlBuilder b = XmlBuilder();
    b.processing('xml', 'version="1.0"');
    b.element(
      'methodCall',
      nest: () {
        b.element('methodName', nest: method);
        b.element(
          'params',
          nest: () {
            for (final Object? p in params) {
              b.element('param', nest: () => _writeValue(b, p));
            }
          },
        );
      },
    );
    return b.buildDocument().toXmlString();
  }

  static void _writeValue(XmlBuilder b, Object? value) {
    b.element(
      'value',
      nest: () {
        switch (value) {
          case null:
            b.element('string', nest: '');
          case final String s:
            b.element('string', nest: s);
          case final bool v:
            b.element('boolean', nest: v ? '1' : '0');
          case final int i:
            // rTorrent's own values are 64-bit, and it accepts i8 on input.
            b.element('i8', nest: '$i');
          case final double d:
            b.element('double', nest: '$d');
          case final Uint8List bytes:
            b.element('base64', nest: base64Encode(bytes));
          case final List<Object?> list:
            b.element(
              'array',
              nest: () {
                b.element(
                  'data',
                  nest: () {
                    for (final Object? item in list) {
                      _writeValue(b, item);
                    }
                  },
                );
              },
            );
          case final Map<String, Object?> map:
            // Only `system.multicall` needs this, and it needs it exactly:
            // rTorrent faults with "could not find expected element struct"
            // if the {methodName, params} pairs arrive as anything else.
            b.element(
              'struct',
              nest: () {
                for (final MapEntry<String, Object?> e in map.entries) {
                  b.element(
                    'member',
                    nest: () {
                      b.element('name', nest: e.key);
                      _writeValue(b, e.value);
                    },
                  );
                }
              },
            );
          default:
            b.element('string', nest: '$value');
        }
      },
    );
  }

  /// Parses a `methodResponse` and returns its single value.
  ///
  /// Throws [XmlRpcFault] when the body carries a fault, and [FormatException]
  /// when it is not a methodResponse at all - which is what a reverse proxy's
  /// HTML error page looks like.
  static Object? parseResponse(String body) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(body);
    } on XmlException catch (e) {
      throw FormatException('not XML: ${e.message}');
    }
    final XmlElement? root = doc.getElement('methodResponse');
    if (root == null) {
      throw const FormatException('no methodResponse element');
    }

    final XmlElement? fault = root.getElement('fault');
    if (fault != null) {
      final Object? value = _readValue(fault.getElement('value'));
      if (value is Map<String, Object?>) {
        final Object? code = value['faultCode'];
        return throw XmlRpcFault(
          code is int ? code : -1,
          (value['faultString'] as String?) ?? 'unknown fault',
        );
      }
      throw const XmlRpcFault(-1, 'malformed fault');
    }

    final XmlElement? param = root.getElement('params')?.getElement('param');
    return _readValue(param?.getElement('value'));
  }

  static Object? _readValue(XmlElement? value) {
    if (value == null) return null;

    // A <value> with no type child is a string by the spec.
    final Iterable<XmlElement> typed = value.childElements;
    if (typed.isEmpty) return value.innerText;

    final XmlElement t = typed.first;
    switch (t.name.local) {
      case 'string':
        return t.innerText;
      case 'int':
      case 'i4':
      case 'i8':
        // rTorrent returns i8 for every integer, including booleans-as-0/1.
        return int.tryParse(t.innerText.trim()) ?? 0;
      case 'boolean':
        return t.innerText.trim() == '1';
      case 'double':
        return double.tryParse(t.innerText.trim()) ?? 0.0;
      case 'base64':
        return base64Decode(t.innerText.trim());
      case 'array':
        final XmlElement? data = t.getElement('data');
        if (data == null) return <Object?>[];
        return data.childElements
            .where((XmlElement e) => e.name.local == 'value')
            .map(_readValue)
            .toList();
      case 'struct':
        final Map<String, Object?> out = <String, Object?>{};
        for (final XmlElement m in t.childElements
            .where((XmlElement e) => e.name.local == 'member')) {
          final String? name = m.getElement('name')?.innerText;
          if (name != null) out[name] = _readValue(m.getElement('value'));
        }
        return out;
      default:
        return t.innerText;
    }
  }
}
