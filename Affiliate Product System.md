# Baakhapaa Affiliate Product System - Complete Flow Documentation

**Document Version:** 3.0  
**Last Updated:** January 23, 2026  
**Status:** Implemented - Content Creator Affiliate System

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Overview](#2-system-overview)
3. [Core Implementation Concepts](#3-core-implementation-concepts)
4. [Complete User Flow](#4-complete-user-flow)
5. [API Implementation Guide](#5-api-implementation-guide)
6. [Content Linking System](#6-content-linking-system)
7. [Real-World Examples](#7-real-world-examples)
8. [Troubleshooting](#8-troubleshooting)
9. [Advanced Features](#9-advanced-features)
10. [Best Practices](#10-best-practices)
11. [FAQ](#11-faq)
12. [Summary](#12-summary)

---

## 1. Executive Summary

The Baakhapaa Affiliate Product System allows **content creators** (users who create shorts and episodes) to earn commissions by linking products to their content. The system operates through two distinct flows:

### 🎯 Two Ways to Link Products

| Method              | When to Use                  | Endpoint                                                                     |
| ------------------- | ---------------------------- | ---------------------------------------------------------------------------- |
| **During Creation** | Creating new shorts/episodes | `POST /api/shorts/create` or `POST /api/episodes/create`                     |
| **After Creation**  | Adding to existing content   | `POST /api/affiliate/link-to-short` or `POST /api/affiliate/link-to-episode` |

---

## 2. System Overview

### 2.1 System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│              CONTENT CREATOR AFFILIATE SYSTEM                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐          │
│  │   CREATOR    │    │   CONTENT    │    │   PRODUCTS   │          │
│  │              │    │ (Shorts/Ep)  │    │  (Affiliable)│          │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘          │
│         │                   │                   │                  │
│         │                   │                   │                  │
│         ▼                   ▼                   ▼                  │
│  ┌────────────────────────────────────────────────────────┐        │
│  │              LINKING MECHANISM                          │        │
│  │  ┌──────────────────┐  ┌──────────────────┐           │        │
│  │  │  During Creation │  │  After Creation  │           │        │
│  │  │  (store method)  │  │  (link-to-X API) │           │        │
│  │  └──────────────────┘  └──────────────────┘           │        │
│  └────────────────────────────────────────────────────────┘        │
│                                                                      │
│  ┌────────────────────────────────────────────────────────┐        │
│  │         CONTENT LINK TYPES                              │        │
│  │  • Featured Products (regular promotions)               │        │
│  │  • Affiliate Products (commission-based)                │        │
│  │  • Related Shorts (content recommendations)             │        │
│  │  • Related Episodes (specific story links)              │        │
│  │  • Season Links (series connections)                    │        │
│  └────────────────────────────────────────────────────────┘        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Link Types Summary

| Link Type     | Purpose                    | Commission | Linkable Types    | Who Can Use              |
| ------------- | -------------------------- | ---------- | ----------------- | ------------------------ |
| **Featured**  | Primary promotion          | ❌ No      | Products, Seasons | All creators             |
| **Affiliate** | Commission-based promotion | ✅ Yes     | Products          | Approved affiliates only |
| **Related**   | Content discovery          | ❌ No      | Shorts, Episodes  | All creators             |

---

## 3. Core Implementation Concepts

The system relies on two critical components working in tandem:

### 3.1 ContentLink vs AffiliateRequest

| Feature         | **ContentLink**                                                        | **AffiliateRequest**                                              |
| :-------------- | :--------------------------------------------------------------------- | :---------------------------------------------------------------- |
| **Purpose**     | **Structural/Visual**: Links content to items for front-end rendering. | **Business Logic**: Tracks commission, vendor approval & payouts. |
| **Visibility**  | Public (visible to end users in the app).                              | Internal (visible to Creator and Vendor).                         |
| **Types**       | `Affiliate`, `Featured`, `Related`.                                    | `pending`, `approved`, `rejected`.                                |
| **Polymorphic** | Yes (source -> Shorts/Episode, linkable -> Product/Season/Shorts).     | No (fixed fields for segments).                                   |

> [!IMPORTANT]
> A product is only displayed as an "Affiliate" product if a `ContentLink` of type `Affiliate` exists. However, for the creator to actually get paid, an approved `AffiliateRequest` must also exist for that product/user combination.

### 3.2 The `HasContentLinks` Trait

Most content models (`Shorts`, `Episode`) use the `HasContentLinks` trait to standardize how items are attached.

**Key Methods:**

- `linkProduct($productId, $type)`: Pairs a product with the content.
- `linkSeason($seasonId)`: Pairs a series/season.
- `linkShorts($shortsId)`: Pairs related shorts.
- `getLinkedContent()`: Retrieves all linked items (products, seasons, related content) in one go.

---

## 4. Complete User Flow

### 4.1 Prerequisite: Become an Affiliate

Before linking affiliate products, creators must join the affiliate program which should be manually accepted by admin :

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Apply to  │───▶│    Admin    │───▶│  Approved   │───▶│ Link Products│
│   Program   │    │   Review    │    │  Status     │    │ & Earn $$$  │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                  │                  │                  │
       │                  │                  │                  │
       ▼                  ▼                  ▼                  ▼
POST /program/join    Pending...       Admin Approve      Commission!
```

**API Call:**

```bash
POST /api/affiliate/program/join
Authorization: Bearer {token}
```

**Response:**

```json
{
  "message": "Application submitted successfully. Waiting for Admin approval."
}
```

---

### 4.2 Flow A: Link Products DURING Content Creation

This is the **primary method** for adding affiliate products when creating new shorts or episodes.

#### Step-by-Step Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DURING CREATION FLOW                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. Creator Opens Creation Form                                     │
│     ↓                                                                │
│  2. Fills Basic Info (title, description, video URL)                │
│     ↓                                                                │
│  3. [OPTIONAL] Selects Affiliate Products                           │
│     • Browse available products                                     │
│     • Select multiple products (array)                              │
│     • System shows commission % for each                            │
│     ↓                                                                │
│  4. [OPTIONAL] Selects Featured Products                            │
│     • Non-commission products                                       │
│     • Can be mixed with affiliate products                          │
│     ↓                                                                │
│  5. [OPTIONAL] Links Related Content                                │
│     • Link to a season (series)                                     │
│     • Link related shorts                                           │
│     ↓                                                                │
│  6. Submit Creation Request                                         │
│     ↓                                                                │
│  7. Backend Validation                                              │
│     • ✅ Check affiliate membership status                          │
│     • ✅ Validate product affiliability                             │
│     • ✅ Verify product commission > 0                              │
│     • ✅ Check user has enough coins                                │
│     ↓                                                                │
│  8. Create Short/Episode                                            │
│     ↓                                                                │
│  9. Create Affiliate Requests (auto-approved)                       │
│     ↓                                                                │
│ 10. Link Products to Content                                        │
│     • Type: 'Affiliate' for commission products                     │
│     • Type: 'Featured' for regular products                         │
│     ↓                                                                │
│ 11. ✅ SUCCESS - Content Created with Products!                     │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

#### API Implementation

**Endpoint:** `POST /api/shorts/create` (or `/api/episodes/create`)

**Request Body:**

```json
{
  "title": "Best Gaming Mouse 2026 Review",
  "description": "Honest review of top gaming mice",
  "video_url": "https://cdn.baakhapaa.com/videos/xyz.mp4",
  "shorts_topic_id": 5,
  "coins": 10,
  "coins_users": 5,

  // ═══════════════════════════════════════════
  // AFFILIATE PRODUCTS (Commission-based)
  // ═══════════════════════════════════════════
  "affiliate_product_ids": [456, 457, 458],

  // ═══════════════════════════════════════════
  // FEATURED PRODUCTS (No commission)
  // ═══════════════════════════════════════════
  "product_ids": [101, 102], // For Episodes, use 'products' instead of 'product_ids'

  // ═══════════════════════════════════════════
  // CONTENT LINKING (Related content)
  // ═══════════════════════════════════════════
  "season_id": 10, // Link to a series (Shorts/Episodes)
  "related_shorts_ids": [23, 45, 67], // Related videos (Shorts only)
  "related_episode_ids": [1012, 1013], // Link specific episodes

  "show_shorts": true,
  "question_limit": 4
}
```

**Response:**

```json
{
  "status": "success",
  "data": 789 // The newly created shorts ID
}
```

#### What Happens in the Backend

```php
// In ShortsController@store() method

// 1. Validate user is approved affiliate
$isApprovedAffiliate = AffiliateProgramRequest::where('user_id', auth()->id())
    ->where('status', 'approved')
    ->exists();

if (!$isApprovedAffiliate) {
    throw new Exception('Must be approved affiliate creator');
}

// 2. Create the shorts
$shorts = Shorts::create($request->myData());

// 3. For each affiliate product
foreach ($request->affiliate_product_ids as $productId) {
    $product = Product::find($productId);

    // 4. Validate product
    if (!$product->is_affiliable || $product->affiliate_commission <= 0) {
        throw new Exception("Product {$productId} not affiliable");
    }

    // 5. Create AffiliateRequest (auto-approved for program members)
    AffiliateRequest::firstOrCreate(
        [
            'user_id' => auth()->id(),
            'product_id' => $productId,
            'vendor_id' => $product->user_id,
            'shorts_id' => $shorts->id,
        ],
        [
            'status' => 'approved',
            'affiliate_commission' => $product->affiliate_commission,
        ]
    );

    // 6. Link product with 'Affiliate' type (using HasContentLinks trait)
    $shorts->linkProduct($productId, 'Affiliate');
}

// 7. Handle featured products (non-commission)
if ($request->filled('product_ids')) {
    $shorts->linkProducts($request->product_ids, 'featured');
}

// 8. Handle season and related shorts
if ($request->filled('season_id')) {
    $shorts->linkSeason($request->season_id, 'featured');
}

if ($request->filled('related_shorts_ids')) {
    foreach ($request->related_shorts_ids as $relatedId) {
        $shorts->linkShorts($relatedId, 'related');
    }
}

if ($request->filled('related_episode_ids')) {
    foreach ($request->related_episode_ids as $episodeId) {
        $shorts->linkEpisode($episodeId, 'related');
    }
}
```

---

### 4.3 Flow B: Link Products AFTER Content Creation

This method allows adding products to **existing** shorts/episodes.

#### Step-by-Step Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AFTER CREATION FLOW                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. Creator Has Existing Short/Episode                              │
│     ↓                                                                │
│  2. Wants to Add Affiliate Product                                  │
│     ↓                                                                │
│  3. Browse Available Products                                       │
│     GET /api/available-products                                     │
│     ↓                                                                │
│  4. Select Product to Add                                           │
│     ↓                                                                │
│  5. Call Link API                                                   │
│     POST /api/affiliate/link-to-short                               │
│     OR                                                               │
│     POST /api/affiliate/link-to-episode                             │
│     ↓                                                                │
│  6. Backend Validation                                              │
│     • ✅ Check if user owns the content                             │
│     • ✅ Check affiliate membership                                 │
│     • ✅ Validate product affiliability                             │
│     • ✅ Check for existing affiliate request                       │
│     ↓                                                                │
│  7. Create/Approve Affiliate Request                                │
│     • If approved member: auto-approve                              │
│     • If not: create pending request                                │
│     ↓                                                                │
│  8. Link Product to Content                                         │
│     • Create ContentLink with type 'Affiliate'                      │
│     ↓                                                                │
│  9. ✅ SUCCESS - Product Added!                                     │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

#### API Implementation

**Endpoint:** `POST /api/affiliate/link-to-short`

**Request Body:**

```json
{
  "shorts_id": 789, // The existing shorts ID
  "product_id": 456 // Product to add
}
```

**Response (Success):**

```json
{
  "status": "success",
  "message": "Product linked to short successfully as an affiliate product."
}
```

**Response (Not Affiliated):**

```json
{
  "status": "error",
  "message": "This product is not affiliated or approved for you."
}
```

#### What Happens in the Backend

```php
// In AffiliateController@linkToShort() method (hypothetical)

// 1. Find the shorts
$shorts = Shorts::findOrFail($request->shorts_id);

// 2. Check ownership
if ($shorts->user_id !== auth()->id()) {
    throw new UnauthorizedException();
}

// 3. Find the product
$product = Product::findOrFail($request->product_id);

// 4. Check if already has approved affiliate request
$affiliateRequest = AffiliateRequest::where('user_id', auth()->id())
    ->where('product_id', $product->id)
    ->where('status', 'approved')
    ->first();

// 5. If no request, check if user is approved member
if (!$affiliateRequest) {
    $isApprovedMember = AffiliateProgramRequest::where('user_id', auth()->id())
        ->where('status', 'approved')
        ->exists();

    if ($isApprovedMember && $product->is_affiliable) {
        // Auto-create approved request
        $affiliateRequest = AffiliateRequest::create([
            'user_id' => auth()->id(),
            'product_id' => $product->id,
            'vendor_id' => $product->user_id,
            'shorts_id' => $shorts->id,
            'status' => 'approved',
            'affiliate_commission' => $product->affiliate_commission,
        ]);
    } else {
        return error('Not affiliated or approved');
    }
}

// 6. Link product to shorts (using HasContentLinks trait)
$shorts->linkProduct($product->id, 'Affiliate');

return success('Product linked successfully');
```

---

### 4.4 Comparison: During vs After Creation

| Feature               | During Creation           | After Creation                      |
| --------------------- | ------------------------- | ----------------------------------- |
| **Endpoint**          | `POST /api/shorts/create` | `POST /api/affiliate/link-to-short` |
| **Multiple products** | ✅ Array of IDs           | ❌ One at a time                    |
| **Content exists**    | ❌ Being created          | ✅ Already exists                   |
| **Validation timing** | Before creation           | Before linking                      |
| **Use case**          | Planned content           | Add product later                   |
| **Flexibility**       | ⭐⭐⭐ High               | ⭐⭐ Medium                         |

---

## 5. API Implementation Guide

### 5.1 Complete API Endpoints

| Method | Endpoint                            | Purpose                         |
| ------ | ----------------------------------- | ------------------------------- |
| POST   | `/api/affiliate/program/join`       | Join affiliate program          |
| GET    | `/api/affiliate/available-products` | Get affiliable products         |
| GET    | `/api/affiliate/creator-requests`   | Get affiliation status          |
| POST   | `/api/shorts/create`                | Create shorts with products     |
| POST   | `/api/episodes/create`              | Create episode with products    |
| POST   | `/api/affiliate/link-to-short`      | Add product to existing short   |
| POST   | `/api/affiliate/link-to-episode`    | Add product to existing episode |

### 5.2 Detailed Request/Response Examples

#### Example 1: Create Shorts with Mixed Products

```javascript
// Create a short with both affiliate and featured products
const createShort = async () => {
  const response = await fetch("/api/shorts/create", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({
      title: "Top 5 Gadgets for Gamers",
      description: "My honest review of gaming gear",
      video_url: "https://cdn.baakhapaa.com/videos/gaming-review.mp4",
      shorts_topic_id: 3,
      coins: 15,
      coins_users: 10,

      // AFFILIATE PRODUCTS (earn commission)
      affiliate_product_ids: [456, 457, 458],

      // FEATURED PRODUCTS (no commission, just promotion)
      product_ids: [101, 102],

      // RELATED CONTENT
      season_id: 5,
      related_shorts_ids: [100, 101, 102],

      show_shorts: true,
      question_limit: 4,
    }),
  });

  const data = await response.json();

  if (response.ok) {
    console.log("✅ Short created:", data.data); // shorts ID
    return data.data;
  } else {
    console.error("❌ Error:", data.message);
    throw new Error(data.message);
  }
};
```

#### Example 2: Add Product to Existing Short

```javascript
// Add an affiliate product to an existing short
const addProductToShort = async (shortsId, productId) => {
  const response = await fetch("/api/affiliate/link-to-short", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({
      shorts_id: shortsId,
      product_id: productId,
    }),
  });

  const data = await response.json();

  if (response.ok) {
    console.log("✅ Product linked:", data.message);
    return true;
  } else if (response.status === 403) {
    console.error("❌ Not approved for this product");
    return false;
  } else {
    console.error("❌ Error:", data.message);
    throw new Error(data.message);
  }
};

// Usage
await addProductToShort(789, 456);
```

#### Example 3: Get Available Products

```javascript
// Browse products available for affiliation
const getAvailableProducts = async () => {
  const response = await fetch("/api/affiliate/available-products", {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
    },
  });

  const { data } = await response.json();

  // Filter products by commission rate
  const highCommission = data.filter((p) => p.affiliate_commission >= 15);
  const autoApproved = data.filter((p) => p.has_agreement);

  console.log(`Found ${data.length} products`);
  console.log(`${highCommission.length} with 15%+ commission`);
  console.log(`${autoApproved.length} auto-approved`);

  return data;
};
```

#### Example 4: Check Your Affiliate Requests

```javascript
// Get all your affiliate product requests
const getMyRequests = async () => {
  const response = await fetch("/api/affiliate/creator-requests", {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
    },
  });

  const { data } = await response.json();

  // Organize by status
  const requests = {
    approved: data.filter((r) => r.status === "approved"),
    pending: data.filter((r) => r.status === "pending"),
    rejected: data.filter((r) => r.status === "rejected"),
  };

  console.log("Affiliate Requests Summary:");
  console.log(`✅ Approved: ${requests.approved.length}`);
  console.log(`⏳ Pending: ${requests.pending.length}`);
  console.log(`❌ Rejected: ${requests.rejected.length}`);

  // Calculate potential earnings from approved products
  const potentialEarnings = requests.approved.reduce((sum, r) => {
    return sum + (r.product.price * r.affiliate_commission) / 100;
  }, 0);

  console.log(`💰 Potential earnings per sale: ₹${potentialEarnings}`);

  return requests;
};
```

---

## 6. Content Linking System

### 6.1 Database Structure

The system uses a **polymorphic relationship** called `ContentLink`:

```
content_links
├── id
├── source_id          → ID of the content (Shorts/Episode ID)
├── source_type        → Class path of content (App\Shorts or App\Episode)
├── linkable_id        → ID of the linked item (Product/Season/Shorts/Episode ID)
├── linkable_type      → Class path of linked item (App\Product, App\Season, App\Shorts, or App\Episode)
├── link_type          → 'Affiliate', 'Featured', 'Related'
├── sort_order         → integer (for manual ordering)
├── metadata           → json (custom settings)
└── timestamps
```

### 6.2 Link Types Explained

#### A. **Affiliate** (Commission-based)

```json
{
  "source_type": "App\\Shorts",
  "source_id": 789,
  "linkable_type": "App\\Product",
  "linkable_id": 456,
  "link_type": "Affiliate" // ← Commission earned!
}
```

**Characteristics:**

- ✅ Earns commission on sales
- ✅ Requires affiliate approval
- ✅ Tracks in `affiliate_requests` table
- ✅ Product must have `is_affiliable = 1`

#### B. **Featured** (Regular promotion)

```json
{
  "source_type": "App\\Shorts",
  "source_id": 789,
  "linkable_type": "App\\Product",
  "linkable_id": 101,
  "link_type": "Featured" // ← No commission
}
```

**Characteristics:**

- ❌ No commission earned
- ✅ Any creator can use
- ✅ No approval needed
- ✅ Used for both **Products** and **Seasons**

#### C. **Related** (Content recommendation)

```json
{
  "source_type": "App\\Shorts",
  "source_id": 789,
  "linkable_type": "App\\Shorts", // or App\\Episode
  "linkable_id": 100,
  "link_type": "Related" // ← Suggests other content
}
```

**Characteristics:**

- ❌ Not for products
- ✅ Links to other **Shorts** or **Episodes**
- ✅ Helps content discovery
- ✅ No approval needed

### 6.3 How Linked Content Appears

When fetching shorts via `GET /api/shorts_v2`, the response includes:

```json
{
  "items": [
    {
      "id": 789,
      "title": "Gaming Review",
      "video_url": "...",

      // ═══════════════════════════════════════
      // LINKED CONTENT SECTION
      // ═══════════════════════════════════════
      "linked_content": {
        // Season link (if part of a series)
        "season": {
          "id": 5,
          "title": "Gaming Series Season 1",
          "episodes_count": 10
        },

        // Related shorts (recommendations)
        "related_shorts": [
          {
            "id": 100,
            "title": "Gaming Setup Tour",
            "thumbnail": "..."
          },
          {
            "id": 101,
            "title": "Budget Gaming PC Build"
          }
        ],

        // Related episodes (specific story links)
        "related_episodes": [
          {
            "id": 1012,
            "title": "Why you need a high refresh rate",
            "video_url": "..."
          }
        ],

        // Products (both affiliate and featured)
        "products": [
          {
            "id": 456,
            "title": "Gaming Mouse Pro",
            "coin": 5000,
            "image": "https://app.baakhapaa.com/storage/..."
          },
          {
            "id": 457,
            "title": "Mechanical Keyboard"
          }
        ]
      }
    }
  ]
}
```

---

## 7. Real-World Examples

### Example 1: Tech Reviewer Workflow

**Scenario:** Ravi is a tech reviewer who wants to monetize his content.

```javascript
// STEP 1: Join affiliate program
await fetch("/api/program/join", {
  method: "POST",
  headers: { Authorization: `Bearer ${raviToken}` },
});
// Wait for admin approval...

// STEP 2: Browse available products
const products = await fetch("/api/available-products", {
  headers: { Authorization: `Bearer ${raviToken}` },
}).then((r) => r.json());

console.log("Available products:", products.data.length);
// Output: Available products: 150

// Filter gaming products with good commission
const gamingProducts = products.data.filter(
  (p) =>
    p.title.toLowerCase().includes("gaming") && p.affiliate_commission >= 12,
);

console.log("Gaming products with 12%+ commission:", gamingProducts.length);
// Output: Gaming products with 12%+ commission: 23

// STEP 3: Create review short with affiliate products
const shortsId = await fetch("/api/shorts", {
  method: "POST",
  headers: {
    Authorization: `Bearer ${raviToken}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    title: "Top 3 Gaming Mice Under ₹2000",
    description: "Honest review - which one should you buy?",
    video_url: "https://cdn.baakhapaa.com/ravi-mouse-review.mp4",
    shorts_topic_id: 3,
    coins: 20,
    coins_users: 15,

    // Add 3 gaming mice as affiliate products
    affiliate_product_ids: [456, 457, 458],

    question_limit: 4,
  }),
})
  .then((r) => r.json())
  .then((d) => d.data);

console.log("✅ Short created:", shortsId);
// Output: ✅ Short created: 1234

// STEP 4: Later, add another product he forgot
await fetch("/api/link-to-short", {
  method: "POST",
  headers: {
    Authorization: `Bearer ${raviToken}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    shorts_id: shortsId,
    product_id: 459, // Gaming mousepad
  }),
});

// STEP 5: Check affiliate status
const myRequests = await fetch("/api/creator-requests", {
  headers: { Authorization: `Bearer ${raviToken}` },
}).then((r) => r.json());

const totalProducts = myRequests.data.filter(
  (r) => r.status === "approved",
).length;
console.log("Total approved products:", totalProducts);
// Output: Total approved products: 4

// Calculate potential earnings
const avgProductPrice = 1500;
const avgCommission = 12; // 12%
const earningsPerSale =
  ((avgProductPrice * avgCommission) / 100) * totalProducts;

console.log(`💰 Potential earnings per sale: ₹${earningsPerSale}`);
// Output: 💰 Potential earnings per sale: ₹720
```

**Results:**

- Created 1 short with 3 products initially
- Added 1 more product later
- Total of 4 affiliate products
- If 10 people buy all products: **₹7,200 commission**

---

### Example 2: Beauty Influencer with Mixed Products

**Scenario:** Priya creates beauty content and wants to promote both affiliate and personal products.

```javascript
// Create a beauty tutorial with mixed products
const createBeautyTutorial = async () => {
  const response = await fetch("/api/shorts", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${priyaToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      title: "Full Glam Makeup Tutorial - Affordable Products",
      description: "Achieve this look with budget-friendly products!",
      video_url: "https://cdn.baakhapaa.com/priya-makeup.mp4",
      shorts_topic_id: 7, // Beauty category
      coins: 10,
      coins_users: 8,

      // AFFILIATE PRODUCTS (she earns commission)
      affiliate_product_ids: [
        601, // Foundation - 15% commission
        602, // Lipstick - 12% commission
        603, // Eyeshadow palette - 18% commission
      ],

      // FEATURED PRODUCTS (her own or brand partnerships)
      product_ids: [
        701, // Her own makeup brush set
        702, // Sponsored brand product
      ],

      // Link to her beauty series
      season_id: 15,

      // Related tutorials
      related_shorts_ids: [200, 201, 202],
    }),
  });

  return await response.json();
};

const result = await createBeautyTutorial();
console.log("✅ Tutorial created with:");
console.log("  - 3 affiliate products (commission)");
console.log("  - 2 featured products (no commission)");
console.log("  - 1 season link");
console.log("  - 3 related shorts");
```

---

### Example 3: Gaming Streamer Series

**Scenario:** Rohan is creating a gaming series and wants to link products across multiple episodes.

```javascript
// Helper function to create episode with products
const createEpisode = async (episodeNumber, title, productIds) => {
  return await fetch("/api/episodes", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${rohanToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      title: `Episode ${episodeNumber}: ${title}`,
      description: "Part of my gaming setup series",
      video_url: `https://cdn.baakhapaa.com/episode-${episodeNumber}.mp4`,
      season_id: 20, // Gaming Setup Series
      affiliate_product_ids: productIds,
    }),
  }).then((r) => r.json());
};

// Create a series with different products per episode
const createSeries = async () => {
  // Episode 1: PC Components
  const ep1 = await createEpisode(1, "Choosing the Right GPU", [
    801, // RTX 4060 - 10% commission
    802, // RTX 4070 - 12% commission
    803, // Power Supply - 8% commission
  ]);

  // Episode 2: Peripherals
  const ep2 = await createEpisode(2, "Best Gaming Keyboard & Mouse", [
    804, // Mechanical Keyboard - 15% commission
    805, // Gaming Mouse - 12% commission
  ]);

  // Episode 3: Monitor Setup
  const ep3 = await createEpisode(3, "Choosing Your Gaming Monitor", [
    806, // 144Hz Monitor - 10% commission
    807, // Monitor Arm - 8% commission
  ]);

  console.log("✅ Created 3-episode series with 8 total affiliate products");
  console.log("Episodes:", [ep1.data, ep2.data, ep3.data]);

  return {
    episodes: [ep1.data, ep2.data, ep3.data],
    totalProducts: 8,
    estimatedEarningsPerFullSetSale: 12500, // ₹1,25,000 avg product value * avg 10% commission
  };
};

await createSeries();
```

---

## 8. Troubleshooting

### 8.1 Common Errors & Solutions

#### Error 1: "You must be an approved affiliate creator"

**Cause:** Trying to add affiliate products without being approved.

**Solution:**

```javascript
// Check your affiliate status first
const checkStatus = async () => {
  const response = await fetch("/api/creator-requests", {
    headers: { Authorization: `Bearer ${token}` },
  });

  const data = await response.json();

  if (data.data.length === 0) {
    console.log("❌ Not an affiliate member yet");
    console.log("→ Apply via: POST /api/program/join");
    return false;
  }

  return true;
};

if (!(await checkStatus())) {
  // Apply to join
  await fetch("/api/program/join", {
    method: "POST",
    headers: { Authorization: `Bearer ${token}` },
  });

  console.log("⏳ Application submitted. Wait for approval.");
}
```

---

#### Error 2: "Product not available for affiliate marketing"

**Cause:** Product has `is_affiliable = 0` or `affiliate_commission = 0`.

**Solution:**

```javascript
// Always check product affiliability before linking
const validateProduct = async (productId) => {
  const response = await fetch("/api/available-products", {
    headers: { Authorization: `Bearer ${token}` },
  });

  const { data } = await response.json();
  const product = data.find((p) => p.id === productId);

  if (!product) {
    console.error(`❌ Product ${productId} not available for affiliation`);
    console.log("Possible reasons:");
    console.log("  - Product is not affiliable (is_affiliable = 0)");
    console.log("  - Product has no commission (affiliate_commission = 0)");
    console.log("  - You already requested this product");
    return false;
  }

  console.log(`✅ Product valid:`, {
    id: product.id,
    title: product.title,
    commission: `${product.affiliate_commission}%`,
    autoApproved: product.has_agreement,
  });

  return true;
};

// Usage
if (await validateProduct(456)) {
  // Proceed with linking
}
```

---

#### Error 3: "This product is not affiliated or approved for you"

**Cause:** Trying to link a product via `/link-to-short` that you haven't been approved for.

**Solution:**

```javascript
// Check if you have an approved request for this product
const checkAffiliateStatus = async (productId) => {
  const response = await fetch("/api/creator-requests", {
    headers: { Authorization: `Bearer ${token}` },
  });

  const { data } = await response.json();

  const request = data.find(
    (r) => r.product_id === productId && r.status === "approved",
  );

  if (!request) {
    console.error(`❌ No approved affiliation for product ${productId}`);
    console.log(
      "Status:",
      data.find((r) => r.product_id === productId)?.status || "Not requested",
    );

    // If you're an approved member, the link API will auto-approve
    console.log("💡 Try linking anyway - auto-approval may apply");
    return false;
  }

  console.log(`✅ Product ${productId} approved for affiliation`);
  return true;
};

await checkAffiliateStatus(456);
```

---

#### Error 4: Insufficient Coins

**Cause:** Not enough coins to create shorts with the coin settings.

**Solution:**

```javascript
// Check coin balance before creating shorts
const checkCoins = async (coinsPerView, totalViews) => {
  const response = await fetch("/api/user/profile", {
    headers: { Authorization: `Bearer ${token}` },
  });

  const user = await response.json();
  const requiredCoins = coinsPerView * totalViews;
  const availableCoins = user.information?.available_coins || 0;

  if (availableCoins < requiredCoins) {
    console.error(`❌ Insufficient coins`);
    console.log(`Required: ${requiredCoins} coins`);
    console.log(`Available: ${availableCoins} coins`);
    console.log(`Shortage: ${requiredCoins - availableCoins} coins`);
    return false;
  }

  console.log(`✅ Sufficient coins: ${availableCoins} >= ${requiredCoins}`);
  return true;
};

// Usage
const coins = 10;
const coinsUsers = 15;

if (await checkCoins(coins, coinsUsers)) {
  // Proceed with shorts creation
  await createShorts({ coins, coins_users: coinsUsers });
}
```

---

#### Error 5: "You can re-apply after 7 days"

**Cause:** Applied for affiliate program, got rejected, cooldown period active.

**Solution:**

```javascript
// Parse the error message to show remaining time
const handleCooldown = (errorMessage) => {
  // Error message: "You can re-apply after 7 days of rejection. Please wait 3 more days."
  const match = errorMessage.match(/wait (\d+) more days?/);

  if (match) {
    const daysLeft = parseInt(match[1]);
    const canReapplyDate = new Date();
    canReapplyDate.setDate(canReapplyDate.getDate() + daysLeft);

    console.log("⏳ Cooldown Period Active");
    console.log(`Days remaining: ${daysLeft}`);
    console.log(`Can re-apply on: ${canReapplyDate.toLocaleDateString()}`);

    // Show countdown in UI
    return {
      canApply: false,
      daysLeft,
      canReapplyDate,
    };
  }

  return { canApply: true };
};

// Usage
try {
  await fetch("/api/program/join", { method: "POST" });
} catch (error) {
  if (error.status === 402) {
    const cooldownInfo = handleCooldown(error.message);
    // Display countdown to user
  }
}
```

---

### 8.2 Validation Checklist

Before creating content with affiliate products, verify:

```javascript
const preflightCheck = async (shortsData) => {
  const checks = {
    affiliateMembership: false,
    productAvailability: false,
    coinBalance: false,
    ownership: false,
  };

  // 1. Check affiliate membership
  const memberResponse = await fetch("/api/creator-requests", {
    headers: { Authorization: `Bearer ${token}` },
  });
  const memberData = await memberResponse.json();
  checks.affiliateMembership = memberData.data.length > 0;

  // 2. Check products are available
  const productsResponse = await fetch("/api/available-products", {
    headers: { Authorization: `Bearer ${token}` },
  });
  const productsData = await productsResponse.json();
  const availableIds = productsData.data.map((p) => p.id);
  checks.productAvailability = shortsData.affiliate_product_ids.every((id) =>
    availableIds.includes(id),
  );

  // 3. Check coin balance
  const userResponse = await fetch("/api/user/profile", {
    headers: { Authorization: `Bearer ${token}` },
  });
  const userData = await userResponse.json();
  const requiredCoins = shortsData.coins * shortsData.coins_users;
  checks.coinBalance = userData.information?.available_coins >= requiredCoins;

  // 4. Check content ownership (for linking to existing content)
  if (shortsData.shorts_id) {
    const shortsResponse = await fetch(`/api/shorts/${shortsData.shorts_id}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const shorts = await shortsResponse.json();
    checks.ownership = shorts.user_id === userData.id;
  } else {
    checks.ownership = true; // Creating new content
  }

  // Report results
  console.log("Preflight Check Results:");
  console.log("═══════════════════════════");
  Object.entries(checks).forEach(([check, passed]) => {
    console.log(`${passed ? "✅" : "❌"} ${check}`);
  });
  console.log("═══════════════════════════");

  const allPassed = Object.values(checks).every((v) => v === true);

  if (!allPassed) {
    console.error("❌ Preflight check failed");
    return false;
  }

  console.log("✅ All checks passed - ready to proceed");
  return true;
};

// Usage
const shortsData = {
  title: "Product Review",
  affiliate_product_ids: [456, 457],
  coins: 10,
  coins_users: 5,
};

if (await preflightCheck(shortsData)) {
  // Proceed with creation
  await createShorts(shortsData);
}
```

---

### 8.3 Error Response Handling

Complete error handling implementation:

```javascript
class AffiliateAPIError extends Error {
  constructor(message, statusCode, data) {
    super(message);
    this.name = "AffiliateAPIError";
    this.statusCode = statusCode;
    this.data = data;
  }
}

const handleAPIResponse = async (response) => {
  const data = await response.json();

  if (!response.ok) {
    // Map status codes to user-friendly messages
    const errorMessages = {
      400: {
        "already applied":
          "You have already applied. Please wait for approval.",
        "already an approved member": "You are already an affiliate member!",
      },
      401: "Please log in to continue.",
      402: "Cooldown period active. Please wait before re-applying.",
      403: {
        "not affiliated": "This product requires affiliation approval.",
        UNAUTHORIZED: "You do not have permission to perform this action.",
      },
      404: "Resource not found.",
      422: "Validation failed. Please check your input.",
      500: "Server error. Please try again later.",
    };

    let userMessage = data.message;

    if (errorMessages[response.status]) {
      if (typeof errorMessages[response.status] === "object") {
        // Find matching message
        for (const [key, msg] of Object.entries(
          errorMessages[response.status],
        )) {
          if (data.message?.toLowerCase().includes(key)) {
            userMessage = msg;
            break;
          }
        }
      } else {
        userMessage = errorMessages[response.status];
      }
    }

    throw new AffiliateAPIError(userMessage, response.status, data);
  }

  return data;
};

// Usage
const safeAPICall = async (endpoint, options = {}) => {
  try {
    const response = await fetch(endpoint, {
      ...options,
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        Accept: "application/json",
        ...options.headers,
      },
    });

    return await handleAPIResponse(response);
  } catch (error) {
    if (error instanceof AffiliateAPIError) {
      // Handle specific error types
      switch (error.statusCode) {
        case 402:
          showCooldownTimer(error.data.message);
          break;
        case 403:
          showPermissionDenied(error.message);
          break;
        case 422:
          showValidationErrors(error.data.errors);
          break;
        default:
          showErrorMessage(error.message);
      }

      console.error("API Error:", error);
      return null;
    }

    // Network or other errors
    console.error("Unexpected Error:", error);
    showErrorMessage("Network error. Please check your connection.");
    return null;
  }
};

// Example usage
const result = await safeAPICall("/api/program/join", {
  method: "POST",
});

if (result) {
  console.log("Success:", result.message);
}
```

---

## 9. Advanced Features

### 9.1 Batch Product Linking

Link multiple products to existing shorts in one go:

```javascript
const batchLinkProducts = async (shortsId, productIds) => {
  const results = {
    successful: [],
    failed: [],
  };

  for (const productId of productIds) {
    try {
      const response = await fetch("/api/link-to-short", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          shorts_id: shortsId,
          product_id: productId,
        }),
      });

      if (response.ok) {
        results.successful.push(productId);
        console.log(`✅ Linked product ${productId}`);
      } else {
        const error = await response.json();
        results.failed.push({ productId, error: error.message });
        console.error(
          `❌ Failed to link product ${productId}: ${error.message}`,
        );
      }

      // Add delay to avoid rate limiting
      await new Promise((resolve) => setTimeout(resolve, 500));
    } catch (error) {
      results.failed.push({ productId, error: error.message });
      console.error(`❌ Error linking product ${productId}:`, error);
    }
  }

  console.log("\n📊 Batch Linking Results:");
  console.log(`✅ Successful: ${results.successful.length}`);
  console.log(`❌ Failed: ${results.failed.length}`);

  if (results.failed.length > 0) {
    console.log("\nFailed products:", results.failed);
  }

  return results;
};

// Usage: Link 5 products to shorts #789
const productIds = [456, 457, 458, 459, 460];
const results = await batchLinkProducts(789, productIds);
```

---

### 9.2 Smart Product Recommendations

Get personalized product recommendations based on content:

```javascript
const getRecommendedProducts = async (shortsData) => {
  // Fetch all available products
  const response = await fetch("/api/available-products", {
    headers: { Authorization: `Bearer ${token}` },
  });
  const { data: products } = await response.json();

  // Analyze shorts content
  const keywords = extractKeywords(
    shortsData.title + " " + shortsData.description,
  );

  // Score products based on relevance
  const scoredProducts = products.map((product) => {
    let score = 0;

    // Keyword matching
    keywords.forEach((keyword) => {
      if (product.title.toLowerCase().includes(keyword.toLowerCase())) {
        score += 10;
      }
      if (product.description?.toLowerCase().includes(keyword.toLowerCase())) {
        score += 5;
      }
    });

    // Commission score
    score += product.affiliate_commission; // Higher commission = higher score

    // Auto-approval bonus
    if (product.has_agreement) {
      score += 20;
    }

    return { ...product, score };
  });

  // Sort by score and return top 10
  const recommendations = scoredProducts
    .sort((a, b) => b.score - a.score)
    .slice(0, 10);

  console.log("🎯 Recommended Products:");
  recommendations.forEach((p, i) => {
    console.log(
      `${i + 1}. ${p.title} - ${p.affiliate_commission}% commission (score: ${p.score})`,
    );
  });

  return recommendations;
};

// Helper function
const extractKeywords = (text) => {
  const commonWords = [
    "the",
    "a",
    "an",
    "and",
    "or",
    "but",
    "in",
    "on",
    "at",
    "to",
    "for",
  ];
  return text
    .toLowerCase()
    .split(/\s+/)
    .filter((word) => word.length > 3 && !commonWords.includes(word))
    .filter((word, index, self) => self.indexOf(word) === index); // Unique words
};

// Usage
const shortsData = {
  title: "Best Gaming Headsets for 2026",
  description: "Compare top gaming headsets with great audio quality",
};

const recommended = await getRecommendedProducts(shortsData);
```

---

### 9.3 Analytics Dashboard

Track your affiliate performance:

```javascript
const getAffiliateAnalytics = async () => {
  // Get all your requests
  const response = await fetch("/api/creator-requests", {
    headers: { Authorization: `Bearer ${token}` },
  });
  const { data: requests } = await response.json();

  // Calculate analytics
  const analytics = {
    totalRequests: requests.length,
    approved: requests.filter((r) => r.status === "approved").length,
    pending: requests.filter((r) => r.status === "pending").length,
    rejected: requests.filter((r) => r.status === "rejected").length,

    // Products by content type
    linkedToShorts: requests.filter((r) => r.shorts_id !== null).length,
    linkedToEpisodes: requests.filter((r) => r.episode_id !== null).length,

    // Commission analysis
    avgCommission:
      requests.reduce((sum, r) => sum + r.affiliate_commission, 0) /
      requests.length,
    highestCommission: Math.max(...requests.map((r) => r.affiliate_commission)),
    lowestCommission: Math.min(...requests.map((r) => r.affiliate_commission)),

    // Product breakdown
    productsByVendor: {},
    productsByCommission: {
      low: requests.filter((r) => r.affiliate_commission < 10).length, // <10%
      medium: requests.filter(
        (r) => r.affiliate_commission >= 10 && r.affiliate_commission < 15,
      ).length, // 10-15%
      high: requests.filter((r) => r.affiliate_commission >= 15).length, // >15%
    },

    // Recent activity
    recentApprovals: requests
      .filter((r) => r.status === "approved")
      .sort((a, b) => new Date(b.updated_at) - new Date(a.updated_at))
      .slice(0, 5),
  };

  // Group by vendor
  requests.forEach((r) => {
    const vendorName = r.vendor?.name || "Unknown";
    if (!analytics.productsByVendor[vendorName]) {
      analytics.productsByVendor[vendorName] = 0;
    }
    analytics.productsByVendor[vendorName]++;
  });

  // Display analytics
  console.log("📊 AFFILIATE ANALYTICS DASHBOARD");
  console.log("═══════════════════════════════════════════");
  console.log(`Total Requests: ${analytics.totalRequests}`);
  console.log(`✅ Approved: ${analytics.approved}`);
  console.log(`⏳ Pending: ${analytics.pending}`);
  console.log(`❌ Rejected: ${analytics.rejected}`);
  console.log("");
  console.log("Content Distribution:");
  console.log(`  Shorts: ${analytics.linkedToShorts}`);
  console.log(`  Episodes: ${analytics.linkedToEpisodes}`);
  console.log("");
  console.log("Commission Analysis:");
  console.log(`  Average: ${analytics.avgCommission.toFixed(2)}%`);
  console.log(`  Highest: ${analytics.highestCommission}%`);
  console.log(`  Lowest: ${analytics.lowestCommission}%`);
  console.log("");
  console.log("Commission Breakdown:");
  console.log(`  Low (<10%): ${analytics.productsByCommission.low} products`);
  console.log(
    `  Medium (10-15%): ${analytics.productsByCommission.medium} products`,
  );
  console.log(`  High (>15%): ${analytics.productsByCommission.high} products`);
  console.log("");
  console.log("Top Vendors:");
  Object.entries(analytics.productsByVendor)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .forEach(([vendor, count]) => {
      console.log(`  ${vendor}: ${count} products`);
    });
  console.log("═══════════════════════════════════════════");

  return analytics;
};

// Usage
const analytics = await getAffiliateAnalytics();
```

---

### 9.4 Automated Content Workflow

Complete automation for content creators:

```javascript
class AffiliateContentCreator {
  constructor(token) {
    this.token = token;
    this.baseURL = "https://api.baakhapaa.com/api";
  }

  async createShortsWithRecommendations(shortsData) {
    console.log("🚀 Starting automated content creation...\n");

    // Step 1: Get recommended products
    console.log("1️⃣ Getting product recommendations...");
    const recommendations = await this.getRecommendedProducts(shortsData);
    const topProducts = recommendations.slice(0, 3).map((p) => p.id);
    console.log(`   Found ${topProducts.length} recommended products\n`);

    // Step 2: Validate products
    console.log("2️⃣ Validating products...");
    const validProducts = await this.validateProducts(topProducts);
    console.log(`   ${validProducts.length} products validated\n`);

    // Step 3: Check coin balance
    console.log("3️⃣ Checking coin balance...");
    const hasCoins = await this.checkCoins(
      shortsData.coins,
      shortsData.coins_users,
    );
    if (!hasCoins) {
      throw new Error("Insufficient coins");
    }
    console.log("   ✅ Sufficient coins\n");

    // Step 4: Create shorts
    console.log("4️⃣ Creating shorts...");
    const shortsId = await this.createShorts({
      ...shortsData,
      affiliate_product_ids: validProducts,
    });
    console.log(`   ✅ Shorts created: #${shortsId}\n`);

    // Step 5: Verify links
    console.log("5️⃣ Verifying product links...");
    await this.verifyLinks(shortsId);
    console.log("   ✅ All products linked successfully\n");

    console.log("✅ Automated workflow complete!");
    console.log(`📹 Shorts ID: ${shortsId}`);
    console.log(`🔗 Products linked: ${validProducts.length}`);

    return {
      shortsId,
      productsLinked: validProducts.length,
      products: validProducts,
    };
  }

  async getRecommendedProducts(shortsData) {
    // Implementation from previous example
    const response = await fetch(`${this.baseURL}/available-products`, {
      headers: { Authorization: `Bearer ${this.token}` },
    });
    const { data } = await response.json();

    // Simple keyword matching and scoring
    const keywords = shortsData.title.toLowerCase().split(/\s+/);
    return data
      .map((p) => ({
        ...p,
        score:
          keywords.reduce((score, keyword) => {
            return score + (p.title.toLowerCase().includes(keyword) ? 10 : 0);
          }, 0) + p.affiliate_commission,
      }))
      .sort((a, b) => b.score - a.score);
  }

  async validateProducts(productIds) {
    const response = await fetch(`${this.baseURL}/available-products`, {
      headers: { Authorization: `Bearer ${this.token}` },
    });
    const { data } = await response.json();
    const availableIds = data.map((p) => p.id);

    return productIds.filter((id) => availableIds.includes(id));
  }

  async checkCoins(coins, coinsUsers) {
    const response = await fetch(`${this.baseURL}/user/profile`, {
      headers: { Authorization: `Bearer ${this.token}` },
    });
    const user = await response.json();
    const required = coins * coinsUsers;
    const available = user.information?.available_coins || 0;

    return available >= required;
  }

  async createShorts(data) {
    const response = await fetch(`${this.baseURL}/shorts`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(data),
    });

    const result = await response.json();
    return result.data;
  }

  async verifyLinks(shortsId) {
    const response = await fetch(`${this.baseURL}/shorts/${shortsId}`, {
      headers: { Authorization: `Bearer ${this.token}` },
    });
    const shorts = await response.json();

    if (
      !shorts.linked_content?.products ||
      shorts.linked_content.products.length === 0
    ) {
      throw new Error("Product linking failed");
    }

    return true;
  }
}

// Usage
const creator = new AffiliateContentCreator(userToken);

const result = await creator.createShortsWithRecommendations({
  title: "Top 5 Budget Gaming Laptops 2026",
  description: "Best gaming laptops under ₹60,000",
  video_url: "https://cdn.baakhapaa.com/gaming-laptops.mp4",
  shorts_topic_id: 3,
  coins: 15,
  coins_users: 10,
  question_limit: 4,
});

console.log("Result:", result);
```

---

## 10. Best Practices

### 10.1 Content Creation Guidelines

✅ **DO:**

- Choose products relevant to your content
- Focus on products with 12%+ commission
- Use auto-approved products when possible
- Link 2-4 products per short (not too many)
- Create quality content that drives sales

❌ **DON'T:**

- Spam products in every video
- Link unrelated products
- Create misleading content
- Oversaturate with affiliate links
- Ignore product quality

---

### 10.2 Performance Optimization

```javascript
// Cache available products to reduce API calls
class ProductCache {
  constructor(ttl = 3600000) {
    // 1 hour default
    this.cache = null;
    this.timestamp = null;
    this.ttl = ttl;
  }

  async get(token) {
    const now = Date.now();

    if (this.cache && this.timestamp && now - this.timestamp < this.ttl) {
      console.log("📦 Using cached products");
      return this.cache;
    }

    console.log("🔄 Fetching fresh products");
    const response = await fetch("/api/available-products", {
      headers: { Authorization: `Bearer ${token}` },
    });
    const { data } = await response.json();

    this.cache = data;
    this.timestamp = now;

    return data;
  }

  invalidate() {
    this.cache = null;
    this.timestamp = null;
  }
}

const productCache = new ProductCache();

// Usage
const products = await productCache.get(token);
```

---

## 11. FAQ

**Q: Can I link products to shorts created before joining the affiliate program?**  
A: Yes! Use the `POST /api/link-to-short` endpoint to add products to existing shorts.

**Q: What's the difference between `affiliate_product_ids` and `product_ids`?**  
A: `affiliate_product_ids` earn commission (requires approval), `product_ids` are just featured promotions (no commission).

**Q: How many products can I link to one short?**  
A: No hard limit, but 2-4 products is recommended for best user experience.

**Q: Can I remove a product after linking?**  
A: Not currently available via API. Contact support or admin panel.

**Q: Do I earn commission if I buy my own products?**  
A: No, self-purchases typically don't earn commission (fraud prevention).

**Q: How long does affiliate approval take?**  
A: Typically 2-3 business days for manual review, instant if you're already an approved member.

**Q: Can I change the commission rate?**  
A: No, commission rates are set by vendors/products.

**Q: What happens if a product becomes unavailable?**  
A: The link remains but shows as unavailable to users. No new sales possible.

---

## 12. Summary

### Complete Affiliate Flow

```
JOIN PROGRAM → GET APPROVED → BROWSE PRODUCTS → CREATE/LINK CONTENT → EARN COMMISSION
```

### Two Methods to Link Products

1. **During Creation**: Bulk add via `affiliate_product_ids` array
2. **After Creation**: Individual add via `/api/link-to-short`

### Key Validations

- ✅ Affiliate membership status
- ✅ Product affiliability
- ✅ Coin balance
- ✅ Content ownership

### Success Formula

**Quality Content + Relevant Products + Good Commission = Affiliate Success** 🎯

---

**Document Status:** Complete  
**Last Updated:** January 23, 2026  
**Next Review:** As needed for system updates
