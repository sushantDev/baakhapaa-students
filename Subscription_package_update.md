## Migrating Subscription API from V1 to V2

This document describes the **data-level changes** required to migrate Subscription Packages from **V1** to **V2**. No application or UI code is included. Only API behavior and JSON structures are documented.

---

## 1. Legacy Subscription API (V1)

**Endpoint**

```
{{url}}/api/subscription
```

**Key Characteristics (V1)**

- Subscription packages are tightly coupled with:
  - `level`
  - `seasons`
  - `achievements`

- Business rules are implicit and inferred from relationships
- No explicit concept of reusable or count-based benefits

**Response Structure (Example)**

```json
{
  "success": true,
  "message": "Success",
  "data": [
    {
      "id": 1,
      "title": "Silver Package",
      "description": "Silver Package",
      "points_per_day": 12,
      "price_per_day": 24,
      "level_id": 1,
      "created_at": "2025-08-22T08:59:31.000000Z",
      "updated_at": "2025-10-13T07:59:47.000000Z",
      "level": { "id": 1, "name": "Level 1" },
      "seasons": [{ "id": 16 }, { "id": 21 }],
      "achievements": [{ "id": 2 }]
    }
  ]
}
```

---

## 2. Updated Subscription API (V2)

**Endpoint**

```
{{url}}/api/subscription/v2/index
```

**Key Changes in V2**

- Subscriptions no longer directly expose `seasons`, `levels`, or `achievements`
- All entitlements are represented as **benefits**
- Benefits are:
  - Explicit
  - Quantifiable
  - Reusable across packages

- UI and feature logic must rely exclusively on `benefits`

---

## 3. Subscription Package – V2 Response Structure

```json
{
  "success": true,
  "message": "Success",
  "data": [
    {
      "id": 1,
      "title": "Silver Package",
      "description": "Silver Package",
      "points_per_day": 12,
      "price_per_day": 24,
      "level_id": 1,
      "created_at": "2025-08-22T08:59:31.000000Z",
      "updated_at": "2025-10-13T07:59:47.000000Z",
      "benefits": [
        {
          "id": 1,
          "benefit_type_id": 1,
          "name": "Upgrade level",
          "description": "Premium User can update his/her level.",
          "quantity": 1
        },
        {
          "id": 2,
          "benefit_type_id": 2,
          "name": "Unlock stories",
          "description": "Premium User can unlock any season as wanted freely.",
          "quantity": 3
        },
        {
          "id": 3,
          "benefit_type_id": 3,
          "name": "Extra lives",
          "description": "Premium User can add lives if needed during quizzes",
          "quantity": 6
        },
        {
          "id": 4,
          "benefit_type_id": 4,
          "name": "Skip Timer",
          "description": "Premium User can skip time to participate in quizzes.",
          "quantity": 6
        },
        {
          "id": 5,
          "benefit_type_id": 5,
          "name": "Bypass Questions",
          "description": "Premium users can bypass difficult questions on quizzes.",
          "quantity": 10
        },
        {
          "id": 11,
          "benefit_type_id": 6,
          "name": "Unlock Achievement",
          "description": "Premium User can unlock achievement freely.",
          "quantity": 2
        }
      ]
    }
  ]
}
```

---

## 4. Benefit Types & Meaning

Each subscription package exposes a list of **benefits**. The client must interpret behavior strictly based on `benefit_type_id` and `quantity`.

| Benefit Type       | Description                    | Behavior                      |
| ------------------ | ------------------------------ | ----------------------------- |
| Upgrade Level      | Level progression entitlement  | User can upgrade level        |
| Unlock Achievement | Achievement unlock entitlement | User can unlock achievements  |
| Skip Timer         | Timer bypass entitlement       | User can skip waiting timers  |
| Unlock Stories     | Season unlock entitlement      | User can unlock seasons       |
| Extra Life         | Quiz retry entitlement         | User can add lives in quizzes |

- `quantity` defines how many times a benefit can be used
- Backend handles decrementing usage automatically upon API call
- Client must call the usage API to persist consumption
  **Quantity Rule**

- `quantity` defines how many times a benefit can be used
- # Client must decrement usage locally and/or rely on backend enforcement
- `quantity` defines how many times a benefit can be used
- Backend handles decrementing usage automatically upon API call
- Client must call the usage API to persist consumption
  > > > > > > > ffefaae02497fe90d1729354c7a949d31352fc35
  > > > > > > > a5ab61371fdf2472ecf093637b107da5b858c2ff

---

## 5. Subscription Package Screen Requirements

- Subscription listing **must use V2 API only**
- Do **not** infer benefits from legacy fields
- Display benefits dynamically from the `benefits` array
- Do not hardcode package rules

---

## 6. User Subscription Status API

**Endpoint**

```
{{url}}/api/v2/user
```

**Relevant Field**

```json
{
  "subscription_expires_at": "2026-03-01T00:00:00.000000Z"
}
```

**Usage Rules**

- If `subscription_expires_at` is null → user is NOT subscribed
- If current time > `subscription_expires_at` → subscription expired
- Benefits are usable only while subscription is active

