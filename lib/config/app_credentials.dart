// This file stores sensitive API credentials that should not be directly in code
// Note: In a production app, consider using secure storage or environment variables

class AppCredentials {
  // Khalti payment credentials
  static const String khaltiPublicKey =
      "live_public_key_9aa9d33aadef4e71b1ab76236124cf9b";
  static const String khaltiSecretKey =
      "live_secret_key_a54ea26e6566436b8a8d8361a981ffd6";

  static const String khaltiTestPublicKey = '145bb5a3cc404e89b017670aa2e48587';
  static const String khaltiTestSecretKey = '704f90524574410386302d074ed60d6f';

  // Stripe payment credentials (publishable key only — secret stays on server)
  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue:
        'pk_live_51TEpJwDUO9Tgj01i4brr2P9ITGGcA6tmgRavoZA82gaihCRT8nvi6GtBmUdvmSiFXdu4TKquZnpXBSpexwLXpsJZ00NIPy1KKN',
  );
  static const String stripeMerchantId = 'merchant.com.baakhapaa';

  static const bool isProduction = true;
}
