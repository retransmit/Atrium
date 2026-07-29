import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:core_ui/core_ui.dart';

/// A dialog that orchestrates the Plex PIN authentication flow.
///
/// It fetches a PIN code from Plex, displays it to the user, and polls
/// the Plex API until the user links the code via their browser.
/// Returns the Plex `authToken` string on success, or null if cancelled.
class PlexPinAuthDialog extends StatefulWidget {
  const PlexPinAuthDialog({super.key});

  @override
  State<PlexPinAuthDialog> createState() => _PlexPinAuthDialogState();
}

class _PlexPinAuthDialogState extends State<PlexPinAuthDialog> {
  final Dio _dio = Dio();
  final String _clientId = 'atrium-app'; // Can be random or constant
  final String _clientName = 'Atrium';

  String? _pinId;
  String? _pinCode;
  String? _error;
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _requestPin();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _dio.close();
    super.dispose();
  }

  Future<void> _requestPin() async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        'https://plex.tv/api/v2/pins?strong=true',
        options: Options(
          headers: <String, String>{
            'Accept': 'application/json',
            'X-Plex-Product': _clientName,
            'X-Plex-Client-Identifier': _clientId,
          },
        ),
      );

      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      
      if (!mounted) return;
      setState(() {
        _pinId = data['id']?.toString();
        _pinCode = data['code']?.toString();
        _isLoading = false;
      });

      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to request Plex PIN: $e';
        _isLoading = false;
      });
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (Timer timer) async {
      if (_pinId == null) return;
      
      try {
        final Response<dynamic> response = await _dio.get<dynamic>(
          'https://plex.tv/api/v2/pins/$_pinId',
          options: Options(
            headers: <String, String>{
              'Accept': 'application/json',
              'X-Plex-Client-Identifier': _clientId,
            },
          ),
        );

        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        final String? authToken = data['authToken'] as String?;

        if (authToken != null && authToken.isNotEmpty) {
          timer.cancel();
          if (mounted) {
            Navigator.of(context).pop(authToken);
          }
        }
      } catch (e) {
        // Ignore polling errors and continue polling
      }
    });
  }

  Future<void> _openBrowser() async {
    final Uri url = Uri.parse('https://plex.tv/link');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sign in with Plex'),
      content: _buildContent(),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const Text(
          '1. Go to plex.tv/link in your browser\n2. Enter the code below:',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Insets.lg),
        Text(
          _pinCode ?? '----',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 4.0,
              ),
        ),
        const SizedBox(height: Insets.lg),
        FilledButton.icon(
          onPressed: _openBrowser,
          icon: const Icon(Icons.open_in_browser),
          label: const Text('Open Browser'),
        ),
        const SizedBox(height: Insets.md),
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.0),
        ),
        const SizedBox(height: Insets.sm),
        const Text('Waiting for authentication...', style: TextStyle(fontStyle: FontStyle.italic)),
      ],
    );
  }
}