---

## 7. Migration Rules (Non‑Negotiable)

- V1 fields (`seasons`, `achievements`, `level`) must NOT be consumed in new UI
- All entitlement logic must come from `benefits`
- Backend is the single source of truth for quantities
- Client assumptions based on package name (Silver / Gold / Platinum) are invalid

## 8. Get Subscription User benifit

- Get API that would get all the user data of Subscription "/subscription/user-benefit-status"
- This api will check the remaining benefit of the user who have purchased the subscription

- Benefits_type sql data

```sql
INSERT INTO `benefit_types` (`id`, `name`, `slug`, `description`, `is_active`, `created_at`, `updated_at`)
VALUES
	(1, 'Upgrade level', 'level%upgrade%vJvW', 'Premium User can update his/her level.', 1, '2026-01-21 16:43:40', '2026-01-21 16:43:40'),
	(2, 'Unlock stories', 'season%unlock%q5HP', 'Premium User can unlock any season as wanted freely.', 1, '2026-01-21 16:44:23', '2026-01-21 16:44:23'),
	(3, 'Extra lives', 'extra%lives%d1Rr', 'Premium User can add lives if needed during quizzes', 1, '2026-01-21 16:48:25', '2026-01-21 16:48:25'),
	(4, 'Skip Timer', 'skip%timer%VVo6', 'Premium User can skip time to participate in quizzes.', 1, '2026-01-21 16:49:02', '2026-01-21 16:49:02'),
	(5, 'Bypass Questions', 'bypass%questions%Td37', 'Premium users can bypass difficult questions on quizzes.', 1, '2026-01-21 16:50:25', '2026-01-21 16:50:25'),
	(6, 'Unlock Achievement', 'unlock%achievement%u0Tz', 'Premium User can unlock achievement freely.', 1, '2026-01-22 12:31:44', '2026-01-22 12:31:44'),
	(7, 'Challenge Unlock', 'challenge%unlock%kRcF', 'Challenge Unlock', 1, '2026-01-26 16:37:36', '2026-01-26 16:37:36');
```

- Example User Data here use has purchased Gold Package

  ```json
  "success": true,
  "code": 0,
  "locale": "en",
  "message": "OK",
  "data": {
    "items": [
      {
        "subscription": {
          "id": 2,
          "title": "Gold Package",
          "price": 48
        },
        "benefits": [
          {
            "id": 25,
            "benefit_type": {
              "id": 1,
              "name": "Upgrade level",
              "description": "Premium User can update his/her level."
            },
            "usage": {
              "used_count": 0,
              "available_count": 2,
              "remaining": 2,
              "is_unlimited": false
            },
            "can_use": true,
            "last_benefit_used_at": "2026-01-26 16:43:51"
          },
          {
            "id": 26,
            "benefit_type": {
              "id": 2,
              "name": "Unlock stories",
              "description": "Premium User can unlock any season as wanted freely."
            },
            "usage": {
              "used_count": 0,
              "available_count": 6,
              "remaining": 6,
              "is_unlimited": false
            },
            "can_use": true,
            "last_benefit_used_at": "2026-01-26 16:43:51"
          },
          {
            "id": 27,
            "benefit_type": {
              "id": 3,
              "name": "Extra lives",
              "description": "Premium User can add lives if needed during quizzes"
            },
            "usage": {
              "used_count": 0,
              "available_count": 12,
              "remaining": 12,
              "is_unlimited": false
            },
            "can_use": true,
            "last_benefit_used_at": "2026-01-26 16:43:52"
          },
          {
            "id": 28,
            "benefit_type": {
              "id": 4,
              "name": "Skip Timer",
              "description": "Premium User can skip time to participate in quizzes."
            },
            "usage": {
              "used_count": 0,
              "available_count": 12,
              "remaining": 12,
              "is_unlimited": false
            },
            "can_use": true,
            "last_benefit_used_at": "2026-01-26 16:43:52"
          },
          {
            "id": 29,
            "benefit_type": {
              "id": 5,
              "name": "Bypass Questions",
              "description": "Premium users can bypass difficult questions on quizzes."
            },
            "usage": {
              "used_count": 0,
              "available_count": 20,
              "remaining": 20,
              "is_unlimited": false
            },
            "can_use": true,
            "last_benefit_used_at": "2026-01-26 16:43:52"
          },
          {
            "id": 30,
            "benefit_type": {
              "id": 6,
              "name": "Unlock Achievement",
              "description": "Premium User can unlock achievement freely."
            },
            "usage": {
              "used_count": 0,
              "available_count": 4,
              "remaining": 4,
              "is_unlimited": false
            },
            "can_use": true,
            "last_benefit_used_at": "2026-01-26 16:43:52"
          },
          {
            "id": 31,
            "benefit_type": {
              "id": 7,
              "name": "Challenge Unlock",
              "description": "Challenge Unlock"
            },
            "usage": {
              "used_count": 0,
              "available_count": 2,
              "remaining": 2,
              "is_unlimited": false
            },
            "can_use": true,
            "last_benefit_used_at": "2026-01-26 16:43:52"
          }
        ]
      }
    ]
  }


  ```

