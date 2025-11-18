import 'dart:async';

import 'dart:convert';
import 'dart:math';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:crypto/crypto.dart';
import 'package:desktop_webview_auth/desktop_webview_auth.dart';
import 'package:desktop_webview_auth/google.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_io/io.dart' as universal_io;
import 'package:window_manager/window_manager.dart';

Future<String?> googleOAuth(BuildContext context) async {
  String? token;

  final defaultScopes = [
    'https://www.googleapis.com/auth/cloudplatformprojects',
    'https://www.googleapis.com/auth/firebase',
    'https://www.googleapis.com/auth/datastore'
  ];

  // android / web implementation
  if (universal_io.Platform.isAndroid || kIsWeb) {
    // on web, show a dialog to make sure users allow scopes
    if (kIsWeb) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: context.theme.colorScheme.properSurface,
            title: Text("Important Notice", style: context.theme.textTheme.titleLarge),
            content: Text(
              'Please make sure to allow BlueBubbles to see, edit, configure, and delete your Google Cloud data after signing in. BlueBubbles will only use this ability to find your server URL.',
              style: context.theme.textTheme.bodyLarge,
            ),
            actions: <Widget>[
              TextButton(
                child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }

    // initialize gsi
    final gsi = GoogleSignIn(clientId: fdb.getClientId(), scopes: defaultScopes);
    try {
      // sign out then sign in
      await gsi.signOut();
      final account = await gsi.signIn();
      if (account != null) {
        // get access token
        await account.clearAuthCache();
        final auth = await account.authentication;
        token = auth.accessToken;
        // make sure scopes were granted on web
        if (kIsWeb && !(await gsi.canAccessScopes(defaultScopes, accessToken: token))) {
          final result = await gsi.requestScopes(defaultScopes);
          if (!result) {
            throw Exception("Scopes not granted!");
          }
        }
      } else {
        // error if account is not present
        throw Exception("No account!");
      }
    } catch (e, stack) {
      Logger.error("Failed to sign in with Google (Android/Web)", error: e, trace: stack);
      return null;
    }
    // desktop implementation
  } else {
    if (universal_io.Platform.isWindows && !(await _hasWebView2Runtime())) {
      await _showWebViewMissingDialog(context);
      return null;
    }

    final args = GoogleSignInArgs(
      clientId: fdb.getClientId()!,
      redirectUri: 'http://localhost:8641/oauth/callback',
      scope: defaultScopes.join(' '),
    );
    try {
      final width = ss.prefs.getDouble('window-width')?.toInt();
      final height = ss.prefs.getDouble('window-height')?.toInt();
      final result = await DesktopWebviewAuth.signIn(
        args,
        width: width != null ? (width * 0.9).ceil() : null,
        height: height != null ? (height * 0.9).ceil() : null,
      ).timeout(const Duration(seconds: 120));
      Future.delayed(const Duration(milliseconds: 500), () async => await windowManager.show());
      token = result?.accessToken;
      token ??= await _desktopBrowserOAuth(context, defaultScopes);
      if (token == null) {
        await _showDesktopOAuthErrorDialog(context);
      }
    } on TimeoutException {
      Logger.error("Google sign-in timed out waiting for desktop webview");
      token = await _desktopBrowserOAuth(context, defaultScopes);
      if (token == null) {
        await _showDesktopOAuthErrorDialog(context);
      }
    } catch (e, stack) {
      Logger.error("Failed to sign in with Google (Desktop)", error: e, trace: stack);
      token = await _desktopBrowserOAuth(context, defaultScopes);
      if (token == null) {
        await _showDesktopOAuthErrorDialog(context);
      }
      return null;
    }
  }
  return token;
}

Future<bool> _hasWebView2Runtime() async {
  // WebView2 installs under one of these roots on Windows. If none exist, we likely can't render the webview.
  final candidates = <String?>[
    universal_io.Platform.environment['PROGRAMFILES(X86)'],
    universal_io.Platform.environment['PROGRAMFILES'],
    universal_io.Platform.environment['LOCALAPPDATA'],
  ];

  for (final root in candidates.whereType<String>()) {
    final installDir = universal_io.Directory(path.join(root, 'Microsoft', 'EdgeWebView', 'Application'));
    if (await installDir.exists()) {
      final versionDirs = installDir.listSync().whereType<universal_io.Directory>();
      if (versionDirs.isNotEmpty) {
        return true;
      }
    }
  }
  return false;
}

Future<void> _showWebViewMissingDialog(BuildContext context) async {
  const runtimeUrl = 'https://go.microsoft.com/fwlink/p/?LinkId=2124703';
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('WebView runtime required', style: context.theme.textTheme.titleLarge),
      content: Text(
        'We could not open the Google sign-in window. On Windows this usually means the Microsoft Edge WebView2 runtime is missing. Install the runtime, then try again.',
        style: context.theme.textTheme.bodyLarge,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close', style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
        ),
        TextButton(
          onPressed: () async {
            await launchUrl(Uri.parse(runtimeUrl), mode: LaunchMode.externalApplication);
            Navigator.of(context).pop();
          },
          child: Text('Install runtime', style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
        ),
      ],
      backgroundColor: context.theme.colorScheme.properSurface,
    ),
  );
}

Future<void> _showDesktopOAuthErrorDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Google sign-in failed', style: context.theme.textTheme.titleLarge),
      content: Text(
        'Something went wrong opening the Google sign-in window. Please try again. If you continue to see a blank window, install or repair the Microsoft Edge WebView2 runtime.',
        style: context.theme.textTheme.bodyLarge,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('OK', style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
        ),
      ],
      backgroundColor: context.theme.colorScheme.properSurface,
    ),
  );
}

Future<String?> _desktopBrowserOAuth(BuildContext context, List<String> scopes) async {
  universal_io.HttpServer? server;
  try {
    server = await universal_io.HttpServer.bind(universal_io.InternetAddress.loopbackIPv4, 0);
    final verifier = _generateCodeVerifier();
    final challenge = base64Url.encode(sha256.convert(utf8.encode(verifier)).bytes).replaceAll('=', '');
    final redirectUri = 'http://localhost:${server.port}/oauth/callback';

    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': fdb.getClientId()!,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': scopes.join(' '),
      'access_type': 'offline',
      'prompt': 'consent',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    });

    await launchUrl(authUri, mode: LaunchMode.externalApplication);

    String? code;
    await for (final request in server) {
      if (request.uri.path == '/oauth/callback') {
        code = request.uri.queryParameters['code'];
        request.response
          ..statusCode = 200
          ..headers.contentType = universal_io.ContentType.html
          ..write('<html><body><script>window.close();</script>You may close this window.</body></html>');
        await request.response.close();
        await server.close(force: true);
        break;
      }
    }

    if (code == null) return null;
    return await _exchangeCodeForToken(code, verifier, redirectUri);
  } catch (e, stack) {
    Logger.error('Desktop browser OAuth failed', error: e, trace: stack);
    return null;
  } finally {
    await server?.close();
  }
}

String _generateCodeVerifier() {
  const length = 64;
  const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._~';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
}

Future<String?> _exchangeCodeForToken(String code, String verifier, String redirectUri) async {
  try {
    final client = universal_io.HttpClient();
    final request = await client.postUrl(Uri.parse('https://oauth2.googleapis.com/token'));
    final body = {
      'client_id': fdb.getClientId()!,
      'code': code,
      'code_verifier': verifier,
      'grant_type': 'authorization_code',
      'redirect_uri': redirectUri,
    };
    final encoded = body.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
    request.headers.contentType = universal_io.ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    request.write(encoded);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    client.close();

    if (response.statusCode != 200) {
      Logger.error('Token exchange failed', error: json);
      return null;
    }

    return json['access_token'] as String?;
  } catch (e, stack) {
    Logger.error('Failed exchanging Google auth code', error: e, trace: stack);
    return null;
  }
}

Future<List<Map>> fetchFirebaseProjects(String token) async {
  List<Map> usableProjects = [];
  try {
    // query firebase projects
    final response = await http.getFirebaseProjects(token);
    final projects = response.data['results'];
    List<Object> errors = [];
    // find projects with RTDB or cloud firestore
    if (projects.isNotEmpty) {
      for (Map e in projects) {
        if (e['resources']['realtimeDatabaseInstance'] != null) {
          try {
            final serverUrlResponse = await http.getServerUrlRTDB(e['resources']['realtimeDatabaseInstance'], token);
            e['serverUrl'] = serverUrlResponse.data['serverUrl'];
            usableProjects.add(e);
          } catch (ex) {
            errors.add("Realtime Database Error: $ex");
          }
        } else {
          try {
            final serverUrlResponse = await http.getServerUrlCF(e['projectId'], token);
            e['serverUrl'] = serverUrlResponse.data['fields']['serverUrl']['stringValue'];
            usableProjects.add(e);
          } catch (ex) {
            errors.add("Firestore Database Error: $ex");
          }
        }
      }

      if (usableProjects.isEmpty && errors.isNotEmpty) {
        throw Exception(errors[0]);
      }

      usableProjects.removeWhere((element) => element['serverUrl'] == null);

      return usableProjects;
    }
    return [];
  } catch (e) {
    return [];
  }
}

Future<void> requestPassword(BuildContext context, String serverUrl, Future<void> Function(String url, String password) connect) async {
  final TextEditingController passController = TextEditingController();
  final RxBool enabled = false.obs;
  await showDialog(
    context: context,
    builder: (_) {
      return Obx(
        () => AlertDialog(
          actions: [
            TextButton(
              child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
              onPressed: () => Get.back(),
            ),
            AnimatedContainer(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              duration: const Duration(milliseconds: 100),
              child: AbsorbPointer(
                absorbing: !enabled.value,
                child: TextButton(
                  child: Text("OK",
                    style: context.theme.textTheme.bodyLarge!.copyWith(
                      color: enabled.value ? context.theme.colorScheme.primary : context.theme.disabledColor,
                    ),
                  ),
                  onPressed: () async {
                    if (passController.text.isEmpty) {
                      return;
                    }
                    Get.back();
                  },
                ),
              ),
            ),
          ],
          content: TextField(
            controller: passController,
            decoration: const InputDecoration(
              labelText: "Password",
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            obscureText: true,
            autofillHints: [AutofillHints.password],
            onChanged: (str) {
              if (enabled.value ^ str.isNotEmpty) {
                enabled.value = str.isNotEmpty;
              }
            },
            onSubmitted: (str) {
              if (passController.text.isEmpty) {
                return;
              }
              Get.back();
            },
          ),
          title: Text("Enter Server Password", style: context.theme.textTheme.titleLarge),
          backgroundColor: context.theme.colorScheme.properSurface,
        ),
      );
    },
  );

  await connect(serverUrl, passController.text);
}
