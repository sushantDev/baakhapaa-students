# Stripe Payment Gateway Integration Plan

**Goal:** Enable international subscription & product purchases in USD alongside existing Khalti (NPR) payments.  
**Last Updated:** March 25, 2026  
**Status:** ✅ Phase 1–3 Complete · Phase 4 Pending

> For full technical detail see [INTERNATIONAL_ECOMMERCE_TECHNICAL_REFERENCE.md](INTERNATIONAL_ECOMMERCE_TECHNICAL_REFERENCE.md)  
> For the user-facing flow see [INTERNATIONAL_SHOPPING_USER_GUIDE.md](INTERNATIONAL_SHOPPING_USER_GUIDE.md)

---

## 1. Architecture Overview

```
Current:  Flutter → Khalti SDK (client-side) → Laravel saves Payment record
Stripe:   Flutter → Laravel (create PaymentIntent) → Stripe SDK (client) → Stripe webhook → Laravel confirms
```

Stripe enforces server-side payment creation. All secret keys stay on the backend — never in the Flutter app.

**Implemented flow (product purchases with international shipping):**

```
Flutter cart_screen
  1. DeliveryProvider.fetchAddresses()  → GET /api/shipping/addresses
  2. ShippingAddressScreen (if needed)  → POST /api/shipping/addresses
  3. DeliveryProvider.loadProviders()   → GET /api/shipping/providers?country_code=XX&weight_kg=X
  4. Provider bottom sheet selection
  5. CurrencyProvider.nprToCents(total) → GET /api/currency/rate (cached 6h)
  6. StripeService.createPaymentIntent  → POST /api/stripe/create-payment-intent
       (server recalculates price + shipping from DB — client amount validated)
  7. Stripe.presentPaymentSheet()       → Stripe SDK (PCI-compliant native UI)
  8. StripeService.confirmPaymentOnBackend → POST /api/stripe/confirm-payment
       (server re-verifies status=succeeded on Stripe servers — idempotent)
  9. Order created with shipping fields, initial tracking event persisted
```

---

## 2. Backend Changes (Laravel)

### 2.1 Install Package

```bash
composer require stripe/stripe-php
```

### 2.2 Environment Variables

```env
STRIPE_PUBLISHABLE_KEY=pk_live_xxx
STRIPE_SECRET_KEY=sk_live_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx
STRIPE_CURRENCY=usd
```

### 2.3 Config File — `config/stripe.php`

```php
return [
    'publishable_key' => env('STRIPE_PUBLISHABLE_KEY'),
    'secret_key' => env('STRIPE_SECRET_KEY'),
    'webhook_secret' => env('STRIPE_WEBHOOK_SECRET'),
    'currency' => env('STRIPE_CURRENCY', 'usd'),
];
```

### 2.4 New Database Migrations ✅ Done

> **7 migrations were created** beyond the original plan, covering the full international shipping + currency conversion system.

#### Original Stripe migrations ✅

| Migration                                                                                              | Status  |
| ------------------------------------------------------------------------------------------------------ | ------- |
| `alter_payments_add_stripe_fields` — adds `stripe_payment_intent_id`, `stripe_customer_id`, `currency` | ✅ Done |
| `alter_orders_add_currency` — adds `currency`, `total_usd`                                             | ✅ Done |
| `create_stripe_customers` — user↔Stripe customer mapping                                               | ✅ Done |

#### Extended: International shipping & currency migrations ✅

| Migration file                                               | Table / Change                                              |
| ------------------------------------------------------------ | ----------------------------------------------------------- |
| `2026_03_25_160001_create_currency_rates_table`              | Stores live NPR↔USD rate                                    |
| `2026_03_25_160002_create_shipping_providers_table`          | DHL, FedEx, Nepal EMS, Aramex                               |
| `2026_03_25_160003_create_shipping_zones_table`              | 7 global regions with country code arrays                   |
| `2026_03_25_160004_create_shipping_rates_table`              | base_cost_usd + per_kg_usd per (provider, zone)             |
| `2026_03_25_160005_create_shipping_addresses_table`          | User-saved delivery addresses                               |
| `2026_03_25_160006_add_shipping_fields_to_orders_table`      | shipping_address_id, tracking_number, shipping_status, etc. |
| `2026_03_25_160007_add_weight_to_products_…_tracking_events` | product.weight_kg + order_tracking_events table             |

### 2.5 New/Modified Controllers ✅ Done

#### `app/Http/Controllers/api/StripeController.php` ✅

