// ignore_for_file: avoid_print, avoid_dynamic_calls, avoid_redundant_argument_values, require_trailing_commas, prefer_const_declarations, prefer_single_quotes, prefer_final_locals
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final inputPath = args.isNotEmpty
      ? args[0]
      : '${Directory.current.path}/tool/openapi.json';
  final outputDir = args.length > 1
      ? args[1]
      : '${Directory.current.path}/lib/src/generated';

  final file = File(inputPath);
  if (!file.existsSync()) {
    print('Error: Input OpenAPI JSON file not found at $inputPath');
    exit(1);
  }

  print('Parsing Ombi OpenAPI specification from: $inputPath');
  final jsonString = file.readAsStringSync();
  final spec = jsonDecode(jsonString) as Map<String, dynamic>;

  final parser = OmbiOpenApiParser(spec, outputDir);
  parser.generateAll();
  print('Successfully generated all Ombi Dart models and API clients in: $outputDir');
}

class OmbiOpenApiParser {
  final Map<String, dynamic> spec;
  final String outputDir;

  final Map<String, String> schemaClassNames = {};
  final Map<String, dynamic> schemas = {};
  final Map<String, List<Map<String, dynamic>>> tagEndpoints = {};

  OmbiOpenApiParser(this.spec, this.outputDir) {
    _initSchemas();
    _initEndpoints();
  }

  void _initSchemas() {
    final rawSchemas =
        (spec['components']?['schemas'] as Map<String, dynamic>?) ?? {};
    schemas.addAll(rawSchemas);

    for (final fullKey in schemas.keys) {
      schemaClassNames[fullKey] = _resolveClassName(fullKey, rawSchemas);
    }
  }

  void _initEndpoints() {
    final paths = (spec['paths'] as Map<String, dynamic>?) ?? {};
    for (final pathEntry in paths.entries) {
      final path = pathEntry.key;
      final methods = pathEntry.value as Map<String, dynamic>;

      for (final methodEntry in methods.entries) {
        final verb = methodEntry.key.toLowerCase();
        if (!['get', 'post', 'put', 'delete', 'patch'].contains(verb)) continue;

        final op = methodEntry.value as Map<String, dynamic>;
        final tags = (op['tags'] as List<dynamic>?)?.cast<String>() ?? ['Default'];
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
      'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch',
      'class', 'const', 'continue', 'covariant', 'default', 'deferred', 'do',
      'dynamic', 'else', 'enum', 'export', 'extends', 'extension', 'external',
      'factory', 'false', 'finally', 'for', 'function', 'get', 'hide',
      'if', 'implements', 'import', 'in', 'interface', 'is', 'late', 'library',
      'mixin', 'new', 'null', 'on', 'operator', 'part', 'required', 'rethrow',
      'return', 'set', 'show', 'static', 'super', 'switch', 'sync', 'this',
      'throw', 'true', 'try', 'typedef', 'var', 'void', 'while', 'with', 'yield'
    };
    return keywords.contains(camel) ? '${camel}Val' : camel;
  }

  String _toSnakeCase(String name) {
    return name
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => '_${m.group(1)!.toLowerCase()}')
        .replaceAll(RegExp(r'^_'), '')
        .replaceAll(RegExp(r'_+'), '_');
  }

