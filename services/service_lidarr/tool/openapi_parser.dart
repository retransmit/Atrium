// ignore_for_file: avoid_print, avoid_dynamic_calls, avoid_redundant_argument_values, require_trailing_commas, prefer_const_declarations, prefer_single_quotes, prefer_final_locals
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final inputPath =
      args.isNotEmpty ? args[0] : '${Directory.current.path}/tool/openapi.json';
  final outputDir =
      args.length > 1 ? args[1] : '${Directory.current.path}/lib/src/generated';

  final file = File(inputPath);
  if (!file.existsSync()) {
    print('Error: Input OpenAPI JSON file not found at $inputPath');
    exit(1);
  }

  print('Parsing Lidarr OpenAPI specification from: $inputPath');
  final jsonString = file.readAsStringSync();
  final spec = jsonDecode(jsonString) as Map<String, dynamic>;

  final parser = LidarrOpenApiParser(spec, outputDir);
  parser.generateAll();
}

class LidarrOpenApiParser {
  final Map<String, dynamic> spec;
  final String outputDir;

  final Map<String, String> schemaClassNames = {};

  /// Enum class name -> the variant to fall back to when the server sends a
  /// value this spec has never heard of. See [_collectEnumFallbacks].
  final Map<String, String> enumFallbacks = {};

  /// Enum class name -> the raw JSON values it declares, for string enums.
  /// Used to recognise the same value under a different spelling.
  final Map<String, List<String>> enumValues = {};
  final Map<String, dynamic> schemas = {};
  final Map<String, List<Map<String, dynamic>>> tagEndpoints = {};
  final Set<String> _writtenFilePaths = {};
  final List<String> _warnings = [];

  int _modelsWritten = 0;
  int _modelsSkippedUnchanged = 0;
  int _apisWritten = 0;
  int _apisSkippedUnchanged = 0;

  LidarrOpenApiParser(this.spec, this.outputDir) {
    _initSchemas();
    _initEndpoints();
  }

  void _initSchemas() {
    final rawSchemas =
        (spec['components']?['schemas'] as Map?)?.cast<String, dynamic>() ?? {};
    schemas.addAll(rawSchemas);

    for (final fullKey in schemas.keys) {
      schemaClassNames[fullKey] = _resolveClassName(fullKey, rawSchemas);
    }
  }

  void _initEndpoints() {
    final paths = (spec['paths'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final pathEntry in paths.entries) {
      final path = pathEntry.key;
      final methods = (pathEntry.value as Map?)?.cast<String, dynamic>() ?? {};

      for (final methodEntry in methods.entries) {
        final verb = methodEntry.key.toLowerCase();
        if (!['get', 'post', 'put', 'delete', 'patch', 'head'].contains(verb)) {
          continue;
        }

        final op = (methodEntry.value as Map?)?.cast<String, dynamic>() ?? {};
        final tags =
            (op['tags'] as List<dynamic>?)?.cast<String>() ?? ['Default'];
        final tag = tags.first;

        tagEndpoints.putIfAbsent(tag, () => []).add({
          'path': path,
          'verb': verb,
          'operation': op,
        });
      }
    }
  }

  String _sanitizeIdentifier(String name) {
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
  }

  String _toPascalCase(String text) {
    final clean = text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ');
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.map((w) => w[0].toUpperCase() + w.substring(1)).join('');
  }

  String _toCamelCase(String text) {
    final pascal = _toPascalCase(text);
    if (pascal.isEmpty) return 'item';
    var camel = pascal[0].toLowerCase() + pascal.substring(1);
    if (RegExp(r'^[0-9]').hasMatch(camel)) {
      camel = 'val$camel';
    }
    const keywords = {
      'abstract',
      'as',
      'assert',
      'async',
      'await',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'covariant',
      'default',
      'deferred',
      'do',
      'dynamic',
      'else',
      'enum',
      'export',
      'extends',
      'extension',
      'external',
      'factory',
      'false',
      'finally',
      'for',
      'function',
      'get',
      'hide',
      'if',
      'implements',
      'import',
      'in',
      'interface',
      'is',
      'late',
      'library',
      'mixin',
      'new',
      'null',
      'on',
      'operator',
      'part',
      'required',
      'rethrow',
      'return',
      'set',
      'show',
      'static',
      'super',
      'switch',
      'sync',
      'this',
      'throw',
      'true',
      'try',
      'typedef',
      'var',
      'void',
      'while',
      'with',
      'yield'
    };
    return keywords.contains(camel) ? '${camel}Val' : camel;
  }

  String _toSnakeCase(String name) {
    return name
        .replaceAllMapped(
            RegExp(r'([A-Z])'), (m) => '_${m.group(1)!.toLowerCase()}')
        .replaceAll(RegExp(r'^_'), '')
        .replaceAll(RegExp(r'_+'), '_');
  }

  String _resolveClassName(String fullKey, Map<String, dynamic> rawSchemas) {
    final genericMatch =
        RegExp(r'`\d+\[\[(?:[^\.,]+\.)*([^\.,]+),').firstMatch(fullKey);
    final genericSuffix =
        genericMatch != null ? _sanitizeIdentifier(genericMatch.group(1)!) : '';

    final cleanBase = fullKey.replaceAll(RegExp(r'`\d+\[\[.*'), '');
    final parts = cleanBase.split('.');
    final short = parts.last;

    final collisions = rawSchemas.keys
        .where((k) =>
            k.replaceAll(RegExp(r'`\d+\[\[.*'), '').split('.').last == short)
        .toList();

    String baseName;
    if (collisions.length == 1) {
      baseName = _sanitizeIdentifier(short);
    } else {
      final meaningful = parts
          .where((p) => !['Lidarr', 'Api', 'External', 'Models', 'Core', 'V1']
              .contains(p))
          .toList();
      final effective = meaningful.isEmpty ? parts : meaningful;
      baseName = effective.map(_sanitizeIdentifier).join('');
    }

    return '$baseName$genericSuffix';
  }

  void generateAll() {
    _createDirectories();
    _generateResponseFiles();
    _generateModelFiles();
    _generateApiFiles();
    _generateExportFile();
    _cleanOrphanFiles();

    print(
        'Generated Lidarr OpenAPI Dart models and API clients in: $outputDir');
    print(
        '  - Models: $_modelsWritten written, $_modelsSkippedUnchanged up-to-date');
    print('  - APIs: $_apisWritten written, $_apisSkippedUnchanged up-to-date');
    if (_warnings.isNotEmpty) {
      print('  - Warnings (${_warnings.length}):');
      for (final w in _warnings.take(10)) {
        print('    * $w');
      }
      if (_warnings.length > 10) {
        print('    * ... and ${_warnings.length - 10} more');
      }
    }
  }

  void _createDirectories() {
    Directory('$outputDir/models').createSync(recursive: true);
    Directory('$outputDir/responses').createSync(recursive: true);
    Directory('$outputDir/api').createSync(recursive: true);
  }

  String _normalizePath(String path) {
    return File(path).absolute.path.replaceAll(r'\', '/').toLowerCase();
  }

  void _writeFileIfChanged(String path, String content,
      {bool isModel = false, bool isApi = false}) {
    final normalizedPath = _normalizePath(path);
    _writtenFilePaths.add(normalizedPath);
    final file = File(path);
    if (file.existsSync()) {
      final existing = file.readAsStringSync();
      if (existing == content) {
        if (isModel) _modelsSkippedUnchanged++;
        if (isApi) _apisSkippedUnchanged++;
        return;
      }
    }
    file.writeAsStringSync(content);
    if (isModel) _modelsWritten++;
    if (isApi) _apisWritten++;
  }

  void _cleanOrphanFiles() {
    final dir = Directory(outputDir);
    if (!dir.existsSync()) return;

    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        final path = _normalizePath(entity.path);
        if (!_writtenFilePaths.contains(path) &&
            !path.endsWith('.freezed.dart') &&
            !path.endsWith('.g.dart')) {
          try {
            entity.deleteSync();
          } catch (_) {}
        }
      }
    }
  }

