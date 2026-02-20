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
      spacing: 32,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.account_circle,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Column(
          spacing: 8,
          children: [
            Text(
              'Welcome',
            ).large,
            Text(
              'Sign in to sync your subscription and manage devices',
            ).small.muted,
          ],
        ),
        Card(
          filled: true,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              spacing: 16,
              mainAxisSize: MainAxisSize.min,
              children: [
                SignInButton(
                  Buttons.google,
                  onPressed: _nativeGoogleSignIn,
                ),
                SignInButton(
                  Buttons.apple,
                  onPressed: _signInWithApple,
                ),
              ],
            ),
          ),
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
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Column(
            spacing: 16,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isPremiumEnabled
                          ? Colors.green.withAlpha(30)
                          : hasActiveSubscription
                          ? Colors.orange.withAlpha(30)
                          : Colors.red.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPremiumEnabled
                          ? Icons.check_circle
                          : hasActiveSubscription
                          ? Icons.warning
                          : Icons.cancel,
                      size: 28,
                      color: isPremiumEnabled
                          ? Colors.green
                          : hasActiveSubscription
                          ? Colors.orange
                          : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.user.email ?? session.user.id,
                        ).small.bold,
                        const SizedBox(height: 4),
                        if (isPremiumEnabled)
                          PrimaryBadge(
                            child: Text('Subscription active'),
                          )
                        else if (hasActiveSubscription)
                          DestructiveBadge(
                            child: Text('Device not registered'),
                          )
                        else
                          DestructiveBadge(
                            child: Text('Subscription inactive'),
                          ),
                      ],
                    ),
                  ),
                  Button.secondary(
                    child: const Text('Logout'),
                    onPressed: () async {
                      await core.supabase.auth.signOut();
                    },
                  ),
                ],
              ),
              Divider(),
              Text(
                'Premium features are enabled when this account has an active subscription.',
              ).small.muted,
              if (hasActiveSubscription && !isRegisteredDevice)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    spacing: 8,
                    children: [
                      Icon(
                        Icons.info,
                        size: 16,
                        color: Colors.orange,
                      ),
                      Expanded(
                        child: Text(
                          'This device is not registered. Register it to enable premium features.',
                          style: TextStyle(color: Colors.orange),
                        ).small,
                      ),
                    ],
                  ),
                ),
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
                ],
              ),
            ],
          ),
        ),
        if (hasActiveSubscription)
          Card(
            child: Column(
              spacing: 16,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.devices,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Current Device',
                    ).small.bold,
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.muted.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    spacing: 8,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Platform', _devicePlatform ?? '-'),
                      _buildInfoRow('Device ID', _deviceId ?? '-'),
                      _buildInfoRow('App Version', _appVersion ?? '-'),
                    ],
                  ),
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
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Register device'),
                                ],
                              ),
                      ),
                    Button.secondary(
                      onPressed: _isRefreshingEntitlements ? null : _refreshEntitlements,
                      child: _isRefreshingEntitlements
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator())
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                const Text('Refresh'),
                              ],
                            ),
                    ),
                    if (Platform.isWindows)
                      Button.secondary(
                        onPressed: _isSyncingWindowsSubscription ? null : _restoreOrSyncWindowsSubscription,
                        child: _isSyncingWindowsSubscription
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator())
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.computer,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Sync Windows'),
                                ],
                              ),
                      ),
                  ],
                ),
                if (_statusMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      spacing: 8,
                      children: [
                        Icon(
                          Icons.info,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                          ).small,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (hasActiveSubscription && _deviceLimitError != null) _buildDeviceLimitCard(_deviceLimitError!),
        if (hasActiveSubscription)
          Card(
            child: Column(
              spacing: 16,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.devices,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Registered Devices',
                    ).small.bold,
                    const Spacer(),
                    if (_isLoadingDevices)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
                if (!_isLoadingDevices && _devicesByPlatform.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.muted.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        spacing: 8,
                        children: [
                          Icon(
                            Icons.devices,
                            size: 32,
                            color: Theme.of(context).colorScheme.mutedForeground,
                          ),
                          Text(
                            'No devices registered',
                          ).small.muted,
                        ],
                      ),
                    ),
                  )
                else if (!_isLoadingDevices)
                  ..._devicesByPlatform.entries.map((entry) => _buildPlatformDevices(entry.key, entry.value)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      spacing: 8,
      children: [
        Text(
          '$label: ',
        ).small.muted,
        Expanded(
          child: Text(
            value,
          ).small,
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
