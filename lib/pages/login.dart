import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bike_control/main.dart';
import 'package:bike_control/models/device_limit_reached_error.dart';
import 'package:bike_control/models/user_device.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/requirements/windows.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final IAPManager _iapManager = IAPManager.instance;

  StreamSubscription<AuthState>? _authSubscription;

  bool _isLoadingDevices = false;
  bool _isRegisteringDevice = false;
  bool _isRefreshingEntitlements = false;
  bool _isSyncingWindowsSubscription = false;
  bool _isPurchasingSubscription = false;

  String? _deviceId;
  String? _devicePlatform;
  String? _appVersion;
  String? _statusMessage;

  DeviceLimitReachedError? _deviceLimitError;
  Map<String, List<UserDevice>> _devicesByPlatform = const {};

  @override
  void initState() {
    super.initState();
    _authSubscription = core.supabase.auth.onAuthStateChange.listen((_) {
      unawaited(_loadSessionState());
    });
    unawaited(_loadSessionState());
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = core.supabase.auth.currentSession;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: session == null ? _buildSignedOut(context) : _buildSignedIn(context, session),
        ),
      ),
    );
  }

  Widget _buildSignedOut(BuildContext context) {
    return Column(
      spacing: 16,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Sign in to sync subscription entitlements and manage devices'),
        SignInButton(
          Buttons.google,
          onPressed: _nativeGoogleSignIn,
        ),
        SignInButton(
          Buttons.apple,
          onPressed: _signInWithApple,
        ),
        if (kDebugMode && Platform.isWindows)
          Button.secondary(
            child: const Text('Register protocol handler'),
            onPressed: () {
              WindowsProtocolHandler().register('bikecontrol');
            },
          ),
      ],
    );
  }

  Widget _buildSignedIn(BuildContext context, Session session) {
    final hasActiveSubscription = _iapManager.hasActiveSubscription;
    final isPremiumEnabled = _iapManager.isPremiumEnabled;
    final isRegisteredDevice = _iapManager.entitlements.isRegisteredDevice;
    return Column(
      spacing: 14,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          filled: true,
          child: Column(
            spacing: 12,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Basic(
                title: const Text('Account'),
                subtitle: Text(session.user.email ?? session.user.id),
                trailing: isPremiumEnabled
                    ? const PrimaryBadge(child: Text('Subscription active'))
                    : hasActiveSubscription
                    ? const DestructiveBadge(child: Text('Device not registered'))
                    : const DestructiveBadge(child: Text('Subscription inactive')),
              ),
              const Text(
                'Login-related premium features are enabled only when this account has an active subscription entitlement.',
              ).small,
              if (hasActiveSubscription && !isRegisteredDevice)
                const Text('This device is not registered yet. Register it below to enable premium features.').small,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!hasActiveSubscription)
                    Button.primary(
                      onPressed: _isPurchasingSubscription ? null : _buySubscription,
                      child: _isPurchasingSubscription
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator())
                          : const Text('Buy subscription'),
                    ),
                  if (!hasActiveSubscription)
                    Button.secondary(
                      onPressed: _isRefreshingEntitlements ? null : _refreshEntitlements,
                      child: _isRefreshingEntitlements
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator())
                          : const Text('Refresh entitlements'),
                    ),
                  Button.secondary(
                    child: const Text('Logout'),
                    onPressed: () async {
                      await core.supabase.auth.signOut();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        if (hasActiveSubscription)
          Card(
            filled: true,
            child: Column(
              spacing: 10,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Basic(
                  title: const Text('Current device'),
                  subtitle: Text(
                    'Platform: ${_devicePlatform ?? '-'}\n'
                    'Device ID: ${_deviceId ?? '-'}\n'
                    'App version: ${_appVersion ?? '-'}',
                  ).small,
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!isRegisteredDevice)
                      Button.primary(
                        onPressed: _isRegisteringDevice ? null : _registerCurrentDevice,
                        child: _isRegisteringDevice
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator())
                            : const Text('Register this device'),
                      ),
                    Button.secondary(
                      onPressed: _isRefreshingEntitlements ? null : _refreshEntitlements,
                      child: _isRefreshingEntitlements
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator())
                          : const Text('Refresh entitlements'),
                    ),
                    if (Platform.isWindows)
                      Button.secondary(
                        onPressed: _isSyncingWindowsSubscription ? null : _restoreOrSyncWindowsSubscription,
                        child: _isSyncingWindowsSubscription
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator())
                            : const Text('Restore / Sync subscription'),
                      ),
                  ],
                ),
                if (_statusMessage != null) Text(_statusMessage!).small,
              ],
            ),
          ),
        if (hasActiveSubscription && _deviceLimitError != null) _buildDeviceLimitCard(_deviceLimitError!),
        if (hasActiveSubscription)
          Card(
            filled: true,
            child: Column(
              spacing: 10,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Basic(
                  title: const Text('Registered devices'),
                  subtitle: _isLoadingDevices ? const Text('Loading devices...') : null,
                ),
                if (!_isLoadingDevices && _devicesByPlatform.isEmpty)
                  const Text('No devices found for this account.').small
                else if (!_isLoadingDevices)
                  ..._devicesByPlatform.entries.map((entry) => _buildPlatformDevices(entry.key, entry.value)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDeviceLimitCard(DeviceLimitReachedError error) {
    return Card(
      filled: true,
      borderColor: Theme.of(context).colorScheme.destructive,
      borderWidth: 1,
      child: Column(
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Basic(
            title: const Text('Device limit reached'),
            subtitle: Text(
              'Platform: ${error.platform}\nMax devices: ${error.maxDevices}',
            ).small,
            trailing: const Icon(Icons.warning_rounded),
          ),
          if (error.devices.isEmpty)
            const Text('No active devices returned by backend.').small
          else
            ...error.devices.map(_buildDeviceRow),
        ],
      ),
    );
  }

  Widget _buildPlatformDevices(String platform, List<UserDevice> devices) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: 8,
          children: [
            Text(platform.toUpperCase()).small,
            Text('${devices.where((d) => d.isActive).length} active').small,
          ],
        ),
        const SizedBox(height: 6),
        ...devices.map(_buildDeviceRow),
      ],
    );
  }

  Widget _buildDeviceRow(UserDevice device) {
    return Card(
      child: Basic(
        title: Text(
          device.deviceName?.trim().isNotEmpty == true ? device.deviceName! : device.deviceId.split("|").first,
        ),
        subtitle: Text(
          [
            if (device.deviceName?.trim().isEmpty == false) 'ID: ${device.deviceId.split("|").first}',
            'Last seen: ${_formatDate(device.lastSeenAt)}',
          ].join('\n'),
        ).small,
        trailing: device.isRevoked
            ? Text('Revoked at\n${_formatDate(device.revokedAt)}').small
            : Button.secondary(
                onPressed: () => _revokeDevice(device),
                child: const Text('Revoke'),
              ),
      ),
    );
  }

  Future<void> _loadSessionState() async {
    final session = core.supabase.auth.currentSession;
    if (session == null) {
      if (!mounted) return;
      setState(() {
        _devicesByPlatform = const {};
        _deviceLimitError = null;
        _statusMessage = null;
      });
      return;
    }

    await _loadCurrentDeviceIdentity();
    await _reloadDevicesAndEntitlements();
  }

  Future<void> _loadCurrentDeviceIdentity() async {
    final platform = await _iapManager.deviceManagement.currentPlatform();
    final deviceId = platform == null ? null : await _iapManager.deviceManagement.currentDeviceId();
    String? version;
    try {
      final package = await PackageInfo.fromPlatform();
      version = package.version;
    } catch (_) {
      version = null;
    }
    if (!mounted) return;
    setState(() {
      _devicePlatform = platform;
      _deviceId = deviceId;
      _appVersion = version;
    });
  }

  Future<void> _reloadDevicesAndEntitlements() async {
    if (!mounted) return;
    setState(() {
      _isLoadingDevices = true;
      _statusMessage = null;
    });
    try {
      await _iapManager.entitlements.refresh(force: true);
      final devices = await _iapManager.deviceManagement.getMyDevices();
      final grouped = <String, List<UserDevice>>{};
      for (final device in devices) {
        grouped.putIfAbsent(device.platform, () => <UserDevice>[]).add(device);
      }
      if (!mounted) return;
      setState(() {
        _devicesByPlatform = grouped;
        _deviceLimitError = _iapManager.entitlements.lastDeviceLimitError;
      });
    } on DeviceLimitReachedError catch (error) {
      if (!mounted) return;
      setState(() {
        _deviceLimitError = error;
        _statusMessage = error.toString();
      });
    } catch (error) {
      recordError(error, null, context: 'reloadDevicesAndEntitlements');
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to load devices: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDevices = false;
        });
      }
    }
  }

  Future<void> _registerCurrentDevice() async {
    setState(() {
      _isRegisteringDevice = true;
      _statusMessage = null;
    });
    try {
      final result = await _iapManager.deviceManagement.registerCurrentDevice(
        deviceName: _suggestDeviceName(),
        appVersion: _appVersion,
      );
      await _reloadDevicesAndEntitlements();
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Device registered (${result.platform} ${result.activeDeviceCount}/${result.maxDevices}).';
      });
    } on DeviceLimitReachedError catch (error) {
      if (!mounted) return;
      setState(() {
        _deviceLimitError = error;
        _statusMessage = error.toString();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Could not register device: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRegisteringDevice = false;
        });
      }
    }
  }

  Future<void> _refreshEntitlements() async {
    setState(() {
      _isRefreshingEntitlements = true;
      _statusMessage = null;
    });
    try {
      await _iapManager.entitlements.refresh(force: true);
      await _reloadDevicesAndEntitlements();
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Entitlements refreshed.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to refresh entitlements: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingEntitlements = false;
        });
      }
    }
  }

  Future<void> _buySubscription() async {
    setState(() {
      _isPurchasingSubscription = true;
      _statusMessage = null;
    });
    try {
      await _iapManager.purchaseSubscription(context);
      await _iapManager.entitlements.refresh(force: true);
      await _reloadDevicesAndEntitlements();
      if (!mounted) return;
      setState(() {
        _statusMessage = _iapManager.isPremiumEnabled
            ? 'Subscription activated.'
            : 'Purchase completed. Entitlement sync may take a moment.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to start subscription purchase: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasingSubscription = false;
        });
      }
    }
  }

  Future<void> _restoreOrSyncWindowsSubscription() async {
    setState(() {
      _isSyncingWindowsSubscription = true;
      _statusMessage = null;
    });
    try {
      await _iapManager.restorePurchases();
      await _reloadDevicesAndEntitlements();
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Windows subscription synced.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to restore/sync subscription: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingWindowsSubscription = false;
        });
      }
    }
  }

  Future<void> _revokeDevice(UserDevice device) async {
    setState(() {
      _statusMessage = null;
    });
    try {
      await _iapManager.deviceManagement.revokeDevice(
        platform: device.platform,
        deviceId: device.deviceId,
      );
      await _reloadDevicesAndEntitlements();
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Device revoked: ${device.deviceId}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to revoke device: $error';
      });
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    return DateFormat.yMMMd().add_Hm().format(value.toLocal());
  }

  String _suggestDeviceName() {
    final platform = _devicePlatform ?? (kIsWeb ? 'web' : Platform.operatingSystem);
    return 'BikeControl ${platform.toUpperCase()}';
  }

  Future<AuthResponse?> _nativeGoogleSignIn() async {
    if (Platform.isAndroid || Platform.isIOS) {
      const webClientId = '709945926587-bgk7j9qc86t7nuemu100ngvl9c7irv9k.apps.googleusercontent.com';
      const iosClientId = '709945926587-0iierajthibf4vhqf85fc7bbpgbdgua2.apps.googleusercontent.com';
      final scopes = ['email'];
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId: webClientId,
        clientId: iosClientId,
      );
      GoogleSignInAccount? googleUser = await googleSignIn.attemptLightweightAuthentication(reportAllExceptions: true);
      googleUser ??= await googleSignIn.authenticate();

      final authorization =
          await googleUser.authorizationClient.authorizationForScopes(scopes) ??
          await googleUser.authorizationClient.authorizeScopes(scopes);
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw AuthException('No ID Token found.');
      }
      final response = await core.supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization.accessToken,
      );
      return response;
    } else {
      await core.supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'bikecontrol://login/',
        authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
      return null;
    }
  }

  Future<AuthResponse?> _signInWithApple() async {
    if (Platform.isIOS || Platform.isMacOS) {
      final rawNonce = core.supabase.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
        nonce: hashedNonce,
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException('Could not find ID Token from generated credential.');
      }
      final authResponse = await core.supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      return authResponse;
    } else {
      await core.supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: kIsWeb ? null : 'bikecontrol://login/',
        authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
      return null;
    }
  }
}