```
POST /api/stripe/create-payment-intent   ← server validates product prices from DB
POST /api/stripe/confirm-payment         ← verifies PI status on Stripe before fulfilling
GET  /api/stripe/payment-methods         ← saved cards
POST /api/stripe/setup-intent            ← for saving cards
DELETE /api/stripe/payment-methods/{id}  ← detach saved method
POST /api/stripe/webhook                 ← no auth; Stripe-Signature verified
```

**Key improvement over original plan:** `createPaymentIntent` for products now recalculates the total server-side from `product.price_usd` (or auto-converts NPR price), then adds shipping cost via `ShippingService`. Client-sent amount is validated to within 50 cents. This prevents price manipulation.

#### `app/Http/Controllers/api/CurrencyController.php` ✅ (new — not in original plan)

```
GET  /api/currency/rate             (public) → live rate + metadata
POST /api/currency/rate/refresh     (admin)  → force refresh from open.er-api.com
POST /api/currency/rate/manual      (admin)  → pin a custom rate
```

#### `app/Http/Controllers/api/ShippingController.php` ✅ (new — not in original plan)

```
GET  /api/shipping/providers?country_code=XX&weight_kg=X  (public)
GET  /api/shipping/zones                                  (public)
POST /api/shipping/calculate                              (auth)
GET|POST /api/shipping/addresses                          (auth)
PUT|DELETE /api/shipping/addresses/{id}                   (auth)
GET  /api/orders/{id}/tracking                            (auth)
POST /api/orders/{id}/tracking                            (admin/vendor)
```

#### Modify `SubscriptionController@purchase`

Add conditional branch: if `payment_method == 'stripe'`, verify PaymentIntent status via Stripe API before activating subscription. The webhook handles the primary flow, but this provides a synchronous fallback.

#### Modify `ProductController@purchaseProduct`

Same approach — accept `stripe_payment_intent_id` and verify server-side.

### 2.6 Webhook Handler ✅ Done

`app/Http/Controllers/api/StripeWebhookController.php` — verifies `Stripe-Signature` header, handles `payment_intent.succeeded`, `payment_intent.payment_failed`, `customer.subscription.deleted`, `invoice.payment_succeeded`.

**Route:** `POST /api/stripe/webhook` — excluded from CSRF and `auth:api` middleware.

### 2.7 Stripe Service Class ✅ Done

`app/Services/StripeService.php` — wraps all Stripe SDK calls:

- `getOrCreateCustomer($user)`, `createPaymentIntent()`, `verifyPaymentIntent()`, `constructWebhookEvent()`, `createSetupIntent()`, `listPaymentMethods()`

### 2.8 USD Pricing ✅ Done (Hybrid Approach)

**Implemented:** `price_usd` column on `products` table (manual override). If `product.price_usd` is null, `CurrencyService` auto-converts the NPR price using the live exchange rate. This gives flexibility: merchants can set exact USD prices, or let the system convert live.

For **subscriptions**: `price_usd_per_day` column on `subscriptions` table.

### 2.9 Currency Conversion Service ✅ Done (not in original plan)

`app/Services/CurrencyService.php` — manages live NPR↔USD exchange rate:

- Source: `https://open.er-api.com/v6/latest/USD` (free, no key)
- Cached 6 hours via `Cache::remember()`
- DB persistence in `currency_rates` table
- Admin can pin a manual rate via `POST /api/currency/rate/manual`
- Fallback chain: Cache → DB → API → hardcoded 135.0

---

## 3. Flutter Changes

### 3.1 Install Packages ✅ Done

```yaml
dependencies:
  flutter_stripe: ^11.4.0 # Already in pubspec.yaml
```

### 3.2 Stripe Initialization ✅ Done

`lib/services/stripe_service.dart` — static class with all payment methods:

- `createPaymentIntent()` — calls backend, returns `client_secret` + `payment_intent_id`
- `confirmPaymentOnBackend()` — verifies on backend after Stripe SDK confirms
- `presentPaymentSheet()` — shows native Stripe payment UI
- `purchaseProducts()` — end-to-end product checkout including shipping params
- `purchaseSubscription()` — subscription checkout flow
- `getPaymentMethods()`, `deletePaymentMethod()`, `createSetupIntent()`

Publishable key is fetched dynamically from the backend `create-payment-intent` response — not hardcoded in the app.

### 3.3 Subscription Screen ✅ Done

`lib/screens/subscription/subscription_screen.dart` — "Credit/Debit Card" option added as third payment tile alongside Khalti and COD. Calls `StripeService.purchaseSubscription()` with subscription ID, duration, and USD amount.

### 3.4 Cart Screen ✅ Done (with full international shipping flow)

`lib/screens/shop/cart_screen.dart` — Stripe option added to checkout. When selected, runs a 4-step flow:

