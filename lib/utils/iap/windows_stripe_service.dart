import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Exception thrown when Stripe operations fail
class StripeException implements Exception {
  final String message;
  final int? statusCode;

  StripeException(this.message, {this.statusCode});

  @override
  String toString() => 'StripeException: $message (status: $statusCode)';
}

/// Service for handling Stripe Checkout and Portal on Windows
/// Requires user to be logged in with a valid Supabase session
class WindowsStripeService {
  static const String _checkoutFunction = 'stripe-checkout';
  static const String _portalFunction = 'stripe-portal';

  final SupabaseClient _supabase;

  WindowsStripeService(this._supabase);

  /// Check if the user is logged in
  bool get isLoggedIn => _supabase.auth.currentSession != null;

  /// Get the current session
  Session? get _session => _supabase.auth.currentSession;

  /// Start a Stripe Checkout session for purchase
  ///
  /// [priceId] must be 'monthly', 'yearly', or 'full' (one-time purchase)
  /// [successUrl] optional, defaults to app origin + '/success'
  /// [cancelUrl] optional, defaults to app origin + '/cancel'
  ///
  /// Throws [StripeException] if the user is not logged in or the request fails
  Future<void> startCheckout({
    required String priceId,
    required String? storeId,
    String? successUrl,
    String? cancelUrl,
  }) async {
    if (!isLoggedIn) {
      throw StripeException('Authentication required. Please log in to purchase a subscription.');
    }

    if (priceId != 'monthly' && priceId != 'yearly' && priceId != 'full') {
      throw StripeException('Invalid price_id. Must be "monthly", "yearly", or "full"');
    }

    try {
      final body = <String, dynamic>{
        'price_id': priceId,
      };

      if (storeId != null) {
        body['store_id'] = storeId;
      }
      if (successUrl != null) {
        body['success_url'] = successUrl;
      }
      if (cancelUrl != null) {
        body['cancel_url'] = cancelUrl;
      }

      final response = await _supabase.functions.invoke(
        _checkoutFunction,
        method: HttpMethod.post,
        headers: {
          'Authorization': 'Bearer ${_session!.accessToken}',
        },
        body: body,
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw StripeException('Invalid response format from server');
      }

      final url = data['url'] as String?;
      if (url == null || url.isEmpty) {
        throw StripeException('No checkout URL returned from server');
      }

      // Launch the Stripe Checkout URL
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StripeException('Could not launch checkout URL');
      }
    } on FunctionException catch (e) {
      final status = e.status;
      final details = e.details;

      String errorMessage = 'Failed to start checkout';

      if (details is Map<String, dynamic>) {
        errorMessage = details['error'] as String? ?? errorMessage;
      }

      if (status == 400) {
        throw StripeException(errorMessage, statusCode: status);
      } else if (status == 401) {
        throw StripeException('Your session has expired. Please log in again.', statusCode: status);
      } else if (status == 500) {
        throw StripeException('Server error: $errorMessage', statusCode: status);
      }

      throw StripeException(errorMessage, statusCode: status);
    } catch (e) {
      if (e is StripeException) rethrow;
      throw StripeException('Failed to start checkout: $e');
    }
  }

  /// Open the Stripe Billing Portal for managing subscriptions
  ///
  /// [returnUrl] optional, URL to return to after leaving the portal
  ///
  /// Throws [StripeException] if the user is not logged in, has no Stripe customer,
  /// or the request fails
  Future<void> openPortal({String? returnUrl}) async {
    if (!isLoggedIn) {
      throw StripeException('Authentication required. Please log in to manage your subscription.');
    }

    try {
      final body = <String, dynamic>{};
      if (returnUrl != null) {
        body['return_url'] = returnUrl;
      }

      final response = await _supabase.functions.invoke(
        _portalFunction,
        method: HttpMethod.post,
        headers: {
          'Authorization': 'Bearer ${_session!.accessToken}',
        },
        body: body.isNotEmpty ? body : null,
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw StripeException('Invalid response format from server');
      }

      final url = data['url'] as String?;
      if (url == null || url.isEmpty) {
        throw StripeException('No portal URL returned from server');
      }

      // Launch the Stripe Portal URL
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StripeException('Could not launch portal URL');
      }
    } on FunctionException catch (e) {
      final status = e.status;
      final details = e.details;

      String errorMessage = 'Failed to open billing portal';

      if (details is Map<String, dynamic>) {
        errorMessage = details['error'] as String? ?? errorMessage;
      }

      if (status == 401) {
        throw StripeException('Your session has expired. Please log in again.', statusCode: status);
      } else if (status == 404) {
        // Special case: user has never completed checkout
        throw StripeException(
          'No subscription found. Please purchase a subscription first.',
          statusCode: status,
        );
      } else if (status == 500) {
        throw StripeException('Server error: $errorMessage', statusCode: status);
      }

      throw StripeException(errorMessage, statusCode: status);
    } catch (e) {
      if (e is StripeException) rethrow;
      throw StripeException('Failed to open billing portal: $e');
    }
  }

  /// Check if the user has a Stripe customer record (has completed checkout)
  /// This is useful for determining whether to show the "Manage Subscription" button
  Future<bool> hasStripeCustomer() async {
    if (!isLoggedIn) return false;

    try {
      await _supabase.functions.invoke(
        _portalFunction,
        method: HttpMethod.post,
        headers: {
          'Authorization': 'Bearer ${_session!.accessToken}',
        },
      );
      return true;
    } on FunctionException catch (e) {
      if (e.status == 404) {
        return false;
      }
      // For other errors, assume they might have a customer
      // This is a best-effort check
      return true;
    } catch (e) {
      return true;
    }
  }
}
