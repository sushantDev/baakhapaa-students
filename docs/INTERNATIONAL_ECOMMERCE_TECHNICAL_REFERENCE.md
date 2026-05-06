# Baakhapaa International E-Commerce — Technical Implementation Reference

**Last Updated:** March 25, 2026  
**Status:** Implemented & Deployed  
**Scope:** International card payments (Stripe), real-time currency conversion, international shipping, and order tracking.

---

## 1. System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Flutter Client (v3.0.42)                      │
│                                                                      │
│  CurrencyProvider          DeliveryProvider        StripeService     │
│  (cached rate, 6h TTL)     (addresses, providers,  (payment sheet +  │
│                             tracking fetch)         backend confirm)  │
│                                                                      │
│  cart_screen.dart  →  shipping_address_screen.dart                   │
│                    →  shipping provider bottom sheet                  │
│                    →  Stripe payment sheet (flutter_stripe)           │
│                    →  order_tracking_screen.dart                     │
└────────────────────────────────┬────────────────────────────────────┘
                                 │ HTTPS / REST API
┌────────────────────────────────▼────────────────────────────────────┐
│                  Laravel 11 Backend (baakhapaa.com/api)              │
│                                                                      │
│  CurrencyController         ShippingController     StripeController  │
│  CurrencyService            ShippingService                          │
│  (open.er-api.com, 6h)      (zone lookup, rates,                     │
│                              tracking events)                        │
└──────────┬──────────────────────┬──────────────────────┬────────────┘
           │                      │                      │
     open.er-api.com       MySQL Database           Stripe API
     (live FX rate)        (10 new tables)          (PaymentIntent)
