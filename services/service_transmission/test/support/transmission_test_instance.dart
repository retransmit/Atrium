import 'package:core_models/core_models.dart';

/// The instance the tests drive. No credentials, as a default install has.
const Instance transmissionTestInstance = Instance(
  id: 'test-transmission',
  name: 'Test Transmission',
  kind: ServiceKind.transmission,
  localUrl: 'http://transmission.test',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.userPass(username: '', password: ''),
);
