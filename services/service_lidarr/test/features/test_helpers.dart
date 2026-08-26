import 'package:core_models/core_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const testInstance = Instance(
  id: 'test-lidarr-instance',
  name: 'My Lidarr Test',
  kind: ServiceKind.lidarr,
  localUrl: 'http://localhost:8686',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuthApiKey(apiKey: 'test-api-key'),
);

extension ResponsiveTester on WidgetTester {
  Future<void> setViewport({
    double width = 360,
    double height = 800,
    double textScale = 1.0,
  }) async {
    view.physicalSize = Size(width * view.devicePixelRatio, height * view.devicePixelRatio);
    platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      view.resetPhysicalSize();
      platformDispatcher.clearTextScaleFactorTestValue();
    });
  }
}