```

---

## 2. Database Schema

### 2.1 New Tables

#### `currency_rates`

Stores the latest NPR↔USD rate. One row updated in-place (`from_currency=NPR, to_currency=USD`).

| Column            | Type                         | Notes                                                                  |
| ----------------- | ---------------------------- | ---------------------------------------------------------------------- |
| `id`              | bigint PK                    |                                                                        |
| `from_currency`   | varchar(3)                   | `NPR`                                                                  |
| `to_currency`     | varchar(3)                   | `USD`                                                                  |
| `rate`            | decimal(14,8)                | NPR value of 1 USD — but stored as **1 NPR in USD**. e.g. `0.00740741` |
| `source`          | enum: `auto`, `manual`       | `auto` = from API, `manual` = admin override                           |
| `provider`        | varchar                      | e.g. `open.er-api.com`                                                 |
| Unique constraint | (from_currency, to_currency) |                                                                        |

#### `shipping_providers`

| Column                   | Type             | Notes                                                    |
| ------------------------ | ---------------- | -------------------------------------------------------- |
| `id`                     | bigint PK        |                                                          |
| `name`                   | varchar          | DHL Express, FedEx International, Nepal Post EMS, Aramex |
| `slug`                   | varchar unique   | `dhl-express`, `fedex`, `nepal-ems`, `aramex`            |
| `logo`                   | varchar nullable | Filename                                                 |
| `website`                | varchar nullable | URL                                                      |
| `tracking_url_template`  | text             | URL with `{tracking_number}` placeholder                 |
| `contact_email`          | varchar nullable |                                                          |
| `contact_phone`          | varchar nullable |                                                          |
| `supports_international` | boolean          | Must be `true` to appear in checkout                     |
| `is_active`              | boolean          | Toggle without deleting                                  |
| `sort_order`             | int              | Display order in lists                                   |

#### `shipping_zones`

7 geographic regions. Each row maps a region name to an array of ISO-3166-1 alpha-2 country codes.

| Column          | Type           | Notes                   |
| --------------- | -------------- | ----------------------- |
| `id`            | bigint PK      |                         |
| `name`          | varchar        | e.g. `North America`    |
| `region_code`   | varchar unique | e.g. `north_america`    |
| `country_codes` | JSON           | e.g. `["US","CA","MX"]` |

**Pre-seeded zones:**

- `south_asia` — IN, BD, LK, PK, AF, BT, MV
- `southeast_asia` — TH, SG, MY, ID, VN, PH, MM, KH, LA
- `east_asia` — JP, KR, CN, HK, TW, MO
- `middle_east` — AE, SA, QA, KW, BH, OM, JO, LB, IL
- `europe` — GB, DE, FR, NL, ES, IT, SE, NO, DK, CH, AT, BE, PT, FI, PL, CZ, HU, RO
- `north_america` — US, CA
- `australia_pacific` — AU, NZ, FJ, PG

#### `shipping_rates`

Base + per-kg cost for each (provider, zone) pair.

| Column                 | Type                                     | Notes                   |
| ---------------------- | ---------------------------------------- | ----------------------- |
| `id`                   | bigint PK                                |                         |
| `shipping_provider_id` | FK → shipping_providers                  |                         |
| `shipping_zone_id`     | FK → shipping_zones                      |                         |
| `base_cost_usd`        | decimal(8,2)                             | Base rate for ≤1 kg     |
| `per_kg_usd`           | decimal(8,2)                             | Added per kg above 1 kg |
| `min_days`             | int                                      | Minimum delivery days   |
| `max_days`             | int                                      | Maximum delivery days   |
| `is_active`            | boolean                                  |                         |
| Unique constraint      | (shipping_provider_id, shipping_zone_id) |                         |

**Cost formula:** `cost = base_cost_usd + max(0, weight_kg - 1) × per_kg_usd`

**Sample rates (USD, 0.5 kg parcel):**

| Provider       | South Asia | Europe | North America |
| -------------- | ---------- | ------ | ------------- |
| Nepal Post EMS | $5         | $16    | $14           |
| Aramex         | $8         | $28    | $25           |
| DHL Express    | $12        | $35    | $30           |
| FedEx          | $15        | $38    | $33           |

#### `shipping_addresses`

User's saved international delivery addresses.

| Column           | Type             | Notes                    |
| ---------------- | ---------------- | ------------------------ |
| `id`             | bigint PK        |                          |
| `user_id`        | FK → users       |                          |
| `recipient_name` | varchar          |                          |
| `phone`          | varchar          |                          |
| `address_line1`  | varchar          |                          |
| `address_line2`  | varchar nullable |                          |
| `city`           | varchar          |                          |
| `state_province` | varchar nullable |                          |
| `postal_code`    | varchar          |                          |
| `country_code`   | char(2)          | ISO 3166-1 alpha-2       |
| `country_name`   | varchar          |                          |
| `is_default`     | boolean          | Pre-selected at checkout |
| `deleted_at`     | timestamp        | SoftDeletes              |

#### `order_tracking_events`

Immutable append-only log of status changes for an order.

| Column        | Type             | Notes                   |
| ------------- | ---------------- | ----------------------- |
| `id`          | bigint PK        |                         |
| `order_id`    | FK → orders      |                         |
| `status`      | varchar          | See status enum below   |
| `location`    | varchar nullable | e.g. "Kathmandu Hub"    |
| `description` | text nullable    | Free-text note          |
| `event_at`    | datetime         | When the event occurred |

**Status values:** `pending`, `processing`, `packed`, `shipped`, `in_transit`, `out_for_delivery`, `delivered`, `failed`, `returned`

#### New columns on existing tables

**`orders`:**

```
shipping_address_id     bigint nullable FK → shipping_addresses
shipping_provider_id    bigint nullable FK → shipping_providers
shipping_cost_usd       decimal(10,2) default 0
shipping_cost_npr       decimal(10,2) default 0
package_weight_kg       decimal(6,3) default 0
tracking_number         varchar nullable
tracking_url            varchar nullable
shipping_status         enum (pending…returned) default pending
shipped_at              timestamp nullable
estimated_delivery_at   timestamp nullable
delivered_at            timestamp nullable
```

**`products`:**

```
weight_kg    decimal(6,3) default 0.5   — used for shipping cost calculation
price_usd    decimal(10,2) nullable      — manual USD override; auto-converted if null
```

---

## 3. Backend Services

### 3.1 `CurrencyService`

**File:** `app/Services/CurrencyService.php`

| Method                                  | Description                                                                                                                       |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `getUsdToNpr(): float`                  | Returns NPR per 1 USD. Cached 6h via `Cache::remember()`. On cache miss: checks DB, then fetches `open.er-api.com/v6/latest/USD`. |
| `getNprToUsd(): float`                  | Returns `1 / getUsdToNpr()`.                                                                                                      |
| `getRateInfo(): array`                  | Returns `{usd_to_npr, npr_to_usd, source, provider, updated_at}` for API response.                                                |
| `nprToUsd(float): float`                | NPR → USD rounded to 2dp.                                                                                                         |
| `nprToCents(float): int`                | NPR → Stripe cents (USD × 100).                                                                                                   |
| `centsToNpr(int): float`                | Stripe cents → NPR for display.                                                                                                   |
| `refreshFromApi(): array`               | Forces a fresh API call, persists to DB, busts cache. Used by admin.                                                              |
| `setManualRate(float $usdToNpr): array` | Admin pin. Sets `source = manual`. Busts cache.                                                                                   |

**Cache TTL:** 6 hours (`CACHE_KEY = 'currency_rate_usd_npr'`)  
**External API:** `https://open.er-api.com/v6/latest/USD` — free tier, no API key required  
**Fallback chain:** Cache → DB → API → hardcoded default (135.0)

