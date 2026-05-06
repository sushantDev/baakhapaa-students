# Stories API Integration Plan

## Overview

This document outlines the required API endpoints and architectural changes needed to support Stories creation alongside Shorts in the Baakhapaa app.

---

## 📁 File Structure Reorganization

### Current Structure (Needs Change)

```
lib/screens/shorts/create/
├── camera_recording_screen.dart
├── create_shorts_screen.dart
├── drafts_screen.dart
├── preview_shorts_screen.dart
├── create_shorts_question_form_screen.dart
├── create_shorts_question_screen.dart
└── youtube_video_selector_screen.dart
```

### Recommended New Structure

```
lib/screens/create/  (NEW - unified content creation)
├── camera_recording_screen.dart
├── create_content_screen.dart (renamed from create_shorts_screen.dart)
├── drafts_screen.dart
├── preview_content_screen.dart (renamed from preview_shorts_screen.dart)
├── create_question_form_screen.dart
├── create_question_screen.dart
└── youtube_video_selector_screen.dart

lib/screens/shorts/
└── (keep shorts-specific viewing screens only)

lib/screens/story/
└── (keep story-specific viewing screens only)
```

---

## 🔌 Required Backend API Endpoints

### 1. **Stories Upload Endpoint**

**Endpoint:** `POST /stories/create` or `POST /v2/stories/create`

**Request Format:**

- **Method:** `POST` with `multipart/form-data`
- **Headers:**
  - `Authorization: Bearer {token}`
  - `Content-Type: multipart/form-data`

**Request Body:**

```json
{
  "video": "<File>",
  "title": "string",
  "description": "string",
  "story_topic_id": "integer", // Similar to shorts_topic_id
  "duration": "integer", // Story duration in seconds
  "visibility": "string", // "public", "friends", "private"
  "expires_in": "integer" // Hours before story expires (24h default)
}
```

**Response Format:**

```json
{
  "success": true,
  "message": "Story created successfully",
  "data": {
    "value": 123, // Newly created story ID
    "story": {
      "id": 123,
      "title": "My Story",
      "description": "Story description",
      "video_url": "https://...",
      "thumbnail_url": "https://...",
      "created_at": "2025-12-05T10:00:00Z",
      "expires_at": "2025-12-06T10:00:00Z",
      "views_count": 0
    }
  }
}
```

---

### 2. **Story Topics/Categories Endpoint**

**Endpoint:** `GET /stories/topics` or `GET /v2/stories/topics`

**Response Format:**

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": 1,
        "title": "Daily Life",
        "icon": "https://...",
        "color": "#FF5722"
      },
      {
        "id": 2,
        "title": "Travel",
        "icon": "https://...",
        "color": "#2196F3"
      }
    ]
  }
}
```

---

### 3. **Fetch Stories Endpoint**

**Endpoint:** `GET /v2/stories` or `GET /stories`

**Query Parameters:**

- `page` (integer) - Page number for pagination
- `filter` (string) - "latest", "trending", "following"
- `user_id` (integer) - Optional, for user-specific stories

**Response Format:**

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": 123,
        "user": {
          "id": 456,
          "username": "john_doe",
          "profile_image": "https://..."
        },
        "title": "My Story",
        "video_url": "https://...",
        "thumbnail_url": "https://...",
        "views_count": 150,
        "created_at": "2025-12-05T10:00:00Z",
        "expires_at": "2025-12-06T10:00:00Z",
        "is_expired": false
      }
    ],
    "pagination": {
      "current_page": 1,
      "total_pages": 5,
      "per_page": 20,
      "total_items": 100
    }
  }
}
```

---

### 4. **Delete Story Endpoint** (Optional but recommended)

**Endpoint:** `DELETE /stories/{story_id}` or `DELETE /v2/stories/{story_id}`

**Response Format:**

```json
{
  "success": true,
  "message": "Story deleted successfully"
}
```

---

### 5. **Story Views Tracking Endpoint**

**Endpoint:** `POST /stories/{story_id}/view`

**Response Format:**

```json
{
  "success": true,
  "data": {
    "views_count": 151
  }
}
```

---

## 🔧 Required Code Changes

### 1. **Provider Updates**

#### Create New `StoryProvider` or Extend `Story` Provider

**File:** `lib/providers/story.dart`

**Add Methods:**

