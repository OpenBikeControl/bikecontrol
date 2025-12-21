import 'dart:convert';
import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:http/http.dart' as http;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Widget to display IAP status and allow purchases
class IAPStatusWidget extends StatefulWidget {
  final bool small;
  const IAPStatusWidget({super.key, required this.small});

  @override
  State<IAPStatusWidget> createState() => _IAPStatusWidgetState();
}

final _normalDate = DateTime(2026, 1, 15, 0, 0, 0, 0, 0);

class _IAPStatusWidgetState extends State<IAPStatusWidget> {
  bool _isPurchasing = false;
  bool _isSmall = false;
  bool? _alreadyBoughtQuestion = null;

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

    return Button(
      onPressed: _isSmall
          ? () {
              setState(() {
                _isSmall = false;
              });
            }
          : () {
              if (Platform.isAndroid) {
                if (_alreadyBoughtQuestion == false) {
                  _handlePurchase();
                }
              } else {
                _handlePurchase();
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPurchased) ...[
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
                          : Text(AppLocalizations.of(context).trialPeriodDescription(IAPManager.dailyCommandLimit)),
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
                              ? context.i18n.commandsRemainingToday(commandsRemaining, IAPManager.dailyCommandLimit)
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
                if (!IAPManager.instance.isPurchased.value && !_isSmall) ...[
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
                                OutlineButton(
                                  child: Text(AppLocalizations.of(context).yes),
                                  onPressed: () {
                                    setState(() {
                                      _alreadyBoughtQuestion = true;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                OutlineButton(
                                  child: Text(AppLocalizations.of(context).no),
                                  onPressed: () {
                                    setState(() {
                                      _alreadyBoughtQuestion = false;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ] else if (_alreadyBoughtQuestion == true) ...[
                            Text(
                              AppLocalizations.of(context).alreadyBoughtTheApp,
                            ).small,
                            Form(
                              onSubmit: (context, values) async {
                                String purchaseId = _purchaseIdField[values]!;
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
                                  await IAPManager.instance.redeem();
                                  buildToast(context, title: 'Success', subtitle: 'Purchase redeemed successfully!');
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
                                              onPressed: () {
                                                launchUrlString(
                                                  'mailto:jonas@bikecontrol.app?subject=Bike%20Control%20Purchase%20Redemption%20Help',
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
                          ] else if (_alreadyBoughtQuestion == false) ...[
                            PrimaryButton(
                              onPressed: _isPurchasing ? null : _handlePurchase,
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
                          ],
                        ],
                      ),
                    )
                  else ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 42.0),
                      child: PrimaryButton(
                        onPressed: _isPurchasing ? null : _handlePurchase,
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

  Future<void> _handlePurchase() async {
    setState(() {
      _isPurchasing = true;
    });

    try {
      await IAPManager.instance.purchaseFullVersion();
    } catch (e) {
      if (mounted) {
        buildToast(
          context,
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

  Future<bool> _redeemPurchase({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String purchaseId,
  }) async {
    final uri = Uri.parse(
      '$supabaseUrl/functions/v1/redeem-purchase',
    );

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $supabaseAnonKey',
      },
      body: jsonEncode({
        'purchaseId': purchaseId,
      }),
    );

    if (response.statusCode != 200) {
      return false;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    return decoded['success'] == true;
  }
}
