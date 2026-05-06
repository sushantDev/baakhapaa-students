# API Requirements for Stories Feature

This document outlines all API endpoints required for the complete Stories (Seasons & Episodes) feature implementation.

## ✅ Currently Implemented & Working

### Metadata Endpoints (GET)

- **GET `/api/metadata/headings`** - Get all headings for season categorization
- **GET `/api/metadata/genres`** - Get all genres for season categorization
- **GET `/api/metadata/maturities`** - Get all maturity ratings
- **GET `/api/metadata/achievements`** - Get all achievements
- **GET `/api/metadata/products`** - Get all products for episode association
- **GET `/api/metadata/seasons`** - Get all user's seasons

### Content Creation Endpoints (POST)

- **POST `/api/seasons/create`** - Create a new season

  - Multipart form data with video/image uploads
  - Fields: title, description, director, headings[], genres[], maturities[], etc.
  - Returns: Season ID and full season object

- **POST `/api/episodes/create`** - Create a new episode
  - Multipart form data with video/image uploads
  - Fields: title, description, season_id, coins, lives, products[], etc.
  - Returns: Episode ID and full episode object

### Question Management Endpoints

- **POST `/api/questions/create`** - Create question for episode
- **GET `/api/questions/episode/{episodeId}`** - Get all questions for episode
- **PUT `/api/questions/{questionId}`** - Update a question
- **DELETE `/api/questions/{questionId}`** - Delete a question
- **DELETE `/api/questions/answer/{answerId}`** - Delete an answer

---

## 🔴 Required APIs (Not Yet Implemented)

### 1. Seasons List Management

#### GET `/api/seasons/my-seasons`

**Purpose:** Fetch all seasons created by the authenticated user  
**Response:**

```json
{
  "success": true,
  "data": {
    "seasons": [
      {
        "id": 157,
        "title": "Season Title",
        "description": "Season description",
        "trailer_url": "videos/xxx.mov",
        "trailer_source": "upload",
        "is_locked": 1,
        "coin_to_unlock": 100,
        "publish_date": "2025-12-10",
        "images": [...],
        "headings": [...],
        "genres": [...],
        "episodes_count": 5,
        "created_at": "2025-12-09T17:47:01",
        "updated_at": "2025-12-09T17:47:01"
      }
    ],
    "pagination": {
      "current_page": 1,
      "total": 10,
      "per_page": 20
    }
  }
}
```

#### GET `/api/seasons/{seasonId}`

**Purpose:** Get detailed information about a specific season  
**Response:**

```json
{
  "success": true,
  "data": {
    "season": {
      "id": 157,
      "title": "Season Title",
      "description": "...",
      "director": "Director Name",
      "sub_director": "Sub Director",
      "writers": ["Writer 1", "Writer 2"],
      "casts": ["Actor 1", "Actor 2"],
      "trailer_url": "videos/xxx.mov",
      "trailer_source": "upload",
      "headings": [...],
      "genres": [...],
      "maturities": [...],
      "images": [...],
      "episodes": [...]
    }
  }
}
```

#### PUT `/api/seasons/{seasonId}`

**Purpose:** Update season information  
**Request:** Multipart form data (same fields as create)  
**Response:** Updated season object

#### DELETE `/api/seasons/{seasonId}`

**Purpose:** Delete a season and all associated episodes  
**Response:**

```json
{
  "success": true,
  "message": "Season deleted successfully"
}
```

---

### 2. Episodes List Management

#### GET `/api/seasons/{seasonId}/episodes`

**Purpose:** Get all episodes for a specific season  
**Query Params:** `?page=1&per_page=20`  
**Response:**

```json
{
  "success": true,
  "data": {
    "episodes": [
      {
        "id": 234,
        "season_id": 157,
        "title": "Episode 1",
        "description": "Episode description",
        "video_url": "videos/xxx.mov",
        "video_source": "upload",
        "duration": 60,
        "coins": 10,
        "lives": 3,
        "coins_users": 5,
        "publish_date": "2025-12-10",
        "images": [...],
        "products": [...],
        "questions_count": 5,
        "created_at": "2025-12-09T18:00:00"
      }
    ],
    "pagination": {
      "current_page": 1,
      "total": 15,
      "per_page": 20
    }
  }
}
```

#### GET `/api/episodes/{episodeId}`

**Purpose:** Get detailed information about a specific episode  
**Response:**

```json
{
  "success": true,
  "data": {
    "episode": {
      "id": 234,
      "season_id": 157,
      "season": {
        "id": 157,
        "title": "Season Title"
      },
      "title": "Episode 1",
      "description": "Episode description",
      "video_url": "videos/xxx.mov",
      "video_source": "upload",
      "video_description": "Optional description",
      "duration": 60,
      "coins": 10,
      "lives": 3,
      "coins_users": 5,
      "publish_date": "2025-12-10",
      "images": [...],
      "products": [...],
      "questions": [...]
    }
  }
}
```

#### PUT `/api/episodes/{episodeId}`