---

### 3.2 `ShippingService`

**File:** `app/Services/ShippingService.php`

| Method                                                                         | Description                                                                                                                                          |
| ------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `getProvidersForCountry(string $countryCode, float $weightKg): array`          | Finds zone by country code (PHP `in_array` over loaded zones), loads rates + providers, calculates cost_usd, cost_npr. Sorted by cost_usd ascending. |
| `calculateRate(int $providerId, string $countryCode, float $weightKg): ?array` | Single provider+country rate. Returns `{cost_usd, cost_npr, cost_cents, estimated_days_min, estimated_days_max}` or `null`.                          |
| `addTrackingEvent(Order $order, array $data): OrderTrackingEvent`              | Creates event row, updates `order.shipping_status`, sets `shipped_at`/`delivered_at` from event data.                                                |
| `getTrackingTimeline(Order $order): array`                                     | Returns full tracking payload: events, carrier info, shipping address.                                                                               |
| `calculateCartWeight(array $items): float`                                     | Sums `product.weight_kg * qty`. Defaults to 0.5 kg per item if `weight_kg` is null.                                                                  |

---

## 4. Backend Controllers & API Endpoints

### 4.1 `CurrencyController`

**File:** `app/Http/Controllers/api/CurrencyController.php`

| Method            | Route                             | Auth   | Description                        |
| ----------------- | --------------------------------- | ------ | ---------------------------------- |
| `getRate()`       | `GET /api/currency/rate`          | Public | Returns current rate + metadata    |
| `refreshRate()`   | `POST /api/currency/rate/refresh` | Admin  | Force-fetches from open.er-api.com |
| `setManualRate()` | `POST /api/currency/rate/manual`  | Admin  | Body: `{"usd_to_npr": 136.50}`     |

**Sample response (`GET /api/currency/rate`):**

```json
{
  "success": true,
  "data": {
    "usd_to_npr": 135.1,
    "npr_to_usd": 0.00740193,
    "source": "auto",
    "provider": "open.er-api.com",
    "updated_at": "2026-03-25T08:00:00.000000Z"
  }
}
```

---

### 4.2 `ShippingController`

**File:** `app/Http/Controllers/api/ShippingController.php`