### Usage Rules (Strict)

- A benefit is usable **only if** all conditions below are true:
  - `subscription_expires_at` is NOT expired
  - `available_count > 0` OR `is_unlimited = true`
  - `can_use = true`

- `available_count = 0` → benefit is fully consumed and must be disabled everywhere

- `is_unlimited = true` → ignore all counters, benefit always usable until subscription expires

- Client must **never** calculate or guess usage

- This API **overrides** package-level `quantity`

---

### Client Enforcement Rules

- Subscription screen → use **V2 package API**
- Runtime actions (unlock, skip, upgrade, etc.) → use **user benefit status API**
- Never decrement counters locally without backend confirmation

## 10. Update User Subscription Benefit Usage

This is a **PUT** API used to persist benefit consumption after every successful usage. It must be called **immediately after** a benefit-based action is completed.

**Endpoint**

```http
PUT /api/subscription/user-benefit-usage/{user_benefit_usages_id}
```

### Purpose

- Update benefit usage counters after each use.
- Keep backend as the single source of truth.
- Prevent client-side desynchronization or abuse.
- Associate benefit usage with specific entities (level, season, achievement, challenge, skip timer, extra life, bypass question).

### Request Body Format (by Benefit Type)

The request body structure varies based on the benefit type being consumed. The `user_benefit_usages_id` in the URL determines which benefit is being used.

#### 1. Upgrade Level

```json
{
  "use_benefit": true,
  "level_id": 13
}
```

**Rules:**

- `level_id` is the **next level ID** the user is upgrading to.
- Client must determine the next level based on the current level's `order`.
- _Example:_ If current level has `order = 3`, find the level with `order = 4`. The actual IDs may not be sequential.

#### 2. Unlock Achievement

```json
{
  "use_benefit": true,
  "achievement_id": 20
}
```

**Rules:**

- `achievement_id` is the ID of the achievement selected to unlock.
- Must be a valid, locked achievement for the current user.

#### 3. Unlock Season (Stories)

```json
{
  "use_benefit": true,
  "season_id": 20
}
```

**Rules:**

- `season_id` is the ID of the season selected to unlock.
- Must be a valid, locked season for the current user.

#### 4. Unlock Challenge

```json
{
  "use_benefit": true,
  "challenge_id": 60
}
```

**Rules:**

- `challenge_id` is the ID of the challenge selected to unlock.
- Must be a valid, locked challenge for the current user.

#### 5. Consumable Benefits (Extra Lives / Bypass Questions / skip timer)

```json
{
  "use_benefit": true
}
```

**Rules:**

- No additional parameters required.
- Backend decrements remaining count automatically.

---

### Benefit Type to Request Body Mapping

| ID  | Benefit Name       | Required Fields                 |
| --- | ------------------ | ------------------------------- |
| 1   | Upgrade level      | `use_benefit`, `level_id`       |
| 2   | Unlock stories     | `use_benefit`, `season_id`      |
| 3   | Extra lives        | `use_benefit`                   |
| 4   | Skip Timer         | `use_benefit`                   |
| 5   | Bypass Questions   | `use_benefit`                   |
| 6   | Unlock Achievement | `use_benefit`, `achievement_id` |
| 7   | Unlock Challenge   | `use_benefit`, `challenge_id`   |

---

### Response (Success)

```json
{
  "success": true,
  "code": 0,
  "locale": "en",
  "message": "OK",
  "data": {
    "value": "Benefit usage updated successfully"
  }
}
```

### Client Implementation Logic

#### 1. Pre-Action Validation

Before calling this API, the client must:

1. Verify subscription is active (`subscription_expires_at` > current time).
2. Check `can_use = true` for the benefit.
3. Verify `remaining > 0` OR `is_unlimited = true`.

#### 2. Logic Flow Examples

- **Level Upgrade:**
  ```javascript
  if (next_level_exists) {
    await PUT(
      "/api/subscription/user-benefit-usage/" + user - benefit - usage_id,
      {
        use_benefit: true,
        level_id: next_level.id,
      },
    );
  }
  ```
- **Consumables:**
  ```javascript
  await PUT(
    "/api/subscription/user-benefit-usage/" + user - benefit - usage_id,
    {
      use_benefit: true,
    },
  );
  ```

#### 3. Post-Action Requirements

After a successful API response:

- **Refresh Status:** Call `/subscription/user-benefit-status` to get updated counts.
- **Update UI:** Reflect new remaining counts and grant entitlement (unlock, add life, etc.).
- **Consistency:** Never cache benefit counts locally beyond the current session.

---

### Failure Conditions

The API will fail (return `success: false`) if:

- Subscription expired.
- `available_count = 0` (and not unlimited).
- `can_use = false`.
- Invalid ID or Entity ID (e.g., sending `season_id` for a level upgrade).

---

## 11. Final Authority Order

When conflicts exist, resolve in this order:

1. **User Benefit Status API**
2. **User Benefit Usage Update API**
3. **Subscription V2 Package API**
4. **Legacy V1 data** (Ignored)