```dart
// Upload story
Future<void> uploadStory(Map<String, dynamic> storyData, File video) async {
  try {
    final url = Uri.parse(Url.baakhapaaApi('/stories/create'));

    var request = http.MultipartRequest('POST', url);
    request.files.add(await http.MultipartFile.fromPath('video', video.path));
    request.fields['title'] = storyData['title'].toString();
    request.fields['description'] = storyData['description'].toString();
    request.fields['story_topic_id'] = storyData['story_topic_id'].toString();
    request.fields['duration'] = storyData['duration'].toString();
    request.fields['visibility'] = storyData['visibility'] ?? 'public';
    request.fields['expires_in'] = storyData['expires_in']?.toString() ?? '24';
    request.headers.addAll(Url.baakhapaaAuthHeadersWithFiles(authToken));

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      final responseData = json.decode(responseBody);
      _newlyCreatedStoryId = responseData['data']['value'];
      notifyListeners();
    } else {
      String errorMessage = await utf8.decodeStream(response.stream);
      throw 'Could not create story. $errorMessage';
    }
  } catch (error) {
    throw error;
  }
}

// Fetch story topics
Future<void> fetchStoryTopics() async {
  try {
    final response = await http.get(
      Uri.parse(Url.baakhapaaApi('/stories/topics')),
      headers: Url.baakhapaaAuthHeaders(authToken),
    );

    var responseData = json.decode(utf8.decode((response.bodyBytes)));
    if (responseData['success']) {
      _storyTopics = responseData['data']['items'];
      notifyListeners();
    }
  } catch (error) {
    throw error;
  }
}

// Fetch user stories
Future<void> fetchUserStories() async {
  try {
    final response = await http.get(
      Uri.parse(Url.baakhapaaApi('/v2/stories')),
      headers: Url.baakhapaaAuthHeaders(authToken),
    );

    var responseData = json.decode(utf8.decode((response.bodyBytes)));
    if (responseData['success']) {
      _userStories = responseData['data']['items'];
      notifyListeners();
    }
  } catch (error) {
    throw error;
  }
}

// Delete story
Future<void> deleteStory(int storyId) async {
  try {
    final response = await http.delete(
      Uri.parse(Url.baakhapaaApi('/stories/$storyId')),
      headers: Url.baakhapaaAuthHeaders(authToken),
    );

    var responseData = json.decode(utf8.decode((response.bodyBytes)));
    if (responseData['success']) {
      _userStories.removeWhere((story) => story['id'] == storyId);
      notifyListeners();
    }
  } catch (error) {
    throw error;
  }
}
```

---

### 2. **Rename and Update Create Screen**

**File:** `lib/screens/create/create_content_screen.dart` (renamed from create_shorts_screen.dart)

**Key Changes:**

- Already has `_contentType` state variable ✅
- Already passes `content_type` to preview screen ✅
- Update UI text to reflect "Create Content" instead of "Create Shorts"
- Dynamically load topics based on content type

**Update `didChangeDependencies` method:**

```dart
@override
void didChangeDependencies() {
  if (!_isInit) {
    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    if (rawArgs is Map<String, dynamic>) {
      _isChallenge = rawArgs['is_challenge'] as bool?;
      // Check if content type was passed from navigation
      _contentType = rawArgs['content_type'] ?? 'shorts';
    }

    // Fetch topics based on content type
    if (_contentType == 'stories') {
      Provider.of<Story>(context, listen: false).fetchStoryTopics();
    } else {
      Provider.of<Shorts>(context, listen: false).fetchShortsTopic();
    }

    _isInit = true;
  }
  super.didChangeDependencies();
}
```

**Update category loading in build method:**

```dart
final topics = _contentType == 'stories'
    ? Provider.of<Story>(context).storyTopics
    : Provider.of<Shorts>(context).shortsTopic;
```

---

### 3. **Update Preview Screen**

**File:** `lib/screens/create/preview_content_screen.dart` (renamed from preview_shorts_screen.dart)

**Key Changes:**

```dart
Future<void> _uploadContent() async {
  // ... existing validation code ...

  final contentType = args['content_type'] ?? 'shorts';

  if (contentType == 'stories') {
    // Upload as story
    final storyProvider = Provider.of<Story>(context, listen: false);
    final storyData = {
      'title': args['title'],
      'description': args['description'],
      'story_topic_id': args['shorts_topic_id'], // Keep key name for compatibility
      'duration': await _getVideoDuration(videoFile),
      'visibility': args['visibility'] ?? 'public',
      'expires_in': args['expires_in'] ?? 24,
    };

    await storyProvider.uploadStory(storyData, videoFile);

    // Navigate to story screen after upload
    Navigator.of(context).pushReplacementNamed(StoryScreen.routeName);

  } else {
    // Upload as shorts (existing logic)
    await shortsProvider.uploadShorts(formData, videoFile);
    // ... existing MCQ logic ...
  }
}
```

---

### 4. **Update Routing**

**File:** `lib/main.dart` or route configuration file

```dart
// Old routes
CreateShortsScreen.routeName: (ctx) => CreateShortsScreen(),
PreviewShortsScreen.routeName: (ctx) => PreviewShortsScreen(),

// New routes (update imports too)
CreateContentScreen.routeName: (ctx) => CreateContentScreen(),
PreviewContentScreen.routeName: (ctx) => PreviewContentScreen(),
```

---

### 5. **Move Files to New Location**

**Terminal Commands:**