| Method               | Route                                                       | Auth         | Description                                    |
| -------------------- | ----------------------------------------------------------- | ------------ | ---------------------------------------------- |
| `getProviders()`     | `GET /api/shipping/providers?country_code=US&weight_kg=1.5` | Public       | Available couriers + costs for a country       |
| `getZones()`         | `GET /api/shipping/zones`                                   | Public       | All 7 regions + country code list              |
| `calculateRate()`    | `POST /api/shipping/calculate`                              | Auth         | Body: `{provider_id, country_code, weight_kg}` |
| `getAddresses()`     | `GET /api/shipping/addresses`                               | Auth         | All user's saved addresses                     |
| `storeAddress()`     | `POST /api/shipping/addresses`                              | Auth         | Create new address                             |
| `updateAddress()`    | `PUT /api/shipping/addresses/{id}`                          | Auth         | Update address fields                          |
| `deleteAddress()`    | `DELETE /api/shipping/addresses/{id}`                       | Auth         | Soft-delete                                    |
| `getTracking()`      | `GET /api/orders/{id}/tracking`                             | Auth         | Full tracking timeline for an order            |
| `addTrackingEvent()` | `POST /api/orders/{id}/tracking`                            | Admin/Vendor | Add a tracking status event                    |

**Sample response (`GET /api/shipping/providers?country_code=US&weight_kg=0.5`):**

```json
{
  "success": true,
  "data": {
    "providers": [
      {
        "provider_id": 3,
        "provider_name": "Nepal Post EMS",
        "provider_slug": "nepal-ems",
        "estimated_delivery": "14–21 business days",
        "cost_usd": 14.0,
        "cost_npr": 1890.0
      },
      {
        "provider_id": 1,
        "provider_name": "DHL Express",
        "provider_slug": "dhl-express",
        "estimated_delivery": "3–5 business days",
        "cost_usd": 30.0,
        "cost_npr": 4050.0
      }
    ],
    "currency_rate": 135.1
  }
}
```

---

### 4.3 `StripeController`

**File:** `app/Http/Controllers/api/StripeController.php`  
Injected dependencies: `StripeService`, `CurrencyService`, `ShippingService`

#### `POST /api/stripe/create-payment-intent`

**Server-side amount validation for products (security-critical):**

1. Receives `product_ids[]` and optional `shipping_address_id` + `shipping_provider_id`
2. For each product: uses `product.price_usd` if set, else auto-converts `product.price` (NPR) via `CurrencyService::nprToCents()`
3. Calculates shipping cost via `ShippingService::calculateRate()`
4. Compares client-sent amount against server-calculated total
5. Rejects if difference > 50 cents (tampering protection)
6. Returns `client_secret` and `payment_intent_id`

#### `POST /api/stripe/confirm-payment`

1. Verifies `payment_intent_id` status on Stripe — must be `succeeded`
2. Idempotency check: rejects if `Payment` row with same `stripe_payment_intent_id` already exists
3. Creates `Payment` + `Order` + `OrderProduct` rows in a `DB::transaction()`
4. For international orders: records `shipping_address_id`, `shipping_provider_id`, `shipping_cost_usd/npr` on the order
5. Creates initial `pending` tracking event
6. Returns order details

---

## 5. Flutter Implementation

### 5.1 `CurrencyProvider`

**File:** `lib/providers/currency_provider.dart`

- Initialized in `main.dart` as a standalone `ChangeNotifierProvider` (not proxy — no auth needed)
- On construction: loads cached rate from `SharedPreferences` immediately (no flicker), then calls `fetchRate()`
- `fetchRate()`: calls `GET /api/currency/rate`, parses `data.usd_to_npr`, updates `_usdToNpr` and `_nprToUsd`, re-caches, notifies listeners
- 6-hour re-fetch guard via `_lastFetched`
- SharedPreferences key: `cached_usd_to_npr`

Exposed helpers:

```dart
double convertNprToUsd(double npr)       // npr * _nprToUsd
int    nprToCents(double npr)             // (npr * _nprToUsd * 100).round()
String formatNprAsUsd(double npr)        // "$9.99"
String formatNprWithUsd(double npr)      // "Rs. 1,350  (~$9.99)"
```

---

### 5.2 `DeliveryProvider`

**File:** `lib/providers/delivery_provider.dart`

Registered as `ChangeNotifierProxyProvider<Auth, DeliveryProvider>` — receives auth token when user logs in.

**State:**

```
_addresses            List<ShippingAddress>
_availableProviders   List<ShippingProvider>
_selectedAddress      ShippingAddress?
_selectedProvider     ShippingProvider?
_isLoadingAddresses   bool
_isLoadingProviders   bool
_currentWeightKg      double
```