  String _resolveClassName(String fullKey, Map<String, dynamic> rawSchemas) {
    final genericMatch = RegExp(r'`\d+\[\[(?:[^\.,]+\.)*([^\.,]+),').firstMatch(fullKey);
    final genericSuffix = genericMatch != null
        ? _sanitizeIdentifier(genericMatch.group(1)!)
        : '';

    final cleanBase = fullKey.replaceAll(RegExp(r'`\d+\[\[.*'), '');
    final parts = cleanBase.split('.');
    final short = parts.last;

    final collisions = rawSchemas.keys
        .where((k) => k.replaceAll(RegExp(r'`\d+\[\[.*'), '').split('.').last == short)
        .toList();

    String baseName;
    if (collisions.length == 1) {
      baseName = _sanitizeIdentifier(short);
    } else {
      final meaningful = parts
          .where((p) => !['Ombi', 'Api', 'External', 'Models', 'Core', 'V1'].contains(p))
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
  }

  void _createDirectories() {
    final dir = Directory(outputDir);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    Directory('$outputDir/models').createSync(recursive: true);
    Directory('$outputDir/responses').createSync(recursive: true);
    Directory('$outputDir/api').createSync(recursive: true);
  }

  void _generateResponseFiles() {
    final apiResponseContent = '''
import 'ombi_error.dart';

/// Standardized API response container for Ombi API calls.
class ApiResponse<T> {
  final T? data;
  final OmbiError? error;
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
    File('$outputDir/responses/api_response.dart')
        .writeAsStringSync(apiResponseContent);

    final errorContent = '''
import 'package:dio/dio.dart';

/// Error model returned by Ombi API endpoints.
class OmbiError {
  final String? message;
  final String? description;
  final List<String> errors;

  const OmbiError({
    this.message,
    this.description,
    this.errors = const [],
  });

  factory OmbiError.fromJson(Map<String, dynamic> json) {
    final errList = (json['errors'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    return OmbiError(
      message: json['message'] as String? ?? json['error'] as String?,
      description: json['description'] as String?,
      errors: errList,
    );
  }

  factory OmbiError.fromDio(DioException exception) {
    if (exception.response?.data is Map<String, dynamic>) {
      return OmbiError.fromJson(
          exception.response!.data as Map<String, dynamic>);
    }
    return OmbiError(
      message: exception.message ?? 'HTTP Error \${exception.response?.statusCode}',
      description: exception.type.toString(),
    );
  }
}
''';
    File('$outputDir/responses/ombi_error.dart')
        .writeAsStringSync(errorContent);

    final exceptionContent = '''
import 'ombi_error.dart';

/// Custom exception thrown on Ombi API failure.
class OmbiException implements Exception {
  final String message;
  final int? statusCode;
  final OmbiError? error;

  const OmbiException(
    this.message, {
    this.statusCode,
    this.error,
  });

  @override
  String toString() =>
      'OmbiException(statusCode: \$statusCode, message: \$message, error: \$error)';
}
''';
    File('$outputDir/responses/ombi_exception.dart')
        .writeAsStringSync(exceptionContent);
  }

  void _generateModelFiles() {
    for (final entry in schemas.entries) {
      final fullKey = entry.key;
      final schema = entry.value as Map<String, dynamic>;
      final className = schemaClassNames[fullKey]!;
      final fileName = _toSnakeCase(className);

      final code = _buildModelCode(fullKey, className, schema);
      File('$outputDir/models/$fileName.dart').writeAsStringSync(code);
    }
  }

  String _buildModelCode(
      String fullKey, String className, Map<String, dynamic> schema) {
    final isEnum = schema.containsKey('enum');
    if (isEnum) {
      return _buildEnumCode(className, schema);
    }

    final properties = (schema['properties'] as Map<String, dynamic>?) ?? {};
    final title = schema['title'] as String?;
    final description = schema['description'] as String?;

    final imports = <String>{};
    final fields = <_ModelField>[];
    final usedFieldNames = <String>{};

    for (final propEntry in properties.entries) {
      final propKey = propEntry.key;
      final propSchema = propEntry.value as Map<String, dynamic>;
      var fieldName = _toCamelCase(propKey);
      if (usedFieldNames.contains(fieldName)) {
        fieldName = '${fieldName}Alt';
      }
      usedFieldNames.add(fieldName);

      final fieldTypeInfo = _parseType(propSchema, imports);
      final propDesc = propSchema['description'] as String?;
      final isDeprecated = propSchema['deprecated'] == true;

      fields.add(_ModelField(
        jsonKey: propKey,
        fieldName: fieldName,
        dartType: fieldTypeInfo.dartType,
        isNullable: fieldTypeInfo.isNullable,
        isList: fieldTypeInfo.isList,
        isCustomClass: fieldTypeInfo.isCustomClass,
        customClassName: fieldTypeInfo.customClassName,
        description: propDesc,
        isDeprecated: isDeprecated,
      ));
    }

    final fileName = _toSnakeCase(className);
    final buffer = StringBuffer();
    buffer.writeln("// ignore_for_file: unused_import");
    buffer.writeln("import 'package:freezed_annotation/freezed_annotation.dart';");
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
        if (f.description != null && f.description!.isNotEmpty) {
          for (final line in f.description!.split('\n')) {
            buffer.writeln('    /// ${line.trim()}');
          }
        }
        if (f.isDeprecated) {
          buffer.writeln("    @Deprecated('Marked deprecated in OpenAPI spec')");
        }
        final typeStr = f.dartType.endsWith('?') ? f.dartType : '${f.dartType}?';
        buffer.writeln("    @JsonKey(name: '${f.jsonKey}') $typeStr ${f.fieldName},");
      }
      buffer.writeln('  }) = _$className;');
    }
    buffer.writeln();
    buffer.writeln('  factory $className.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$${className}FromJson(json);');
    buffer.writeln('}');

    return buffer.toString();
  }

  String _buildEnumCode(String className, Map<String, dynamic> schema) {
    final buffer = StringBuffer();
    final enumList = schema['enum'] as List<dynamic>;
    final fileName = _toSnakeCase(className);

    buffer.writeln("// ignore_for_file: unused_import");
    buffer.writeln("import 'package:freezed_annotation/freezed_annotation.dart';");
    buffer.writeln();
    buffer.writeln("part '$fileName.g.dart';");
    buffer.writeln();
    buffer.writeln('/// Enum `$className`');
    buffer.writeln('@JsonEnum(alwaysCreate: true)');
    buffer.writeln('enum $className {');

    for (final item in enumList) {
      final strVal = item.toString();
      final identifier = _toCamelCase(strVal);
      // Most of Ombi's enums are integers on the wire. Quoting them made
      // every model carrying one throw as soon as it met the real value.
      buffer.writeln(
        item is num ? '  @JsonValue($item)' : "  @JsonValue('$strVal')",
      );
      buffer.writeln('  $identifier,');
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  _TypeInfo _parseType(
      Map<String, dynamic> schema, Set<String> imports) {
    if (schema.containsKey('\$ref')) {
      final ref = schema['\$ref'] as String;
      final key = ref.replaceFirst('#/components/schemas/', '');
      final cls = schemaClassNames[key] ?? 'dynamic';
      imports.add(cls);
      return _TypeInfo(
          dartType: cls, isNullable: true, isCustomClass: true, customClassName: cls);
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
        customClassName: itemType.isCustomClass ? itemType.customClassName : null,
      );
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

    return _TypeInfo(dartType: 'dynamic', isNullable: true);
  }

  void _generateApiFiles() {
    for (final entry in tagEndpoints.entries) {
      final tag = entry.key;
      final endpoints = entry.value;
      final className = 'Raw${_toPascalCase(tag)}Api';
      final fileName = _toSnakeCase(className);

      final code = _buildApiCode(tag, className, endpoints);
      File('$outputDir/api/$fileName.dart').writeAsStringSync(code);
    }
  }

  String _buildApiCode(
      String tag, String className, List<Map<String, dynamic>> endpoints) {
    final buffer = StringBuffer();
    final imports = <String>{
      "import 'dart:convert';",
      "import 'package:dio/dio.dart';",
      "import '../responses/api_response.dart';",
      "import '../responses/ombi_error.dart';",
      "import '../responses/ombi_exception.dart';",
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

      final respSchema = _getSuccessResponseSchema(op);
      final returnTypeInfo = _getReturnTypeInfo(respSchema);
      final returnType = returnTypeInfo.type;

      buffer.writeln('  Future<ApiResponse<$returnType>> $methodName(');

      final params = (op['parameters'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final pathParams = params.where((p) => p['in'] == 'path').toList();
      final queryParams = params.where((p) => p['in'] == 'query').toList();
      final bodySchema = _getRequestBodySchema(op);

      final methodParams = <String>[];
      for (final p in pathParams) {
        final pName = _toCamelCase(p['name'] as String);
        methodParams.add('required String $pName');
      }
      for (final q in queryParams) {
        final qName = _toCamelCase(q['name'] as String);
        methodParams.add('String? $qName');
      }
      if (bodySchema != null) {
        methodParams.add('dynamic body');
      }

      if (methodParams.isNotEmpty) {
        buffer.writeln('    {${methodParams.join(', ')}}');
      }
      buffer.writeln('  ) async {');

      var interpolatedPath = path;
      for (final p in pathParams) {
        final rawName = p['name'] as String;
        final pName = _toCamelCase(rawName);
        interpolatedPath = interpolatedPath.replaceAll('{$rawName}', '\$$pName');
      }

      buffer.writeln('    try {');
      buffer.writeln('      final Response<dynamic> resp = await _dio.$verb<dynamic>(');
      buffer.writeln("        '$interpolatedPath',");
      if (queryParams.isNotEmpty) {
        buffer.writeln('        queryParameters: <String, dynamic>{');
        for (final q in queryParams) {
          final qRaw = q['name'] as String;
          final qName = _toCamelCase(qRaw);
          buffer.writeln("          if ($qName != null) '$qRaw': $qName,");
        }
        buffer.writeln('        },');
      }
      if (bodySchema != null) {
        buffer.writeln('        data: body,');
      }
      buffer.writeln('      );');

      buffer.writeln('      ${_buildDeserializationCode(returnTypeInfo)}');
      buffer.writeln('      return ApiResponse.success(data, statusCode: resp.statusCode);');
      buffer.writeln('    } on DioException catch (e) {');
      buffer.writeln('      return ApiResponse.error(OmbiError.fromDio(e), statusCode: e.response?.statusCode);');
      buffer.writeln('    }');
      buffer.writeln('  }');
      buffer.writeln();
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  _ReturnTypeInfo _getReturnTypeInfo(Map<String, dynamic>? schema) {
    if (schema == null) return _ReturnTypeInfo(type: 'void', isList: false, isCustomClass: false);
    if (schema.containsKey('\$ref')) {
      final ref = schema['\$ref'] as String;
      final key = ref.replaceFirst('#/components/schemas/', '');
      final cls = schemaClassNames[key] ?? 'dynamic';
      final isEnum = schemas[key] != null && (schemas[key] as Map<String, dynamic>).containsKey('enum');
      return _ReturnTypeInfo(type: cls, isList: false, isCustomClass: !isEnum, isEnum: isEnum, className: cls);
    }
    if (schema['type'] == 'array') {
      final items = schema['items'] as Map<String, dynamic>?;
      if (items != null && items.containsKey('\$ref')) {
        final ref = items['\$ref'] as String;
        final key = ref.replaceFirst('#/components/schemas/', '');
        final cls = schemaClassNames[key] ?? 'dynamic';
        final isEnum = schemas[key] != null && (schemas[key] as Map<String, dynamic>).containsKey('enum');
        return _ReturnTypeInfo(type: 'List<$cls>', isList: true, isCustomClass: !isEnum, isEnum: isEnum, className: cls);
      }
      return _ReturnTypeInfo(type: 'List<dynamic>', isList: true, isCustomClass: false);
    }
    return _ReturnTypeInfo(type: 'dynamic', isList: false, isCustomClass: false);
  }

  String _buildDeserializationCode(_ReturnTypeInfo info) {
    if (info.type == 'void') {
      return 'final void data = null;';
    }
    if (info.isEnum) {
      return 'final ${info.className}? data = resp.data != null ? ${info.className}.values.cast<${info.className}?>().firstWhere((e) => e?.name == resp.data.toString(), orElse: () => null) : null;';
    }
    if (info.isList && info.isCustomClass) {
      return 'final List<${info.className}> data = (resp.data as List<dynamic>?)?.map((e) => ${info.className}.fromJson(e as Map<String, dynamic>)).toList() ?? <${info.className}>[];';
    }
    if (info.isCustomClass) {
      return 'final ${info.className}? data = resp.data is Map<String, dynamic> ? ${info.className}.fromJson(resp.data as Map<String, dynamic>) : null;';
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
    final jsonContent = content?['application/json'] ?? content?['text/json'];
    return jsonContent?['schema'] as Map<String, dynamic>?;
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
    buffer.writeln("// Autogenerated OpenAPI Exports for Ombi\n");
    buffer.writeln("export 'responses/api_response.dart';");
    buffer.writeln("export 'responses/ombi_error.dart';");
    buffer.writeln("export 'responses/ombi_exception.dart';");

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

    File('$outputDir/generated.dart').writeAsStringSync(buffer.toString());
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
  final bool isEnum;
  final String? className;

  _ReturnTypeInfo({
    required this.type,
    required this.isList,
    required this.isCustomClass,
    this.isEnum = false,
    this.className,
  });
}