**Purpose:** Update episode information  
**Request:** Multipart form data (same fields as create)  
**Response:** Updated episode object

#### DELETE `/api/episodes/{episodeId}`

**Purpose:** Delete an episode and all associated questions  
**Response:**

```json
{
  "success": true,
  "message": "Episode deleted successfully"
}
```

---

### 3. Bulk Operations (Optional but Recommended)

#### POST `/api/seasons/{seasonId}/episodes/reorder`

**Purpose:** Reorder episodes within a season  
**Request:**

```json
{
  "episodes": [
    { "id": 234, "order": 1 },
    { "id": 235, "order": 2 },
    { "id": 236, "order": 3 }
  ]
}
```

#### POST `/api/episodes/{episodeId}/questions/reorder`

**Purpose:** Reorder questions within an episode  
**Request:**

```json
{
  "questions": [
    { "id": 45, "order": 1 },
    { "id": 46, "order": 2 }
  ]
}
```

---

### 4. Statistics & Analytics (Optional)

#### GET `/api/seasons/{seasonId}/stats`

**Purpose:** Get season statistics  
**Response:**

```json
{
  "success": true,
  "data": {
    "total_episodes": 15,
    "total_views": 1250,
    "total_questions": 75,
    "completion_rate": 68.5,
    "average_score": 82.3
  }
}
```

#### GET `/api/episodes/{episodeId}/stats`

**Purpose:** Get episode statistics  
**Response:**

```json
{
  "success": true,
  "data": {
    "views": 320,
    "completions": 245,
    "completion_rate": 76.5,
    "questions_count": 5,
    "average_score": 85.2,
    "average_time": 58
  }
}
```

---

## 📋 Implementation Priority

### Phase 1: Essential APIs (Required for MVP)

1. ✅ All metadata endpoints (completed)
2. ✅ Season creation (completed)
3. ✅ Episode creation (completed)
4. 🔴 **GET `/api/seasons/my-seasons`** - List user's seasons
5. 🔴 **GET `/api/seasons/{seasonId}/episodes`** - List episodes for season

### Phase 2: Management APIs (Required for editing)

6. 🔴 **GET `/api/seasons/{seasonId}`** - View season details
7. 🔴 **GET `/api/episodes/{episodeId}`** - View episode details
8. 🔴 **PUT `/api/seasons/{seasonId}`** - Edit season
9. 🔴 **PUT `/api/episodes/{episodeId}`** - Edit episode

### Phase 3: Deletion & Cleanup

10. 🔴 **DELETE `/api/seasons/{seasonId}`** - Delete season
11. 🔴 **DELETE `/api/episodes/{episodeId}`** - Delete episode

### Phase 4: Enhanced Features (Nice to have)

12. 🟡 Reorder APIs
13. 🟡 Statistics APIs
14. 🟡 Search/Filter APIs

---

## 🎯 Immediate Next Steps

To continue development, the backend team needs to implement **Phase 1** APIs:

1. **`GET /api/seasons/my-seasons`** - Absolutely required to show user's created seasons
2. **`GET /api/seasons/{seasonId}/episodes`** - Absolutely required to show episodes in a season

Without these two endpoints, users cannot:

- View their created seasons
- Navigate to episode creation after season creation
- Manage their existing content

---

## 📱 Screens Requiring These APIs

### Seasons List Screen (NEW - needs to be built)

- Requires: `GET /api/seasons/my-seasons`
- Displays: Grid/list of user's seasons with thumbnails, titles, episode counts
- Actions: View, Edit, Delete, Create New

### Season Detail Screen (NEW - needs to be built)

- Requires: `GET /api/seasons/{seasonId}`, `GET /api/seasons/{seasonId}/episodes`
- Displays: Season info, episodes list
- Actions: Edit Season, Add Episode, Edit/Delete Episodes

### Episode List Screen (Partial - currently empty)

- Requires: `GET /api/seasons/{seasonId}/episodes`
- Displays: List of episodes for selected season
- Actions: View, Edit, Delete, Create New, Reorder

### Episode Detail Screen (NEW - needs to be built)

- Requires: `GET /api/episodes/{episodeId}`
- Displays: Episode info, questions list
- Actions: Edit Episode, Add/Edit/Delete Questions

---

## 🔧 Current Status

**Working:**

- ✅ Metadata fetching from individual endpoints
- ✅ Season creation with file uploads
- ✅ Episode creation with file uploads
- ✅ Question CRUD operations
- ✅ Navigation from season creation → episode creation

**Blocked (waiting for backend APIs):**

- ❌ Viewing list of created seasons
- ❌ Viewing episodes for a season
- ❌ Editing existing seasons/episodes
- ❌ Deleting seasons/episodes

---

## 📝 Notes for Backend Team

1. All list endpoints should support pagination
2. Response format should be consistent across all endpoints
3. Include proper error messages and HTTP status codes
4. File uploads should return full URLs in responses
5. Consider adding search/filter query parameters to list endpoints
6. Soft delete is recommended for seasons/episodes (preserve data)