**Key methods:**

| Method                                   | Behaviour                                                                           |
| ---------------------------------------- | ----------------------------------------------------------------------------------- |
| `fetchAddresses()`                       | `GET /shipping/addresses`. Auto-selects default.                                    |
| `addAddress(Map data)`                   | `POST /shipping/addresses`. Inserts at front of list. Auto-selects if `is_default`. |
| `deleteAddress(int id)`                  | `DELETE /shipping/addresses/{id}`. Falls back selection to first remaining.         |
| `selectAddress(address)`                 | Sets selected, clears provider list, triggers `_loadProvidersForAddress`.           |
| `loadProviders({countryCode, weightKg})` | `GET /shipping/providers?...`. Auto-selects cheapest.                               |
| `selectProvider(provider)`               | Sets selected provider.                                                             |
| `fetchOrderTracking(int orderId)`        | `GET /orders/{id}/tracking`. Returns raw map.                                       |
| `resetSelection()`                       | Clears selected provider only (preserves address).                                  |
| `clearAll()`                             | Full reset (e.g., on logout).                                                       |

**Computed getters:**

```dart
bool   isReadyForInternationalCheckout   // address != null && provider != null
double totalShippingCostUsd              // selectedProvider?.costUsd ?? 0.0
double totalShippingCostNpr              // selectedProvider?.costNpr ?? 0.0
```

---

### 5.3 `StripeService`

**File:** `lib/services/stripe_service.dart`

All methods are `static` — no provider injection needed at the service level.

**`purchaseProducts()` — full checkout flow:**

```dart
static Future<Map<String, dynamic>> purchaseProducts({
  required String authToken,
  required List<int> productIds,
  required int amountInCents,
  int? shippingAddressId,
  int? shippingProviderId,
})
```

1. Calls `createPaymentIntent()` → passes `shipping_address_id` + `shipping_provider_id` in body
2. Extracts `client_secret` and `payment_intent_id` from response
3. Calls `presentPaymentSheet(clientSecret)` — shows native Stripe UI
4. On success, calls `confirmPaymentOnBackend()` → passes shipping IDs again

**`createPaymentIntent()` body for product type:**

```json
{
  "amount": 4550,
  "currency": "usd",
  "type": "product",
  "product_ids": [12, 15],
  "shipping_address_id": 3,
  "shipping_provider_id": 1
}
```

---

### 5.4 Shipping Address Screen

**File:** `lib/screens/shop/shipping_address_screen.dart`  
**Route:** `/shipping-address`  
**Returns:** `ShippingAddress?` via `Navigator.pop()`

- Calls `delivery.fetchAddresses()` in `addPostFrameCallback` (never in builder)
- `_AddressTile`: animated container with radio-circle selection, default badge, delete button with confirmation dialog
- `_AddAddressSheet`: `showModalBottomSheet` with `Form`, all fields validated, `is_default` switch
- "Continue" button disabled until an address is selected
- "Add Address" FAB only shows when addresses already exist (empty state uses an inline button)

---

### 5.5 Order Tracking Screen

**File:** `lib/screens/shop/order_tracking_screen.dart`  
**Route:** `/order-tracking`  
**Arguments:** `int orderId`

Key widget composition:

- `_StatusCard`: gradient container with current status icon + color, progress bar (7 steps), carrier info row, "Track on carrier website" `OutlinedButton` using `url_launcher`
- `_TrackingTimeline`: `ListView` of events sorted **newest first**; uses `IntrinsicHeight` + vertical spine lines to create a CSS-style timeline. Each event card highlights the most recent one.
- `DeliveryProviderAccessor.of(context)` helper to call `fetchOrderTracking()` without Provider listening

---

### 5.6 Cart Screen — Stripe Flow Update

**File:** `lib/screens/shop/cart_screen.dart`

`_processStripeProductPurchase()` now runs a 4-step sequential flow:

