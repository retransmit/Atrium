import 'package:core_models/core_models.dart';

const Instance technitiumTestInstance = Instance(
  id: 'technitium-test',
  name: 'Technitium Test',
  kind: ServiceKind.technitium,
  localUrl: 'http://127.0.0.1:5380',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.apiKey(apiKey: 'test-token-12345'),
);