  void _generateResponseFiles() {
    final apiResponseContent = '''
import 'lidarr_error.dart';

/// Standardized API response container for Lidarr API calls.
class ApiResponse<T> {
  final T? data;
  final LidarrError? error;
  final int? statusCode;
  final bool isSuccess;

  const ApiResponse.success(this.data, {this.statusCode})
      : error = null,
        isSuccess = true;

  const ApiResponse.error(this.error, {this.statusCode})
      : data = null,
        isSuccess = false;
}
''';
    _writeFileIfChanged(
        '$outputDir/responses/api_response.dart', apiResponseContent);

    final errorContent = '''
import 'package:dio/dio.dart';

/// Error model returned by Lidarr API endpoints.
class LidarrError {
  final String? message;
  final String? description;
  final List<String> errors;

  const LidarrError({
    this.message,
    this.description,
    this.errors = const [],
  });

  factory LidarrError.fromJson(dynamic data) {
    if (data == null) {
      return const LidarrError();
    }

    if (data is String) {
      return LidarrError(message: data);
    }

    if (data is List) {
      final List<String> errList = [];
      for (final item in data) {
        if (item is Map) {
          final String? err = item['errorMessage']?.toString() ??
              item['message']?.toString() ??
              item['propertyName']?.toString();
          if (err != null && err.isNotEmpty) {
            errList.add(err);
          }
        } else if (item != null) {
          errList.add(item.toString());
        }
      }
      return LidarrError(
        message: errList.isNotEmpty ? errList.first : 'Validation error',
        errors: errList,
      );
    }

    if (data is Map<String, dynamic> || data is Map) {
      final map = data as Map;
      final List<String> errList = [];

      final rawErrors = map['errors'];
      if (rawErrors is Map) {
        // ASP.NET ValidationProblemDetails: {"errors": {"Field": ["Error 1", "Error 2"]}}
        for (final entry in rawErrors.entries) {
          final field = entry.key?.toString() ?? '';
          final val = entry.value;
          if (val is List) {
            for (final msg in val) {
              errList.add(field.isNotEmpty ? '\$field: \$msg' : msg.toString());
            }
          } else if (val != null) {
            errList.add(field.isNotEmpty ? '\$field: \$val' : val.toString());
          }
        }
      } else if (rawErrors is List) {
        for (final item in rawErrors) {
          if (item is Map) {
            final String? err = item['errorMessage']?.toString() ??
                item['message']?.toString();
            if (err != null && err.isNotEmpty) {
              errList.add(err);
            }
          } else if (item != null) {
            errList.add(item.toString());
          }
        }
      } else if (rawErrors is String && rawErrors.isNotEmpty) {
        errList.add(rawErrors);
      }

      final String? msg = (errList.isNotEmpty ? errList.join('\\n') : null) ??
          map['message']?.toString() ??
          map['title']?.toString() ??
          map['error']?.toString();

      final String? desc = map['description']?.toString() ??
          map['detail']?.toString();

      return LidarrError(
        message: msg,
        description: desc,
        errors: errList,
      );
    }

    return LidarrError(message: data.toString());
  }

  factory LidarrError.fromDio(DioException exception) {
    if (exception.response?.data != null) {
      final parsed = LidarrError.fromJson(exception.response!.data);
      if (parsed.message != null && parsed.message!.isNotEmpty) {
        return parsed;
      }
    }
    return LidarrError(
      message: exception.message ??
          'HTTP Error \${exception.response?.statusCode}',
      description: exception.type.toString(),
    );
  }
}
''';
    _writeFileIfChanged('$outputDir/responses/lidarr_error.dart', errorContent);

    final exceptionContent = '''
import 'lidarr_error.dart';

/// Custom exception thrown on Lidarr API failure.
class LidarrException implements Exception {
  final String message;
  final int? statusCode;
  final LidarrError? error;

  const LidarrException(
    this.message, {
    this.statusCode,
    this.error,
  });

  @override
  String toString() =>
      'LidarrException(statusCode: \$statusCode, message: \$message, error: \$error)';
}
''';
    _writeFileIfChanged(
        '$outputDir/responses/lidarr_exception.dart', exceptionContent);

    const normalizerContent = r'''
/// Accepts either spelling Lidarr uses for an enum value.
///
/// Older builds serialise these in short form (`torrent`), while newer
/// branches send the full C# member name (`TorrentDownloadProtocol`). The
/// difference is systematic rather than per-plugin, so rather than teach every
/// call site about it, the raw value is reconciled here before decoding.
///
/// Returns the declared spelling when it can recognise the value, and the
/// original otherwise, leaving the generated `unknownEnumValue` to catch
/// anything genuinely new such as a protocol a plugin has introduced.
Object? normalizeLidarrEnum(
  Object? raw,
  String enumName,
  List<String> allowed,
) {
  if (raw is! String) return raw;
  if (allowed.contains(raw)) return raw;

  var candidate = raw;
  final lowerName = enumName.toLowerCase();
  if (candidate.length > enumName.length &&
      candidate.toLowerCase().endsWith(lowerName)) {
    candidate = candidate.substring(0, candidate.length - enumName.length);
  }

  for (final value in allowed) {
    if (value.toLowerCase() == candidate.toLowerCase()) return value;
  }
  return raw;
}
''';
    _writeFileIfChanged(
        '$outputDir/responses/enum_normalizer.dart', normalizerContent);
  }