```
1. delivery.fetchAddresses()
   └─ if selectedAddress == null → push ShippingAddressScreen, await result
   └─ if user cancels → early return with message

2. if availableProviders.isEmpty → delivery.loadProviders(countryCode, weightKg)
   └─ show _showShippingProviderDialog() (StatefulBuilder bottom sheet)
   └─ if user cancels → early return with message

3. totalCents = currency.nprToCents(cart.totalAmount)
              + (shippingProvider.costUsd * 100).round()

4. StripeService.purchaseProducts(
     authToken, productIds, totalCents,
     shippingAddressId: address.id,
     shippingProviderId: provider.id,
   )
   └─ on success: cart.reset(), delivery.resetSelection(), orderSuccessDialogue()
```

`_showShippingProviderDialog()`: Returns selected `ShippingProvider?`. Uses `StatefulBuilder` inside `showModalBottomSheet` so radio selection updates without rebuilding the parent. Each tile shows courier name, delivery estimate, and USD cost.

---

## 6. Data Models (Flutter)

**File:** `lib/models/shipping.dart`

```
ShippingAddress     id, userId, recipientName, phone,
                    addressLine1, addressLine2?, city, stateProvince?,
                    postalCode, countryCode, countryName, isDefault
                    → get formattedAddress (comma-joined)

ShippingProvider    id, name, slug, logo?, website?,
                    estimatedDelivery, costUsd, costNpr,
                    estimatedDaysMin, estimatedDaysMax
                    → fromJson() handles both 'provider_id'/'id' keys

OrderTrackingEvent  id, status, location?, description?, eventAt

OrderTracking       orderId, trackingNumber?, trackingUrl?,
                    shippingStatus, carrier?, carrierLogo?,
                    shippedAt?, estimatedDelivery?, deliveredAt?,
                    shippingAddress?, events[]
                    → get statusLabel (human-readable string map)
```

---

## 7. Provider Registration (`lib/main.dart`)

```dart
// Currency — standalone, no auth needed
ChangeNotifierProvider.value(value: currencyProvider)   // line ~549

// Delivery — auth-aware proxy
ChangeNotifierProxyProvider<Auth, DeliveryProvider>(
  create: (_) => DeliveryProvider(''),
  update: (ctx, auth, previous) => DeliveryProvider(auth.token),
)

// Routes added
ShippingAddressScreen.routeName: (ctx) => const ShippingAddressScreen(),
OrderTrackingScreen.routeName:   (ctx) => const OrderTrackingScreen(),
```

---

## 8. Security Controls

| Threat                       | Mitigation                                                                                                                                                    |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Client-sent amount tampering | Server recalculates product total from DB `price_usd` (or auto-converts NPR price). Rejects if diff > 50 cents.                                               |
| Stripe key exposure          | `STRIPE_SECRET_KEY` lives only in `.env`. Flutter only receives `publishable_key` in API response (never hardcoded).                                          |
| Double fulfillment           | Idempotency check: `Payment::where('stripe_payment_intent_id', $id)->first()` before fulfilling.                                                              |
| Spoofed payment status       | `confirmPayment()` always calls `stripeService->verifyPaymentIntent()` and checks `status === 'succeeded'` directly on Stripe's servers.                      |
| Address ownership spoofing   | `ShippingAddress::where('id', ...)->where('user_id', $user->id)` — address ID + ownership verified in StripeController before using for shipping calculation. |
| Webhook replay / MITM        | Stripe signature verified via `STRIPE_WEBHOOK_SECRET` on every webhook call.                                                                                  |
| SSRF via currency API        | `CurrencyService` calls a hardcoded URL (`open.er-api.com`), not user-provided input.                                                                         |

---

## 9. Deployment Checklist

### Backend

```bash
php artisan migrate
php artisan db:seed --class=ShippingSeeder
php artisan config:clear
php artisan cache:clear
```

### Required `.env` Values

```env
STRIPE_PUBLISHABLE_KEY=pk_live_...
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_CURRENCY=usd
```

### Stripe Dashboard Setup

- Set webhook URL: `https://student.baakhapaa.com/api/stripe/webhook`
- Events to listen for: `payment_intent.succeeded`, `payment_intent.payment_failed`