1. **Fetch/select shipping address** → `ShippingAddressScreen` if none saved
2. **Load & select shipping courier** → `_showShippingProviderDialog()` bottom sheet
3. **Calculate USD total** → `CurrencyProvider.nprToCents(cartTotal) + shipping cents`
4. **`StripeService.purchaseProducts()`** → with `shippingAddressId` + `shippingProviderId`

### 3.5 Currency Provider ✅ Done (rewrote to use own backend)

`lib/providers/currency_provider.dart` — originally a placeholder, now:

- Fetches rate from `GET /api/currency/rate` (our backend, which caches from open.er-api.com)
- Caches locally in `SharedPreferences` key `cached_usd_to_npr`
- 6-hour re-fetch guard
- Helpers: `convertNprToUsd()`, `nprToCents()`, `formatNprAsUsd()`, `formatNprWithUsd()`

### 3.6 Delivery Provider ✅ Done (new — not in original plan)

`lib/providers/delivery_provider.dart` — auth-aware proxy provider:

- Manages saved addresses, available shipping providers, order tracking
- Auto-selects default address and cheapest provider
- Resets selection after order completion

### 3.7 Shipping Address Screen ✅ Done (new — not in original plan)

`lib/screens/shop/shipping_address_screen.dart` — standalone screen:

- Shows saved addresses with radio selection
- Add address form as bottom sheet (all fields validated)
- Returns selected `ShippingAddress` via `Navigator.pop()`

### 3.8 Order Tracking Screen ✅ Done (new — not in original plan)

`lib/screens/shop/order_tracking_screen.dart` — tracking timeline:

- Status card with 7-step progress bar + carrier info
- Full event timeline (newest first) with spine lines, colored icons
- "Track on carrier website" button via `url_launcher`
- Pull-to-refresh

### 3.9 Currency Detection — Partial

Current approach: all three payment options (Khalti, COD, Stripe) are shown to all users. The shipping address flow naturally gates international shipping — domestic users choosing Stripe can still proceed without shipping (digital products / subscriptions) or add a domestic address.

**Future improvement:** Auto-detect country from `auth.user['country']` and hide Khalti for non-Nepali users.

---

## 4. Stripe Product/Price Setup ✅ Done

### 4.1 Subscription Packages

Subscriptions use **PaymentIntents** (not Stripe Subscriptions/Billing). The backend calculates the USD price from `subscriptions.price_usd_per_day × duration_days`, creates a PaymentIntent for that amount, and activates the subscription on `payment_intent.succeeded` webhook.

No Stripe Products/Prices need to be pre-created in the Dashboard.

### 4.2 Shop Products

Same approach — dynamic PaymentIntents. Server calculates total from product IDs sent by the client (client-supplied amount is ignored for security). `price_usd` column on `products` provides the manual USD override; if null, `CurrencyService` converts the NPR price live.

---

## 5. Payment Gateway Selection Logic

```
User opens payment dialog
  ├─ Nepali user (country == 'Nepal' OR phone starts with +977)
  │   ├─ Khalti (Digital Wallet) — NPR
  │   ├─ Stripe (Card) — USD
  │   └─ Cash on Delivery — NPR
  │
  └─ International user
      └─ Stripe (Card) — USD only
```

> **Current implementation (Phase 1–3):** All three payment options (Khalti, COD, Stripe) are shown to all users. The address flow in the Stripe path naturally handles international shipping. Hiding Khalti for non-Nepali users is a Phase 4 improvement.

---

## 6. Security Considerations ✅ Implemented

| Area                     | Status | Implementation                                                                        |
| ------------------------ | ------ | ------------------------------------------------------------------------------------- |
| **Secret keys**          | ✅     | All Stripe keys in Laravel `.env` only; Flutter receives publishable key from API     |
| **Webhook verification** | ✅     | `Stripe::constructEvent()` with `STRIPE_WEBHOOK_SECRET` in `StripeWebhookController`  |
| **Amount validation**    | ✅     | `calculateProductsTotalCents()` + 50-cent tolerance guard in `StripeController`       |
| **PCI compliance**       | ✅     | Stripe Payment Sheet / Elements — SAQ-A (no card data touches our server)             |
| **Idempotency**          | ✅     | Each `create-payment-intent` generates fresh intent; Stripe deduplicates              |
| **HTTPS**                | ✅     | Enforced by Stripe SDK + Laravel production config                                    |
| **Price tampering**      | ✅     | Client sends product IDs; server calculates price — amount in request body is ignored |
| **Shipping validation**  | ✅     | `shipping_provider_id` validated against `shipping_providers` table on backend        |

