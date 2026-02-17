import 'dart:convert';
import 'dart:io';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Widget to display IAP status and allow purchases
class IAPStatusWidget extends StatefulWidget {
  final bool small;
  const IAPStatusWidget({super.key, required this.small});

  @override
  State<IAPStatusWidget> createState() => _IAPStatusWidgetState();
}

final _normalDate = DateTime(2026, 2, 15, 0, 0, 0, 0, 0);
final _iapDate = DateTime(2025, 12, 21, 0, 0, 0, 0, 0);

enum AlreadyBoughtOption { fullPurchase, iap, no }

class _IAPStatusWidgetState extends State<IAPStatusWidget> {
  bool _isPurchasing = false;
  bool _isSmall = false;
  AlreadyBoughtOption? _alreadyBoughtQuestion;

  final _purchaseIdField = const TextFieldKey(#purchaseId);

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isSmall = widget.small;
  }

  @override
  void didUpdateWidget(covariant IAPStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.small != widget.small) {
      setState(() {
        _isSmall = widget.small;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final iapManager = IAPManager.instance;
    final isTrialExpired = iapManager.isTrialExpired;
    if (isTrialExpired) {
      _isSmall = false;
    }
    final trialDaysRemaining = iapManager.trialDaysRemaining;
    final commandsRemaining = iapManager.commandsRemainingToday;
    final dailyCommandCount = iapManager.dailyCommandCount;

    return kIsWeb
        ? SizedBox()
        : Button(
            onPressed: _isSmall
                ? () {
                    setState(() {
                      _isSmall = false;
                    });
                  }
                : () {
                    if (Platform.isAndroid) {
                      if (_alreadyBoughtQuestion == AlreadyBoughtOption.iap) {
                        _handlePurchase(context);
                      }
                    } else {
                      _handlePurchase(context);
                    }
                  },
            style: ButtonStyle.card().withBackgroundColor(
              color: Theme.of(context).colorScheme.muted,
              hoverColor: Theme.of(context).colorScheme.primaryForeground,
            ),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 700),
              width: double.infinity,
              child: ValueListenableBuilder(
                valueListenable: IAPManager.instance.isPurchased,
                builder: (context, isPurchased, child) {
                  final hasPremiumAccess = iapManager.isPremiumEnabled || isPurchased;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasPremiumAccess) ...[
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context).fullVersion,
                              style: TextStyle(
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ] else if (!isTrialExpired) ...[
                        if (!Platform.isAndroid)
                          Basic(
                            leadingAlignment: Alignment.centerLeft,
                            leading: Icon(Icons.access_time, color: Colors.blue),
                            title: Text(AppLocalizations.of(context).trialPeriodActive(trialDaysRemaining)),
                            subtitle: _isSmall
                                ? null
                                : Text(
                                    AppLocalizations.of(context).trialPeriodDescription(IAPManager.dailyCommandLimit),
                                  ),
                            trailing: _isSmall ? Icon(Icons.expand_more) : null,
                          )
                        else
                          Basic(
                            leadingAlignment: Alignment.centerLeft,
                            leading: Icon(Icons.lock),
                            title: Text(AppLocalizations.of(context).trialPeriodActive(trialDaysRemaining)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 6,
                              children: [
                                SizedBox(),
                                Text(
                                  commandsRemaining >= 0
                                      ? context.i18n
                                            .commandsRemainingToday(commandsRemaining, IAPManager.dailyCommandLimit)
                                            .replaceAll(
                                              '${IAPManager.dailyCommandLimit}/${IAPManager.dailyCommandLimit}',
                                              IAPManager.dailyCommandLimit.toString(),
                                            )
                                      : AppLocalizations.of(
                                          context,
                                        ).dailyLimitReached(dailyCommandCount, IAPManager.dailyCommandLimit),
                                ).small,
                                if (commandsRemaining >= 0 && dailyCommandCount > 0)
                                  SizedBox(
                                    width: 300,
                                    child: LinearProgressIndicator(
                                      value: dailyCommandCount.toDouble() / IAPManager.dailyCommandLimit.toDouble(),
                                      backgroundColor: Colors.gray[300],
                                      color: commandsRemaining > 0 ? Colors.orange : Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: _isSmall ? Icon(Icons.expand_more) : null,
                            trailingAlignment: Alignment.centerRight,
                          ),
                      ] else ...[
                        Basic(
                          leadingAlignment: Alignment.centerLeft,
                          leading: Icon(Icons.lock),
                          title: Text(AppLocalizations.of(context).trialExpired(IAPManager.dailyCommandLimit)),
                          trailing: _isSmall ? Icon(Icons.expand_more) : null,
                          trailingAlignment: Alignment.centerRight,
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 6,
                            children: [
                              SizedBox(),
                              Text(
                                commandsRemaining >= 0
                                    ? context.i18n.commandsRemainingToday(
                                        commandsRemaining,
                                        IAPManager.dailyCommandLimit,
                                      )
                                    : AppLocalizations.of(
                                        context,
                                      ).dailyLimitReached(dailyCommandCount, IAPManager.dailyCommandLimit),
                              ).small,
                              if (commandsRemaining >= 0)
                                SizedBox(
                                  width: 300,
                                  child: LinearProgressIndicator(
                                    value: dailyCommandCount.toDouble() / IAPManager.dailyCommandLimit.toDouble(),
                                    backgroundColor: Colors.gray[300],
                                    color: commandsRemaining > 0 ? Colors.orange : Colors.red,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (!hasPremiumAccess && !_isSmall) ...[
                        if (Platform.isAndroid)
                          Padding(
                            padding: const EdgeInsets.only(left: 42.0, top: 16.0),
                            child: Column(
                              spacing: 8,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Divider(),
                                const SizedBox(),
                                if (_alreadyBoughtQuestion == null && DateTime.now().isBefore(_normalDate)) ...[
                                  Text(AppLocalizations.of(context).alreadyBoughtTheAppPreviously).small,
                                  Row(
                                    children: [
                                      Builder(
                                        builder: (context) {
                                          return OutlineButton(
                                            child: Text(AppLocalizations.of(context).yes),
                                            onPressed: () {
                                              showDropdown(
                                                context: context,
                                                builder: (c) => DropdownMenu(
                                                  children: [
                                                    MenuButton(
                                                      child: Text(
                                                        AppLocalizations.of(
                                                          context,
                                                        ).beforeDate(DateFormat.yMMMd().format(_iapDate)),
                                                      ),
                                                      onPressed: (c) {
                                                        setState(() {
                                                          _alreadyBoughtQuestion = AlreadyBoughtOption.fullPurchase;
                                                        });
                                                      },
                                                    ),
                                                    MenuButton(
                                                      child: Text(
                                                        AppLocalizations.of(
                                                          context,
                                                        ).afterDate(DateFormat.yMMMd().format(_iapDate)),
                                                      ),
                                                      onPressed: (c) {
                                                        setState(() {
                                                          _alreadyBoughtQuestion = AlreadyBoughtOption.iap;
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      OutlineButton(
                                        child: Text(AppLocalizations.of(context).no),
                                        onPressed: () {
                                          setState(() {
                                            _alreadyBoughtQuestion = AlreadyBoughtOption.no;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ] else if (_alreadyBoughtQuestion == AlreadyBoughtOption.fullPurchase) ...[
                                  Text(
                                    AppLocalizations.of(context).alreadyBoughtTheApp,
                                  ).small,
                                  Form(
                                    onSubmit: (context, values) async {
                                      String purchaseId = _purchaseIdField[values]!.trim();
                                      setState(() {
                                        _isLoading = true;
                                      });
                                      final redeemed = await _redeemPurchase(
                                        purchaseId: purchaseId,
                                        supabaseAnonKey:
                                            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBpa3JjeXlub3Zkdm9ncmxkZm53Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYwNjMyMzksImV4cCI6MjA4MTYzOTIzOX0.oxJovYahRiZ6XvCVR-qww6OQ5jY6cjOyUiFHJsW9MVk',
                                        supabaseUrl: 'https://pikrcyynovdvogrldfnw.supabase.co',
                                      );
                                      if (redeemed) {
                                        await IAPManager.instance.redeem(purchaseId);
                                        buildToast(
                                          title: 'Success',
                                          subtitle: 'Purchase redeemed successfully!',
                                        );
                                        setState(() {
                                          _isLoading = false;
                                        });
                                      } else {
                                        setState(() {
                                          _isLoading = false;
                                        });
                                        if (mounted) {
                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              return AlertDialog(
                                                title: Text('Error'),
                                                content: Text(
                                                  'Failed to redeem purchase. Please check your Purchase ID and try again or contact me directly. Sorry about that!',
                                                ),
                                                actions: [
                                                  OutlineButton(
                                                    child: Text(context.i18n.getSupport),
                                                    onPressed: () async {
                                                      final appUserId = await Purchases.appUserID;
                                                      launchUrlString(
                                                        'mailto:jonas@bikecontrol.app?subject=Bike%20Control%20Purchase%20Redemption%20Help%20for%20$appUserId',
                                                      );
                                                    },
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.of(context).pop();
                                                    },
                                                    child: Text('OK'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        }
                                      }
                                    },
                                    child: Row(
                                      spacing: 8,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: FormField(
                                            showErrors: {
                                              FormValidationMode.submitted,
                                              FormValidationMode.changed,
                                            },
                                            key: _purchaseIdField,
                                            label: Text('Purchase ID'),
                                            validator: RegexValidator(
                                              RegExp(r'GPA.[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{5}'),
                                              message: 'Please enter a valid Purchase ID.',
                                            ),
                                            child: TextField(
                                              placeholder: Text('GPA.****-****-****-*****'),
                                            ),
                                          ),
                                        ),
                                        FormErrorBuilder(
                                          builder: (context, errors, child) {
                                            return PrimaryButton(
                                              onPressed: errors.isEmpty ? () => context.submitForm() : null,
                                              child: _isLoading
                                                  ? SmallProgressIndicator(color: Colors.black)
                                                  : const Text('Submit'),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else if (_alreadyBoughtQuestion == AlreadyBoughtOption.no ||
                                    DateTime.now().isAfter(_normalDate)) ...[
                                  PrimaryButton(
                                    onPressed: _isPurchasing ? null : () => _handlePurchase(context),
                                    leading: Icon(Icons.star),
                                    child: _isPurchasing
                                        ? Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SmallProgressIndicator(),
                                              const SizedBox(width: 8),
                                              Text('Processing...'),
                                            ],
                                          )
                                        : Text(AppLocalizations.of(context).unlockFullVersion),
                                  ),
                                  Text(AppLocalizations.of(context).fullVersionDescription).xSmall,
                                ] else if (_alreadyBoughtQuestion == AlreadyBoughtOption.iap) ...[
                                  PrimaryButton(
                                    onPressed: _isPurchasing ? null : () => _handlePurchase(context),
                                    leading: Icon(Icons.star),
                                    child: _isPurchasing
                                        ? Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SmallProgressIndicator(),
                                              const SizedBox(width: 8),
                                              Text('Processing...'),
                                            ],
                                          )
                                        : Text(AppLocalizations.of(context).unlockFullVersion),
                                  ),
                                  Text(
                                    AppLocalizations.of(context).restorePurchaseInfo,
                                  ).xSmall,
                                  OutlineButton(
                                    child: Text(context.i18n.getSupport),
                                    onPressed: () async {
                                      final appUserId = await Purchases.appUserID;
                                      launchUrlString(
                                        'mailto:jonas@bikecontrol.app?subject=Bike%20Control%20Purchase%20Redemption%20Help%20for%20$appUserId',
                                      );
                                    },
                                  ),
                                ],
                                if (IAPManager.instance.isUsingRevenueCat)
                                  _buildRestoreAction(
                                    label: 'Restore Purchases',
                                    leftPadding: 0,
                                  ),
                              ],
                            ),
                          )
                        else ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.only(left: 42.0),
                            child: Builder(
                              builder: (context) {
                                return PrimaryButton(
                                  onPressed: _isPurchasing ? null : () => _handlePurchase(context),
                                  leading: Icon(Icons.star),
                                  child: _isPurchasing
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SmallProgressIndicator(),
                                            const SizedBox(width: 8),
                                            Text('Processing...'),
                                          ],
                                        )
                                      : Text(AppLocalizations.of(context).unlockFullVersion),
                                );
                              },
                            ),
                          ),
                          if (IAPManager.instance.isUsingRevenueCat)
                            _buildRestoreAction(
                              label: 'Restore Purchases',
                              leftPadding: 42.0,
                            ),
                          if (Platform.isWindows)
                            _buildRestoreAction(
                              label: 'Restore / Sync subscription',
                              leftPadding: 42.0,
                            ),
                          Padding(
                            padding: const EdgeInsets.only(left: 42.0, top: 8.0),
                            child: Text(AppLocalizations.of(context).fullVersionDescription).xSmall,
                          ),
                        ],
                      ],
                    ],
                  );
                },
              ),
            ),
          );
  }

  Future<void> _handlePurchase(BuildContext context) async {
    setState(() {
      _isPurchasing = true;
    });

    try {
      // Use RevenueCat paywall if available, otherwise fall back to legacy
      await IAPManager.instance.purchaseFullVersion(context);
    } catch (e) {
      if (mounted) {
        buildToast(
          title: 'Error',
          subtitle: 'An error occurred: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  Widget _buildRestoreAction({
    required String label,
    required double leftPadding,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: leftPadding, top: 8.0, bottom: 8),
      child: LoadingWidget(
        futureCallback: () async {
          await IAPManager.instance.restorePurchases();
          await IAPManager.instance.refreshEntitlementsOnResume();
        },
        renderChild: (isLoading, tap) => LinkButton(
          onPressed: tap,
          child: isLoading ? SmallProgressIndicator() : Text(label).small,
        ),
      ),
    );
  }

  Future<bool> _redeemPurchase({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String purchaseId,
  }) async {
    final uri = Uri.parse('$supabaseUrl/functions/v1/redeem-purchase');

    final appUserId = await Purchases.appUserID;

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $supabaseAnonKey',
      },
      body: jsonEncode({
        'purchaseId': purchaseId,
        'userId': appUserId,
      }),
    );

    if (response.statusCode != 200) {
      return false;
    }

    final body = response.body;
    final decoded = jsonDecode(body) as Map<String, dynamic>;

    core.connection.signalNotification(LogNotification(body));

    return decoded['success'] == true;
  }
}