  /// The identifiers [_buildEnumCode] will emit, in order, for one enum.
  ///
  /// Kept deliberately in step with that method: a fallback has to name a
  /// variant that actually exists, collision suffix and all.
  List<String> _enumIdentifiers(List<dynamic> enumList) {
    final used = <String>{};
    final out = <String>[];
    for (final item in enumList) {
      var identifier =
          item is int ? 'val$item' : _toCamelCase(item.toString());
      while (used.contains(identifier)) {
        identifier = '${identifier}Alt';
      }
      used.add(identifier);
      out.add(identifier);
    }
    return out;
  }

  /// Picks a landing spot for enum values this spec does not list.
  ///
  /// Lidarr's plugin builds introduce protocols and statuses no released spec
  /// mentions, and json_serializable throws on a value it cannot map, which
  /// loses the entire response rather than one field. Falling back keeps the
  /// rest of the payload usable. An `unknown` variant is the natural home
  /// where the enum has one; otherwise the first value is taken, since the
  /// alternative is an exception.
  void _collectEnumFallbacks() {
    for (final entry in schemas.entries) {
      final schema = (entry.value as Map).cast<String, dynamic>();
      if (!schema.containsKey('enum')) continue;
      final className = schemaClassNames[entry.key];
      if (className == null) continue;
      final enumList = schema['enum'] as List<dynamic>;
      if (enumList.isEmpty) continue;

      final identifiers = _enumIdentifiers(enumList);
      var chosen = identifiers.first;
      for (var i = 0; i < enumList.length; i++) {
        final item = enumList[i];
        if (item is! int && item.toString().toLowerCase() == 'unknown') {
          chosen = identifiers[i];
          break;
        }
      }
      enumFallbacks[className] = chosen;
      if (enumList.every((e) => e is! int)) {
        enumValues[className] = enumList.map((e) => e.toString()).toList();
      }
    }
  }

  void _generateModelFiles() {
    _collectEnumFallbacks();
    for (final entry in schemas.entries) {
      final fullKey = entry.key;
      final schema = (entry.value as Map).cast<String, dynamic>();
      final className = schemaClassNames[fullKey]!;
      final fileName = _toSnakeCase(className);

      final code = _buildModelCode(fullKey, className, schema);
      _writeFileIfChanged('$outputDir/models/$fileName.dart', code,
          isModel: true);
    }
  }

  Map<String, dynamic> _flattenProperties(
      Map<String, dynamic> schema, Set<String> requiredSet) {
    final properties = <String, dynamic>{};

    if (schema.containsKey('properties') && schema['properties'] is Map) {
      properties.addAll((schema['properties'] as Map).cast<String, dynamic>());
    }

    if (schema.containsKey('required') && schema['required'] is List) {
      final reqList = schema['required'] as List<dynamic>;
      requiredSet.addAll(reqList.map((e) => e.toString()));
    }

    if (schema.containsKey('allOf') && schema['allOf'] is List) {
      final allOfList = schema['allOf'] as List<dynamic>;
      for (final sub in allOfList) {
        if (sub is Map) {
          final subMap = sub.cast<String, dynamic>();
          if (subMap.containsKey(r'$ref')) {
            final refKey = (subMap[r'$ref'] as String)
                .replaceFirst('#/components/schemas/', '');
            final refSchema = schemas[refKey];
            if (refSchema is Map) {
              properties.addAll(_flattenProperties(
                  refSchema.cast<String, dynamic>(), requiredSet));
            }
          } else {
            properties.addAll(_flattenProperties(subMap, requiredSet));
          }
        }
      }
    }

    return properties;
  }