```bash
# Create new create directory
mkdir -p lib/screens/create

# Move files from shorts/create to screens/create
mv lib/screens/shorts/create/camera_recording_screen.dart lib/screens/create/
mv lib/screens/shorts/create/create_shorts_screen.dart lib/screens/create/create_content_screen.dart
mv lib/screens/shorts/create/drafts_screen.dart lib/screens/create/
mv lib/screens/shorts/create/preview_shorts_screen.dart lib/screens/create/preview_content_screen.dart
mv lib/screens/shorts/create/create_shorts_question_form_screen.dart lib/screens/create/create_question_form_screen.dart
mv lib/screens/shorts/create/create_shorts_question_screen.dart lib/screens/create/create_question_screen.dart
mv lib/screens/shorts/create/youtube_video_selector_screen.dart lib/screens/create/

# Remove old directory
rmdir lib/screens/shorts/create
```

**After moving, update all imports in these files:**

```dart
// Old import
import 'package:baakhapaa/screens/shorts/create/create_shorts_screen.dart';

// New import
import 'package:baakhapaa/screens/create/create_content_screen.dart';
```

---

## 📊 Database Schema Recommendations

### Stories Table

```sql
CREATE TABLE stories (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  video_url VARCHAR(500) NOT NULL,
  thumbnail_url VARCHAR(500),
  story_topic_id INT,
  duration INT, -- in seconds
  visibility ENUM('public', 'friends', 'private') DEFAULT 'public',
  views_count INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP, -- Auto-calculated: created_at + expires_in hours
  is_expired BOOLEAN DEFAULT FALSE,
  INDEX idx_user_id (user_id),
  INDEX idx_created_at (created_at),
  INDEX idx_expires_at (expires_at),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (story_topic_id) REFERENCES story_topics(id) ON DELETE SET NULL
);

CREATE TABLE story_topics (
  id INT PRIMARY KEY AUTO_INCREMENT,
  title VARCHAR(100) NOT NULL,
  icon VARCHAR(255),
  color VARCHAR(20),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE story_views (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  story_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  viewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_view (story_id, user_id),
  FOREIGN KEY (story_id) REFERENCES stories(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

---

## 🚀 Implementation Priority

### Phase 1: Backend Setup (High Priority)

1. ✅ Create stories database tables
2. ✅ Implement `POST /stories/create` endpoint
3. ✅ Implement `GET /stories/topics` endpoint
4. ✅ Implement `GET /v2/stories` endpoint
5. ✅ Set up automated story expiration (cron job or scheduled task)

### Phase 2: File Reorganization (Medium Priority)

1. ✅ Create `lib/screens/create/` directory
2. ✅ Move and rename files
3. ✅ Update all imports across the project
4. ✅ Update routing configuration

### Phase 3: Provider Implementation (High Priority)

1. ✅ Add story upload method to Story provider
2. ✅ Add story topics fetching method
3. ✅ Add story listing method
4. ✅ Add story deletion method

### Phase 4: UI Updates (Medium Priority)

1. ✅ Update create_content_screen.dart to handle both types
2. ✅ Update preview_content_screen.dart to handle both uploads
3. ✅ Test content type switching
4. ✅ Update localization strings

### Phase 5: Testing (High Priority)

1. ✅ Test story upload flow end-to-end
2. ✅ Test shorts upload flow (regression testing)
3. ✅ Test content type switching
4. ✅ Test story expiration logic
5. ✅ Test API error handling

---

## 🔐 Security Considerations

1. **File Upload Validation:**

   - Max file size limit (e.g., 100MB for stories)
   - Allowed video formats (mp4, mov, etc.)
   - Scan for malicious content

2. **Rate Limiting:**

   - Limit stories per user per day (e.g., 10 stories/day)
   - Prevent spam uploads

3. **Content Moderation:**

   - Implement content flagging system
   - Auto-moderation for inappropriate content

4. **Privacy:**
   - Respect visibility settings
   - Allow users to control who can view their stories

---

## 📱 Frontend Considerations

### Story-Specific Features to Consider:

1. **Story Expiration Timer:** Show countdown before story expires
2. **Story Viewers List:** Show who viewed the story (like Instagram)
3. **Story Highlights:** Option to save stories permanently
4. **Story Replies:** Allow users to reply to stories via DM
5. **Story Reactions:** Quick emoji reactions to stories

---

## 🧪 Testing Checklist

- [ ] Backend API endpoints work correctly
- [ ] File upload works for both shorts and stories
- [ ] Content type switching works in UI
- [ ] Topics load correctly based on content type
- [ ] Preview screen uploads to correct endpoint
- [ ] Stories expire correctly after 24 hours
- [ ] Navigation works after file reorganization
- [ ] No broken imports after file moves
- [ ] Draft system works for both content types
- [ ] Error handling works for both types

---

## 📞 Support Contact

For questions about this implementation plan, contact:

- Backend Team: [backend@baakhapaa.com]
- Frontend Team: [frontend@baakhapaa.com]

---

**Last Updated:** December 5, 2025
**Version:** 1.0