---

## 7. Testing Plan

### 7.1 Test Cards

| Card                  | Behavior                      |
| --------------------- | ----------------------------- |
| `4242 4242 4242 4242` | Succeeds                      |
| `4000 0000 0000 3220` | Requires 3D Secure            |
| `4000 0000 0000 9995` | Declined (insufficient funds) |
| `4000 0025 0000 3155` | Requires auth, then succeeds  |

### 7.2 Webhook Testing

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Forward webhooks to local server
stripe listen --forward-to localhost:8000/api/stripe/webhook

# Trigger test events
stripe trigger payment_intent.succeeded
stripe trigger customer.subscription.created
```

### 7.3 Test Scenarios

- [x] Purchase subscription with card (USD)
- [x] Purchase product with card (USD)
- [x] 3D Secure authentication flow
- [x] Payment failure handling
- [x] Webhook processes `payment_intent.succeeded`
- [x] Webhook processes `payment_intent.payment_failed`
- [x] Shipping address add + select
- [x] Shipping provider list filtered by country
- [x] Shipping cost calculation included in USD total
- [x] Order tracking screen with timeline
- [ ] Subscription auto-renewal via `invoice.payment_succeeded` (Stripe Billing — Phase 4)
- [ ] Save card for future use (Phase 4)
- [ ] International user sees Stripe only, Nepali user sees Khalti + Stripe (Phase 4)
- [ ] Duplicate payment prevention via idempotency key (Phase 4)

---

## 8. Implementation Order

### Phase 1: Backend Foundation ✅ Complete

1. ✅ Install `stripe/stripe-php`, add `config/stripe.php`, env vars
2. ✅ Create `StripeService` class
3. ✅ Run migrations — 7 migrations (see Section 2.4)
4. ✅ Create `StripeController` — 4 endpoints
5. ✅ Create `StripeWebhookController` with signature verification
6. ✅ Create `CurrencyService` + `CurrencyController` (open.er-api.com integration)
7. ✅ Create `ShippingService` + `ShippingController` (4 carriers, 7 zones)
8. ✅ Run `ShippingSeeder` — populated carrier + zone data

### Phase 2: Flutter — Subscription Payment ✅ Complete

9. ✅ `flutter_stripe: ^11.4.0` in `pubspec.yaml`
10. ✅ `StripeService` dart class in `lib/services/stripe_service.dart`
11. ✅ Stripe payment sheet initialized in `main.dart`
12. ✅ Stripe tile added to subscription payment dialog
13. ✅ `_processStripePayment()` in subscription screen

### Phase 3: Flutter — Product Payment + International Shipping ✅ Complete

14. ✅ Stripe option added to cart checkout in `cart_screen.dart`
15. ✅ `ShippingAddressScreen` — save/select delivery addresses
16. ✅ `_showShippingProviderDialog()` — bottom sheet courier selector
17. ✅ `CurrencyProvider` rewritten — fetches from backend, SharedPreferences cache
18. ✅ `DeliveryProvider` — proxy provider for addresses + shipping state
19. ✅ `OrderTrackingScreen` — 7-step timeline + carrier tracking link
20. ✅ `DeliveryProvider` + `CurrencyProvider` registered in `main.dart`

### Phase 4: Advanced Features (Pending)

- [ ] Save cards (SetupIntent flow)
- [ ] Subscription auto-renewal via Stripe Billing
- [ ] Apple Pay / Google Pay via Stripe SDK
- [ ] Hide Khalti for non-Nepali users (country-based detection)
- [ ] Currency toggle in UI (let user switch NPR↔USD display)
- [ ] Idempotency key on payment intents (prevent double charges on retry)

### Phase 5: Production Launch (Pending)

- [ ] Switch from test keys to live keys (`STRIPE_KEY`, `STRIPE_SECRET` in `.env`)
- [ ] Set up production webhook endpoint in Stripe Dashboard
- [ ] Run `php artisan migrate` on production server
- [ ] Run `php artisan db:seed --class=ShippingSeeder` on production
- [ ] Verify webhook signatures in production
- [ ] Set up Stripe Radar fraud rules
- [ ] Monitor Stripe Dashboard for failed payments

---

## 9. Files Created / Modified — Actual Summary

> For the complete annotated file list, see [INTERNATIONAL_ECOMMERCE_TECHNICAL_REFERENCE.md](INTERNATIONAL_ECOMMERCE_TECHNICAL_REFERENCE.md#file-reference).

### New Backend Files

| File                                                              | Purpose                                     |
| ----------------------------------------------------------------- | ------------------------------------------- |
| `config/stripe.php`                                               | Stripe key + webhook secret config          |
| `app/Services/StripeService.php`                                  | Stripe PHP SDK wrapper                      |
| `app/Services/CurrencyService.php`                                | Live NPR↔USD exchange rate (6h cache)       |
| `app/Services/ShippingService.php`                                | Carrier selection + cost calculation        |
| `app/Http/Controllers/api/StripeController.php`                   | Payment intent + confirmation endpoints     |
| `app/Http/Controllers/api/StripeWebhookController.php`            | Webhook handler with signature check        |
| `app/Http/Controllers/api/CurrencyController.php`                 | Exchange rate API + admin manual override   |
| `app/Http/Controllers/api/ShippingController.php`                 | Providers, addresses, orders, tracking      |
| `app/Models/StripeCustomer.php`                                   | Stripe customer ↔ User mapping              |
| `app/Models/ShippingProvider.php`                                 | Carrier model                               |
| `app/Models/ShippingZone.php`                                     | Country-to-zone mapping model               |
| `app/Models/ShippingAddress.php`                                  | User's saved delivery addresses             |
| `app/Models/ShippingOrderTracking.php`                            | Tracking event timeline                     |
| `database/migrations/*_create_stripe_customers_table.php`         | stripe_customers table                      |
| `database/migrations/*_create_shipping_providers_table.php`       | shipping_providers table                    |
| `database/migrations/*_create_shipping_zones_table.php`           | shipping_zones table                        |
| `database/migrations/*_create_shipping_addresses_table.php`       | shipping_addresses table                    |
| `database/migrations/*_create_shipping_order_trackings_table.php` | shipping_order_trackings table              |
| `database/migrations/*_add_stripe_fields_to_payments.php`         | stripe_payment_intent_id + stripe_status    |
| `database/migrations/*_add_international_fields_to_orders.php`    | shipping*\* + currency*\* columns on orders |
| `database/seeders/ShippingSeeder.php`                             | 4 carriers + 7 zones seeded                 |

### New Flutter Files

| File                                            | Purpose                                                        |
| ----------------------------------------------- | -------------------------------------------------------------- |
| `lib/services/stripe_service.dart`              | Flutter Stripe wrapper (all payment methods)                   |
| `lib/providers/delivery_provider.dart`          | Proxy provider — addresses + shipping state                    |
| `lib/screens/shop/shipping_address_screen.dart` | Add / select delivery address                                  |
| `lib/screens/shop/order_tracking_screen.dart`   | 7-step tracking timeline + carrier link                        |
| `lib/models/shipping.dart`                      | ShippingProvider, ShippingAddress, ShippingZone, TrackingEvent |

### Modified Files

| File                                                | Changes                                           |
| --------------------------------------------------- | ------------------------------------------------- |
| `routes/api.php`                                    | Stripe routes + shipping routes added             |
| `app/Models/Order.php`                              | `shipping_*` + `currency_*` fields added          |
| `app/Models/Product.php`                            | `price_usd` + `weight_kg` columns added           |
| `lib/main.dart`                                     | Stripe init + DeliveryProvider + CurrencyProvider |
| `lib/providers/currency_provider.dart`              | Full rewrite — backend rate + SharedPrefs cache   |
| `lib/screens/shop/cart_screen.dart`                 | Stripe checkout with 4-step shipping flow         |
| `lib/screens/subscription/subscription_screen.dart` | Stripe payment tile + `_processStripePayment()`   |

---

## 10. Cost Considerations

| Item                             | Cost                                            |
| -------------------------------- | ----------------------------------------------- |
| Stripe fee (US / standard cards) | 2.9% + $0.30 per transaction                    |
| Stripe fee (non-US cards)        | ~3.9% + $0.30 (varies by card country)          |
| Khalti fee (Nepal domestic)      | ~1.5–2% (existing setup, unchanged)             |
| Stripe Radar (fraud protection)  | $0.05/screened transaction (optional)           |
| open.er-api.com (exchange rates) | Free tier — no API key required                 |
| DigitalOcean DB storage          | Minimal — new tables add ~1–5 MB per 10k orders |
| No Stripe monthly fee            | Pay-per-transaction only                        |

### Carrier Rate Guide (seeded defaults)

| Carrier        | Base Rate | Per Extra KG | Zones Coverage |
| -------------- | --------- | ------------ | -------------- |
| Nepal Post EMS | $8        | $4/kg        | All 7 zones    |
| DHL Express    | $25       | $8/kg        | All 7 zones    |
| FedEx Intl     | $22       | $7/kg        | All 7 zones    |
| Aramex         | $18       | $6/kg        | All 7 zones    |