  String _buildModelCode(
      String fullKey, String className, Map<String, dynamic> schema) {
    final isEnum = schema.containsKey('enum');
    if (isEnum) {
      return _buildEnumCode(className, schema);
    }

    final requiredSet = <String>{};
    final properties = _flattenProperties(schema, requiredSet);
    final title = schema['title'] as String?;
    final description = schema['description'] as String?;

    final imports = <String>{};
    final fields = <_ModelField>[];
    final usedFieldNames = <String>{};
    final enumReadersNeeded = <String>{};

    for (final propEntry in properties.entries) {
      final propKey = propEntry.key;
      final propSchema = propEntry.value is Map
          ? (propEntry.value as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      var fieldName = _toCamelCase(propKey);
      while (usedFieldNames.contains(fieldName)) {
        fieldName = '${fieldName}Alt';
      }
      usedFieldNames.add(fieldName);

      final fieldTypeInfo = _parseType(propSchema, imports);
      final propDesc = propSchema['description'] as String?;
      final format = propSchema['format'] as String?;
      final isDeprecated = propSchema['deprecated'] == true;
      final readOnly = propSchema['readOnly'] == true;
      final defaultVal = propSchema['default'];

      final isExplicitlyNullable = propSchema['nullable'] == true;
      final isRequired = requiredSet.contains(propKey);
      final isNullable = isExplicitlyNullable || !isRequired;

      fields.add(_ModelField(
        jsonKey: propKey,
        fieldName: fieldName,
        dartType: fieldTypeInfo.dartType,
        isNullable: isNullable,
        isList: fieldTypeInfo.isList,
        isCustomClass: fieldTypeInfo.isCustomClass,
        customClassName: fieldTypeInfo.customClassName,
        description: propDesc,
        format: format,
        readOnly: readOnly,
        defaultValue: defaultVal,
        isDeprecated: isDeprecated,
      ));
    }

    final fileName = _toSnakeCase(className);
    final buffer = StringBuffer();
    buffer.writeln("// ignore_for_file: unused_import");
    buffer.writeln(
        "import 'package:freezed_annotation/freezed_annotation.dart';");
    buffer.writeln("import '../responses/enum_normalizer.dart';");
    for (final imp in imports) {
      if (imp != className) {
        final impFileName = _toSnakeCase(imp);
        buffer.writeln("import '$impFileName.dart';");
      }
    }
    buffer.writeln();
    buffer.writeln("part '$fileName.freezed.dart';");
    buffer.writeln("part '$fileName.g.dart';");
    buffer.writeln();

    final classDoc = description ?? title;
    if (classDoc != null && classDoc.isNotEmpty) {
      for (final line in classDoc.split('\n')) {
        buffer.writeln('/// ${line.trim()}');
      }
      buffer.writeln('///');
    }
    buffer.writeln('/// Original C# Schema: `$fullKey`');
    if (schema['deprecated'] == true) {
      buffer.writeln("@Deprecated('Marked deprecated in OpenAPI spec')");
    }
    buffer.writeln('@freezed');
    buffer.writeln('abstract class $className with _\$$className {');
    if (fields.isEmpty) {
      buffer.writeln('  const factory $className() = _$className;');
    } else {
      buffer.writeln('  const factory $className({');
      for (final f in fields) {
        final docParts = <String>[];
        if (f.description != null && f.description!.isNotEmpty) {
          docParts.add(f.description!.trim());
        }
        final metaTags = <String>[];
        if (f.format != null) metaTags.add('format: ${f.format}');
        if (f.readOnly) metaTags.add('readOnly: true');
        if (f.defaultValue != null) metaTags.add('default: ${f.defaultValue}');
        if (metaTags.isNotEmpty) {
          docParts.add('(${metaTags.join(', ')})');
        }

        if (docParts.isNotEmpty) {
          for (final line in docParts.join(' ').split('\n')) {
            buffer.writeln('    /// ${line.trim()}');
          }
        }
        if (f.isDeprecated) {
          buffer
              .writeln("    @Deprecated('Marked deprecated in OpenAPI spec')");
        }
        final typeStr = f.isNullable
            ? (f.dartType.endsWith('?') ? f.dartType : '${f.dartType}?')
            : f.dartType;
        final prefix = f.isNullable ? '' : 'required ';
        // Give an enum field somewhere to land when the server sends a value
        // this spec does not list, rather than throwing and losing the whole
        // response. Covers `List<Enum>` too, where it applies per element.
        final baseType = typeStr
            .replaceAll('?', '')
            .replaceFirst('List<', '')
            .replaceFirst('>', '');
        final fallback = enumFallbacks[baseType];
        final args = <String>["name: '${f.jsonKey}'"];
        if (fallback != null) {
          // Lidarr's newer branches serialise an enum by its C# member name
          // (`TorrentDownloadProtocol`) where older ones sent the short form
          // (`torrent`), so the raw value is normalised before decoding and
          // anything still unrecognised lands on the fallback.
          if (enumValues.containsKey(baseType)) {
            enumReadersNeeded.add(baseType);
            args.add('readValue: _read$baseType');
          }
          args.add('unknownEnumValue: $baseType.$fallback');
        }
        buffer.writeln(
            "    @JsonKey(${args.join(', ')}) $prefix$typeStr ${f.fieldName},");
      }
      buffer.writeln('  }) = _$className;');
    }
    buffer.writeln();
    buffer
        .writeln('  factory $className.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$${className}FromJson(json);');
    buffer.writeln('}');

    for (final enumName in enumReadersNeeded) {
      final allowed =
          enumValues[enumName]!.map((v) => "'${v.replaceAll("'", r"'")}'").join(', ');
      buffer.writeln();
      buffer.writeln('/// Reads `\$key` allowing for either spelling of a');
      buffer.writeln('/// [$enumName] value. See `normalizeLidarrEnum`.');
      buffer.writeln(
          'Object? _read$enumName(Map<dynamic, dynamic> json, String key) =>');
      buffer.writeln('    normalizeLidarrEnum(');
      buffer.writeln("      json[key],");
      buffer.writeln("      '$enumName',");
      buffer.writeln('      const <String>[$allowed],');
      buffer.writeln('    );');
    }

    return buffer.toString();
  }

  String _buildEnumCode(String className, Map<String, dynamic> schema) {
    final buffer = StringBuffer();
    final enumList = schema['enum'] as List<dynamic>;
    final fileName = _toSnakeCase(className);

    buffer.writeln("// ignore_for_file: unused_import");
    buffer.writeln(
        "import 'package:freezed_annotation/freezed_annotation.dart';");
    buffer.writeln();
    buffer.writeln("part '$fileName.g.dart';");
    buffer.writeln();
    buffer.writeln('/// Enum `$className`');
    buffer.writeln('@JsonEnum(alwaysCreate: true)');
    buffer.writeln('enum $className {');

    final isIntEnum = enumList.isNotEmpty && enumList.first is int;
    final usedIdentifiers = <String>{};

    for (final item in enumList) {
      if (item is int) {
        var identifier = 'val$item';
        while (usedIdentifiers.contains(identifier)) {
          identifier = '${identifier}Alt';
        }
        usedIdentifiers.add(identifier);
        buffer.writeln("  @JsonValue($item)");
        buffer.writeln('  $identifier($item),');
      } else {
        final strVal = item.toString();
        var identifier = _toCamelCase(strVal);
        while (usedIdentifiers.contains(identifier)) {
          identifier = '${identifier}Alt';
        }
        usedIdentifiers.add(identifier);
        final escaped = strVal.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
        buffer.writeln("  @JsonValue('$escaped')");
        buffer.writeln("  $identifier('$escaped'),");
      }
    }
    buffer.writeln(';');
    buffer.writeln();
    final valType = isIntEnum ? 'int' : 'String';
    buffer.writeln('  final $valType value;');
    buffer.writeln('  const $className(this.value);');
    buffer.writeln('}');
    return buffer.toString();
  }

  _TypeInfo _parseType(Map<String, dynamic> schema, Set<String> imports) {
    if (schema.containsKey('\$ref')) {
      final ref = schema['\$ref'] as String;
      final key = ref.replaceFirst('#/components/schemas/', '');
      final cls = schemaClassNames[key] ?? 'dynamic';
      if (cls != 'dynamic') imports.add(cls);
      return _TypeInfo(
          dartType: cls,
          isNullable: true,
          isCustomClass: true,
          customClassName: cls);
    }

    final type = schema['type'] as String?;
    if (type == 'array') {
      final items = (schema['items'] as Map<String, dynamic>?) ?? {};
      final itemType = _parseType(items, imports);
      final listDartType = 'List<${itemType.dartType}>';
      return _TypeInfo(
        dartType: listDartType,
        isNullable: true,
        isList: true,
        customClassName:
            itemType.isCustomClass ? itemType.customClassName : null,
      );
    }

    if (type == 'object') {
      if (schema.containsKey('additionalProperties')) {
        final addProps = schema['additionalProperties'];
        if (addProps is Map<String, dynamic> && addProps.isNotEmpty) {
          final valType = _parseType(addProps, imports);
          final isValNullable = addProps['nullable'] == true;
          final valueTypeStr =
              isValNullable ? '${valType.dartType}?' : valType.dartType;
          return _TypeInfo(
            dartType: 'Map<String, $valueTypeStr>',
            isNullable: true,
          );
        }
        return _TypeInfo(
          dartType: 'Map<String, dynamic>',
          isNullable: true,
        );
      }
      return _TypeInfo(dartType: 'Map<String, dynamic>', isNullable: true);
    }

    if (type == 'integer') {
      return _TypeInfo(dartType: 'int', isNullable: true);
    }
    if (type == 'number') {
      return _TypeInfo(dartType: 'double', isNullable: true);
    }
    if (type == 'boolean') {
      return _TypeInfo(dartType: 'bool', isNullable: true);
    }
    if (type == 'string') {
      return _TypeInfo(dartType: 'String', isNullable: true);
    }

    if (schema.containsKey('allOf')) {
      final allOf = schema['allOf'] as List<dynamic>;
      if (allOf.isNotEmpty &&
          allOf.first is Map<String, dynamic> &&
          (allOf.first as Map<String, dynamic>).containsKey('\$ref')) {
        return _parseType(allOf.first as Map<String, dynamic>, imports);
      }
    }

    if (schema.containsKey('oneOf') || schema.containsKey('anyOf')) {
      _warnings.add('Encountered oneOf/anyOf union: mapping to dynamic');
      return _TypeInfo(dartType: 'dynamic', isNullable: true);
    }

    return _TypeInfo(dartType: 'dynamic', isNullable: true);
  }

  void _generateApiFiles() {
    for (final entry in tagEndpoints.entries) {
      final tag = entry.key;
      final endpoints = entry.value;
      final className = 'Raw${_toPascalCase(tag)}Api';
      final fileName = _toSnakeCase(className);

      final code = _buildApiCode(tag, className, endpoints);
      _writeFileIfChanged('$outputDir/api/$fileName.dart', code, isApi: true);
    }
  }

  String _buildApiCode(
      String tag, String className, List<Map<String, dynamic>> endpoints) {
    final buffer = StringBuffer();
    final imports = <String>{
      "import 'dart:convert';",
      "import 'package:dio/dio.dart';",
      "import '../responses/api_response.dart';",
      "import '../responses/lidarr_error.dart';",
      "import '../responses/lidarr_exception.dart';",
    };

    final modelImports = <String>{};

    for (final ep in endpoints) {
      final op = ep['operation'] as Map<String, dynamic>;
      final respSchema = _getSuccessResponseSchema(op);
      if (respSchema != null) {
        _extractModelImports(respSchema, modelImports);
      }
      final bodySchema = _getRequestBodySchema(op);
      if (bodySchema != null) {
        _extractModelImports(bodySchema, modelImports);
      }
      final params =
          (op['parameters'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
              [];
      for (final p in params) {
        final pSchema = p['schema'] as Map<String, dynamic>?;
        if (pSchema != null) {
          _extractModelImports(pSchema, modelImports);
        }
      }
    }

    buffer.writeln("// ignore_for_file: unused_import");
    for (final imp in imports) {
      buffer.writeln(imp);
    }

    for (final mImp in modelImports) {
      final fileName = _toSnakeCase(mImp);
      buffer.writeln("import '../models/$fileName.dart';");
    }
    buffer.writeln();

    buffer.writeln('/// Raw API client for `$tag` endpoints.');
    buffer.writeln('class $className {');
    buffer.writeln('  final Dio _dio;');
    buffer.writeln();
    buffer.writeln('  $className(this._dio);');
    buffer.writeln();

    final usedMethodNames = <String>{};
    for (final ep in endpoints) {
      final path = ep['path'] as String;
      final verb = ep['verb'] as String;
      final op = ep['operation'] as Map<String, dynamic>;

      final summary = op['summary'] as String?;
      final description = op['description'] as String?;
      final operationId = op['operationId'] as String?;

      var methodName = _buildMethodName(verb, path, operationId);
      if (usedMethodNames.contains(methodName)) {
        var count = 2;
        while (usedMethodNames.contains('$methodName$count')) {
          count++;
        }
        methodName = '$methodName$count';
      }
      usedMethodNames.add(methodName);

      final doc = summary ?? description;
      if (doc != null && doc.isNotEmpty) {
        for (final line in doc.split('\n')) {
          buffer.writeln('  /// ${line.trim()}');
        }
      }
      buffer.writeln('  /// HTTP $verb $path');
      if (op['deprecated'] == true) {
        buffer.writeln("  @Deprecated('Marked deprecated in OpenAPI spec')");
      }

      final respSchema = verb == 'head' ? null : _getSuccessResponseSchema(op);
      final returnTypeInfo = _getReturnTypeInfo(respSchema);
      final returnType = returnTypeInfo.type;

      buffer.writeln('  Future<ApiResponse<$returnType>> $methodName(');

      final params =
          (op['parameters'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
              [];
      final pathParams = params.where((p) => p['in'] == 'path').toList();
      final queryParams = params.where((p) => p['in'] == 'query').toList();
      final bodySchema = _getRequestBodySchema(op);

      final methodParams = <String>[];
      for (final p in pathParams) {
        final rawName = p['name'] as String;
        final pName = _toCamelCase(rawName);
        final pSchema = p['schema'] as Map<String, dynamic>? ?? {};
        final pType = _parseParameterType(pSchema);
        methodParams.add('required $pType $pName');
      }
      for (final q in queryParams) {
        final qRaw = q['name'] as String;
        final qName = _toCamelCase(qRaw);
        final qSchema = q['schema'] as Map<String, dynamic>? ?? {};
        final isRequired = q['required'] == true;
        final qType = _parseParameterType(qSchema);
        if (isRequired) {
          methodParams.add('required $qType $qName');
        } else {
          methodParams.add('$qType? $qName');
        }
      }
      if (bodySchema != null) {
        final bodyTypeInfo = _getReturnTypeInfo(bodySchema);
        final isBodyRequired = op['requestBody']?['required'] == true;
        final bodyType = bodyTypeInfo.type;
        if (isBodyRequired) {
          methodParams.add('required $bodyType body');
        } else {
          methodParams.add('$bodyType? body');
        }
      }

      if (methodParams.isNotEmpty) {
        buffer.writeln('    {${methodParams.join(', ')}}');
      }
      buffer.writeln('  ) async {');

      var interpolatedPath = path;
      for (final p in pathParams) {
        final rawName = p['name'] as String;
        final pName = _toCamelCase(rawName);
        interpolatedPath = interpolatedPath.replaceAll(
            '{$rawName}', '\${Uri.encodeComponent(\'\$$pName\')}');
      }

      buffer.writeln('    try {');
      buffer.writeln(
          '      final Response<dynamic> resp = await _dio.$verb<dynamic>(');
      buffer.writeln("        '$interpolatedPath',");
      if (queryParams.isNotEmpty) {
        buffer.writeln('        queryParameters: <String, dynamic>{');
        for (final q in queryParams) {
          final qRaw = q['name'] as String;
          final qName = _toCamelCase(qRaw);
          final qSchema = q['schema'] as Map<String, dynamic>? ?? {};
          final isEnum = _isEnumSchema(qSchema);
          final isArray = qSchema['type'] == 'array';
          final arrayItems = isArray
              ? (qSchema['items'] as Map<String, dynamic>? ?? {})
              : null;
          final isEnumArray = arrayItems != null && _isEnumSchema(arrayItems);

          if (isEnum) {
            buffer.writeln(
                "          if ($qName != null) '$qRaw': $qName.value,");
          } else if (isEnumArray) {
            buffer.writeln(
                "          if ($qName != null) '$qRaw': $qName.map((e) => e.value).toList(),");
          } else {
            buffer.writeln("          if ($qName != null) '$qRaw': $qName,");
          }
        }
        buffer.writeln('        },');
      }
      if (bodySchema != null) {
        final bodyTypeInfo = _getReturnTypeInfo(bodySchema);
        if (bodyTypeInfo.isCustomClass && !bodyTypeInfo.isList) {
          buffer.writeln('        data: body?.toJson(),');
        } else if (bodyTypeInfo.isCustomClass && bodyTypeInfo.isList) {
          buffer
              .writeln('        data: body?.map((e) => e.toJson()).toList(),');
        } else if (_isEnumSchema(bodySchema)) {
          buffer.writeln('        data: body?.value,');
        } else {
          buffer.writeln('        data: body,');
        }
      }
      buffer.writeln('      );');

      buffer.writeln('      ${_buildDeserializationCode(returnTypeInfo)}');
      buffer.writeln(
          '      return ApiResponse.success(data, statusCode: resp.statusCode);');
      buffer.writeln('    } on DioException catch (e) {');
      buffer.writeln(
          '      return ApiResponse.error(LidarrError.fromDio(e), statusCode: e.response?.statusCode);');
      buffer.writeln('    }');
      buffer.writeln('  }');
      buffer.writeln();
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  bool _isEnumSchema(Map<String, dynamic> schema) {
    if (schema.containsKey('enum')) return true;
    if (schema.containsKey(r'$ref')) {
      final ref = schema[r'$ref'] as String;
      final key = ref.replaceFirst('#/components/schemas/', '');
      final target = schemas[key];
      if (target is Map && target.containsKey('enum')) return true;
    }
    return false;
  }

  String _parseParameterType(Map<String, dynamic> schema) {
    if (schema.containsKey('\$ref')) {
      final ref = schema['\$ref'] as String;
      final key = ref.replaceFirst('#/components/schemas/', '');
      return schemaClassNames[key] ?? 'dynamic';
    }
    final type = schema['type'] as String?;
    if (type == 'integer') return 'int';
    if (type == 'number') return 'double';
    if (type == 'boolean') return 'bool';
    if (type == 'string') return 'String';
    if (type == 'array') {
      final items = schema['items'] as Map<String, dynamic>? ?? {};
      final itemType = _parseParameterType(items);
      return 'List<$itemType>';
    }
    return 'dynamic';
  }

  _ReturnTypeInfo _getReturnTypeInfo(Map<String, dynamic>? schema) {
    if (schema == null) {
      return _ReturnTypeInfo(type: 'void', isList: false, isCustomClass: false);
    }
    if (schema.containsKey('\$ref')) {
      final ref = schema['\$ref'] as String;
      final key = ref.replaceFirst('#/components/schemas/', '');
      final cls = schemaClassNames[key] ?? 'dynamic';
      return _ReturnTypeInfo(
          type: cls, isList: false, isCustomClass: true, className: cls);
    }
    if (schema['type'] == 'array') {
      final items = schema['items'] as Map<String, dynamic>?;
      if (items != null && items.containsKey('\$ref')) {
        final ref = items['\$ref'] as String;
        final key = ref.replaceFirst('#/components/schemas/', '');
        final cls = schemaClassNames[key] ?? 'dynamic';
        return _ReturnTypeInfo(
            type: 'List<$cls>',
            isList: true,
            isCustomClass: true,
            className: cls);
      }
      if (items != null && items['type'] != null) {
        final prim = _parseParameterType(items);
        return _ReturnTypeInfo(
            type: 'List<$prim>', isList: true, isCustomClass: false);
      }
      return _ReturnTypeInfo(
          type: 'List<dynamic>', isList: true, isCustomClass: false);
    }
    if (schema['type'] == 'integer') {
      return _ReturnTypeInfo(type: 'int', isList: false, isCustomClass: false);
    }
    if (schema['type'] == 'number') {
      return _ReturnTypeInfo(
          type: 'double', isList: false, isCustomClass: false);
    }
    if (schema['type'] == 'boolean') {
      return _ReturnTypeInfo(type: 'bool', isList: false, isCustomClass: false);
    }
    if (schema['type'] == 'string') {
      return _ReturnTypeInfo(
          type: 'String', isList: false, isCustomClass: false);
    }
    if (schema['type'] == 'object') {
      return _ReturnTypeInfo(
          type: 'Map<String, dynamic>', isList: false, isCustomClass: false);
    }

    return _ReturnTypeInfo(
        type: 'dynamic', isList: false, isCustomClass: false);
  }

  String _buildDeserializationCode(_ReturnTypeInfo info) {
    if (info.type == 'void') {
      return 'final void data = null;';
    }
    if (info.isList && info.isCustomClass) {
      return 'final List<${info.className}> data = (resp.data as List<dynamic>?)?.map((e) => ${info.className}.fromJson(e as Map<String, dynamic>)).toList() ?? <${info.className}>[];';
    }
    if (info.isList && !info.isCustomClass) {
      final innerType = info.type.replaceAll(RegExp(r'^List<|>[\?]?$'), '');
      if (innerType == 'int') {
        return 'final List<int> data = (resp.data as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? <int>[];';
      }
      if (innerType == 'double') {
        return 'final List<double> data = (resp.data as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? <double>[];';
      }
      if (innerType == 'bool') {
        return 'final List<bool> data = (resp.data as List<dynamic>?)?.map((e) => e as bool).toList() ?? <bool>[];';
      }
      if (innerType == 'String') {
        return 'final List<String> data = (resp.data as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];';
      }
      return 'final ${info.type} data = (resp.data as List<dynamic>?)?.map((e) => e as $innerType).toList() ?? <$innerType>[];';
    }
    if (info.isCustomClass) {
      return 'final ${info.className}? data = resp.data is Map<String, dynamic> ? ${info.className}.fromJson(resp.data as Map<String, dynamic>) : null;';
    }
    if (info.type == 'int') {
      return 'final int? data = resp.data is num ? (resp.data as num).toInt() : (resp.data is String ? int.tryParse(resp.data as String) : null);';
    }
    if (info.type == 'double') {
      return 'final double? data = resp.data is num ? (resp.data as num).toDouble() : (resp.data is String ? double.tryParse(resp.data as String) : null);';
    }
    if (info.type == 'bool') {
      return 'final bool? data = resp.data as bool?;';
    }
    if (info.type == 'String') {
      return 'final String? data = resp.data?.toString();';
    }
    return 'final dynamic data = resp.data;';
  }

  String _buildMethodName(String verb, String path, String? operationId) {
    if (operationId != null && operationId.isNotEmpty) {
      var clean = operationId.replaceAll(RegExp(r'ApiV\d+'), '');
      return _toCamelCase(clean);
    }
    final pathParamMatches = RegExp(r'\{([^}]+)\}').allMatches(path);
    final pathParamNames = pathParamMatches.map((m) => m.group(1)!).toList();

    final cleanPath = path
        .replaceAll(RegExp(r'^/api/v\d+/'), '/')
        .replaceAll(RegExp(r'^/api/'), '/')
        .replaceAll(RegExp(r'\{[^}]+\}'), '');
    final parts = cleanPath.split('/').where((p) => p.isNotEmpty).toList();

    if (pathParamNames.isNotEmpty) {
      parts.add('by');
      parts.addAll(pathParamNames);
    }

    final nameParts = [verb, ...parts];
    return _toCamelCase(nameParts.join('_'));
  }

  Map<String, dynamic>? _getSuccessResponseSchema(Map<String, dynamic> op) {
    final responses = op['responses'] as Map<String, dynamic>?;
    if (responses == null) return null;
    final resp200 = responses['200'] ?? responses['201'];
    if (resp200 is Map<String, dynamic>) {
      final content = resp200['content'] as Map<String, dynamic>?;
      final jsonContent = content?['application/json'] ?? content?['text/json'];
      return jsonContent?['schema'] as Map<String, dynamic>?;
    }
    return null;
  }

  Map<String, dynamic>? _getRequestBodySchema(Map<String, dynamic> op) {
    final reqBody = op['requestBody'] as Map<String, dynamic>?;
    final content = reqBody?['content'] as Map<String, dynamic>?;
    if (content == null || content.isEmpty) return null;
    final jsonContent = content['application/json'] ?? content['text/json'];
    if (jsonContent != null) {
      return jsonContent['schema'] as Map<String, dynamic>?;
    }
    final otherTypes = content.keys.join(', ');
    _warnings.add(
        'Unsupported requestBody content-type ($otherTypes) for operation "${op['operationId'] ?? 'unknown'}"');
    return null;
  }

  void _extractModelImports(
      Map<String, dynamic> schema, Set<String> modelImports) {
    if (schema.containsKey('\$ref')) {
      final ref = schema['\$ref'] as String;
      final key = ref.replaceFirst('#/components/schemas/', '');
      final cls = schemaClassNames[key];
      if (cls != null) modelImports.add(cls);
    } else if (schema['type'] == 'array') {
      final items = schema['items'] as Map<String, dynamic>?;
      if (items != null) _extractModelImports(items, modelImports);
    }
  }

  void _generateExportFile() {
    final buffer = StringBuffer();
    buffer.writeln("// Autogenerated OpenAPI Exports for Lidarr\n");
    buffer.writeln("export 'responses/api_response.dart';");
    buffer.writeln("export 'responses/lidarr_error.dart';");
    buffer.writeln("export 'responses/lidarr_exception.dart';");
    buffer.writeln("export 'responses/enum_normalizer.dart';");

    for (final entry in schemas.entries) {
      final className = schemaClassNames[entry.key]!;
      final fileName = _toSnakeCase(className);
      buffer.writeln("export 'models/$fileName.dart';");
    }

    for (final tag in tagEndpoints.keys) {
      final className = 'Raw${_toPascalCase(tag)}Api';
      final fileName = _toSnakeCase(className);
      buffer.writeln("export 'api/$fileName.dart';");
    }

    _writeFileIfChanged('$outputDir/generated.dart', buffer.toString());
  }
}

class _ModelField {
  final String jsonKey;
  final String fieldName;
  final String dartType;
  final bool isNullable;
  final bool isList;
  final bool isCustomClass;
  final String? customClassName;
  final String? description;
  final String? format;
  final bool readOnly;
  final dynamic defaultValue;
  final bool isDeprecated;

  _ModelField({
    required this.jsonKey,
    required this.fieldName,
    required this.dartType,
    required this.isNullable,
    this.isList = false,
    this.isCustomClass = false,
    this.customClassName,
    this.description,
    this.format,
    this.readOnly = false,
    this.defaultValue,
    this.isDeprecated = false,
  });
}

class _TypeInfo {
  final String dartType;
  final bool isNullable;
  final bool isList;
  final bool isCustomClass;
  final String? customClassName;

  _TypeInfo({
    required this.dartType,
    required this.isNullable,
    this.isList = false,
    this.isCustomClass = false,
    this.customClassName,
  });
}

class _ReturnTypeInfo {
  final String type;
  final bool isList;
  final bool isCustomClass;
  final String? className;

  _ReturnTypeInfo({
    required this.type,
    required this.isList,
    required this.isCustomClass,
    this.className,
  });
}
