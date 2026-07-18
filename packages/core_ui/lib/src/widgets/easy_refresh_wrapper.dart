import 'dart:async';
import 'dart:io';

import 'package:easy_refresh/easy_refresh.dart' as er;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;

class EasyRefresh extends material.StatelessWidget {
  final er.Header? header;
  final er.Footer? footer;
  final er.EasyRefreshController? controller;
  final FutureOr<void> Function()? onRefresh;
  final FutureOr<void> Function()? onLoad;
  final material.Widget child;

  const EasyRefresh({
    super.key,
    this.header,
    this.footer,
    this.controller,
    this.onRefresh,
    this.onLoad,
    required this.child,
  });

  @override
  material.Widget build(material.BuildContext context) {
    final isTest = kDebugMode && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) {
      if (onRefresh == null) return child;
      return material.RefreshIndicator(
        onRefresh: () async {
          await onRefresh!();
        },
        child: child,
      );
    }
    
    return er.EasyRefresh(
      header: header,
      footer: footer,
      controller: controller,
      onRefresh: onRefresh,
      onLoad: onLoad,
      triggerAxis: material.Axis.vertical,
      child: child,
    );
  }
}

class HeaderLocator extends material.StatelessWidget {
  final bool _isSliver;

  const HeaderLocator({super.key}) : _isSliver = false;
  const HeaderLocator.sliver({super.key}) : _isSliver = true;

  @override
  material.Widget build(material.BuildContext context) {
    final isTest = kDebugMode && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) {
      if (_isSliver) {
        return const material.SliverToBoxAdapter(child: material.SizedBox.shrink());
      }
      return const material.SizedBox.shrink();
    }
    
    if (_isSliver) {
      return const er.HeaderLocator.sliver();
    }
    return const er.HeaderLocator();
  }
}
