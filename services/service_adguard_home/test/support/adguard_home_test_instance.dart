import 'package:core_models/core_models.dart';

const Instance adguardHomeTestInstance = Instance(
  id: 'adguard-test',
  name: 'AdGuard Home',
  kind: ServiceKind.adguardHome,
  localUrl: 'http://adguard.test',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.userPass(username: 'admin', password: 'not-a-secret'),
);