### Flutter

No new env vars needed. API base URL auto-resolves to `https://student.baakhapaa.com/api`. Stripe publishable key is received dynamically from the backend in `create-payment-intent` response.

---

## 10. File Reference

### New Backend Files

| File                                                                                                | Purpose                             |
| --------------------------------------------------------------------------------------------------- | ----------------------------------- |
| `database/migrations/2026_03_25_160001_create_currency_rates_table.php`                             | Currency rates table                |
| `database/migrations/2026_03_25_160002_create_shipping_providers_table.php`                         | Couriers table                      |
| `database/migrations/2026_03_25_160003_create_shipping_zones_table.php`                             | Regions + country codes             |
| `database/migrations/2026_03_25_160004_create_shipping_rates_table.php`                             | Cost per (provider, zone)           |
| `database/migrations/2026_03_25_160005_create_shipping_addresses_table.php`                         | User addresses                      |
| `database/migrations/2026_03_25_160006_add_shipping_fields_to_orders_table.php`                     | Shipping columns on orders          |
| `database/migrations/2026_03_25_160007_add_weight_to_products_and_create_tracking_events_table.php` | Product weight + tracking events    |
| `app/Models/CurrencyRate.php`                                                                       | Eloquent model for rates            |
| `app/Models/ShippingProvider.php`                                                                   | Courier model                       |
| `app/Models/ShippingZone.php`                                                                       | Region model, `findByCountryCode()` |
| `app/Models/ShippingRate.php`                                                                       | Rate model, `calculateCost()`       |
| `app/Models/ShippingAddress.php`                                                                    | User address model                  |
| `app/Models/OrderTrackingEvent.php`                                                                 | Tracking event model                |
| `app/Services/CurrencyService.php`                                                                  | Live FX rate management             |
| `app/Services/ShippingService.php`                                                                  | Shipping quote + tracking           |
| `app/Http/Controllers/api/CurrencyController.php`                                                   | Currency API endpoints              |
| `app/Http/Controllers/api/ShippingController.php`                                                   | Shipping + tracking endpoints       |
| `database/seeders/ShippingSeeder.php`                                                               | 4 providers, 7 zones, 28 rates      |

### Modified Backend Files

| File                                            | Changes                                                                                                               |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `app/Product.php`                               | Added `price_usd`, `weight_kg` to `$fillable` and `$casts`                                                            |
| `app/Order.php`                                 | Shipping columns in fillable + `shippingAddress()`, `shippingProvider()`, `trackingEvents()` relationships            |
| `routes/api.php`                                | Currency + shipping routes added                                                                                      |
| `app/Http/Controllers/api/StripeController.php` | Injected `CurrencyService` + `ShippingService`; server-side price validation; shipping cost in fulfillProductPurchase |
| `database/seeders/DatabaseSeeder.php`           | Calls `ShippingSeeder::class`                                                                                         |

### New Flutter Files

| File                                            | Purpose                                                                             |
| ----------------------------------------------- | ----------------------------------------------------------------------------------- |
| `lib/models/shipping.dart`                      | `ShippingAddress`, `ShippingProvider`, `OrderTrackingEvent`, `OrderTracking` models |
| `lib/providers/delivery_provider.dart`          | State: addresses, providers, tracking fetches                                       |
| `lib/screens/shop/shipping_address_screen.dart` | Address list + add address sheet                                                    |
| `lib/screens/shop/order_tracking_screen.dart`   | Timeline tracking UI                                                                |

### Modified Flutter Files

| File                                   | Changes                                                                                        |
| -------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `lib/providers/currency_provider.dart` | Rewrote to use `/api/currency/rate`; SharedPreferences cache; `nprToCents()` helper            |
| `lib/services/stripe_service.dart`     | Added `shippingAddressId` + `shippingProviderId` to all three relevant methods                 |
| `lib/screens/shop/cart_screen.dart`    | Added shipping address + provider selection flow; `_showShippingProviderDialog()`; new imports |
| `lib/main.dart`                        | DeliveryProvider registered; new routes; new imports                                           |
