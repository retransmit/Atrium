import 'package:core_models/core_models.dart';

const Instance prowlarrTestInstance = Instance(
  id: 'prowlarr-test',
  name: 'Prowlarr',
  kind: ServiceKind.prowlarr,
  localUrl: 'http://prowlarr.test',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.apiKey(apiKey: 'not-a-secret'),
);
