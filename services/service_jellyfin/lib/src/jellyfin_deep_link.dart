import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'jellyfin_client.dart';

/// Launches the Jellyfin app for a given item.
Future<void> launchJellyfinDeepLink(
    BuildContext context, JellyfinClient client, String itemId) async {
  if (Platform.isAndroid) {
    try {
      const MethodChannel channel = MethodChannel('app.atrium/launcher');

      // Try official mobile app
      bool launched =
          await channel.invokeMethod<bool>('launchPackage', <String, dynamic>{
                'package': 'org.jellyfin.mobile',
              }) ??
              false;

      if (launched) return;

      // Try official Android TV app
      launched =
          await channel.invokeMethod<bool>('launchPackage', <String, dynamic>{
                'package': 'org.jellyfin.androidtv',
              }) ??
              false;

      if (launched) return;

      // If both fail, show error
      if (context.mounted) {
        _showNotInstalled(context);
      }
      return;
    } catch (e) {
      if (context.mounted) {
        _showNotInstalled(context);
      }
      return;
    }
  }

  if (context.mounted) {
    _showNotInstalled(context);
  }
}

void _showNotInstalled(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Could not open the Jellyfin item.'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 3),
    ),
  );
}
