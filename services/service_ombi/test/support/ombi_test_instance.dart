import 'package:core_models/core_models.dart';

/// The instance the tests drive.
const Instance ombiTestInstance = Instance(
  id: 'test-ombi',
  name: 'Test Ombi',
  kind: ServiceKind.ombi,
  localUrl: 'http://ombi.test',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.apiKey(apiKey: 'k'),
);
