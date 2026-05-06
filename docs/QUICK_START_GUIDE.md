# Quick Start Guide - Dual Content Creation

## For Users

### How to Create Shorts (Quick Videos)

1. Tap the **"+"** button at the bottom center of the app
2. A modal will appear with two options
3. Select **"Create Shorts"** (icon: video camera)
4. Record or select your video
5. Add title, description, and quiz questions
6. Submit your short!

### How to Create a Season (New Series)

1. Tap the **"+"** button at the bottom center of the app
2. Select **"Create Stories"** (icon: play circle)
3. Choose **"Create Season"**
4. Fill in season details:
   - Title and description
   - Director information
   - Upload cover image
   - Upload trailer video OR paste YouTube URL
   - Select categories (genres, maturity ratings, etc.)
   - Configure settings (locked/unlocked, skip options)
   - Set publish date
5. Tap **"Create Season"** button
6. Your season is now created and ready for episodes!

### How to Create an Episode

1. Tap the **"+"** button at the bottom center of the app
2. Select **"Create Stories"** (icon: play circle)
3. Choose **"Create Episode"**
4. Fill in episode details:
   - Select parent season from dropdown
   - Enter title and description
   - Upload video OR paste YouTube URL
   - Upload thumbnail image (optional)
   - Set game parameters (coins, lives, duration)
   - Select related products (optional)
   - Set publish date
5. Tap **"Create Episode"** button
6. Your episode is created! (You can add quiz questions later)

## For Developers

### Testing the Flow

#### Test Content Type Selector

```dart
// Navigate from anywhere
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (context) => const ContentTypeSelectorSheet(),
);
```

#### Test Season Creation

```dart
Navigator.of(context).pushNamed(CreateSeasonScreen.routeName);
```

#### Test Episode Creation

```dart
Navigator.of(context).pushNamed(CreateEpisodeScreen.routeName);
```

### Code Locations

**Entry Point:** `lib/widgets/footer.dart` - `_toggleDial()` method (line ~180)

**Content Selector:** `lib/widgets/content_type_selector_sheet.dart`

**Story Type Screen:** `lib/screens/create/story/create_story_type_screen.dart`

**Season Creation:** `lib/screens/create/story/create_season_screen.dart`

**Episode Creation:** `lib/screens/create/story/create_episode_screen.dart`

**API Provider:** `lib/providers/story_creation.dart`

### Debugging Tips

#### Enable Debug Logs

The `DebugLogger` utility is used throughout. Enable verbose logging to see API requests/responses:

```dart
DebugLogger.info('Message');
DebugLogger.error('Error');
DebugLogger.success('Success');
```

#### Check API Responses

All API calls in `story_creation.dart` log responses. Look for:

- `📊 Fetching metadata...`
- `🎬 Creating season...`
- `📺 Creating episode...`
- `✅ Success messages`
- `❌ Error messages`

#### Test Metadata Loading

```dart
final storyCreation = Provider.of<StoryCreation>(context, listen: false);

// Load season metadata
await storyCreation.fetchSeasonMetadata();
print('Headings: ${storyCreation.headings.length}');
print('Genres: ${storyCreation.genres.length}');

// Load episode metadata
await storyCreation.fetchEpisodeMetadata();
print('Seasons: ${storyCreation.seasons.length}');
print('Products: ${storyCreation.products.length}');
```

### Common Issues & Solutions

#### Issue: "Failed to load metadata"

**Cause:** API endpoint not responding or auth token expired
**Solution:**

1. Check network connection
2. Verify auth token in Auth provider
3. Check API endpoint URL in `models/url.dart`

#### Issue: "No seasons available" in episode creation

**Cause:** No seasons created yet
**Solution:** Create a season first before creating episodes

#### Issue: Video upload fails

**Cause:** File size too large or network timeout
**Solution:**

1. Check file size (200MB for season trailers, 1GB for episodes)
2. Use YouTube URL as alternative
3. Compress video before upload

#### Issue: Image picker not working

**Cause:** Missing permissions
**Solution:**

1. iOS: Check Info.plist for camera/photo permissions
2. Android: Check AndroidManifest.xml for storage permissions

#### Issue: Form validation fails

**Cause:** Required fields not filled
**Solution:**

- Season requires: title, description, director, image, trailer, at least 1 heading, 1 genre, 1 maturity
- Episode requires: season selection, title, description, video, game settings

### API Testing

#### Test Season Creation

```bash
curl -X POST "https://your-api.com/api/seasons/create" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "title=Test Season" \
  -F "description=Test Description" \
  -F "director=Test Director" \
  -F "headings=[1,2]" \
  -F "genres=[1]" \
  -F "maturities=[1]" \
  -F "is_jump_available=0" \
  -F "is_locked=0" \
  -F "publish_date=2024-12-31" \
  -F "trailer_url=https://youtube.com/watch?v=test"
```

#### Test Episode Creation

```bash
curl -X POST "https://your-api.com/api/episodes/create" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "title=Test Episode" \
  -F "description=Test Description" \
  -F "season_id=1" \
  -F "coins=10" \
  -F "lives=3" \
  -F "coins_users=0" \
  -F "duration=60" \
  -F "products=[]" \
  -F "publish_date=2024-12-31" \
  -F "video_url=https://youtube.com/watch?v=test"
```

### Performance Monitoring

#### Image Compression Settings

```dart
final XFile? image = await picker.pickImage(
  source: ImageSource.gallery,
  maxWidth: 1920,    // Resize to max width
  maxHeight: 1080,   // Resize to max height
  imageQuality: 85,  // 85% quality (good balance)
);
```

#### File Size Checks

```dart
final file = File(image.path);
final fileSize = await file.length();

// Season trailer: 200MB
if (fileSize > 200 * 1024 * 1024) {
  // Show error
}

// Episode video: 1GB
if (fileSize > 1024 * 1024 * 1024) {
  // Show error
}

// Image: 10MB
if (fileSize > 10 * 1024 * 1024) {
  // Show error
}
```

### Future Enhancements Roadmap

**Phase 1: Question Management (Next)**

- Create episode questions screen
- Edit/delete questions
- Reorder questions
- Question preview

**Phase 2: Preview Screens**

- Season preview before submission
- Episode preview before submission
- Video player integration
- Edit after preview

**Phase 3: Advanced Media**

- Video trimming
- Image cropping
- Thumbnail selection from video
- Video compression
- Multiple image upload

**Phase 4: Drafts & Offline**

- Save as draft
- Resume from draft
- Offline mode support
- Auto-save progress

**Phase 5: Analytics**

- Creation analytics
- User engagement metrics
- Performance tracking
- A/B testing

### Contributing

When adding new features to this system:

1. **Follow the pattern:**

   - Add methods to `StoryCreation` provider
   - Create new screen in `lib/screens/create/story/`
   - Add route to `main.dart`
   - Update navigation in appropriate screen

2. **Maintain consistency:**

   - Use same form validation approach
   - Follow same error handling pattern
   - Use DebugLogger for logging
   - Show snackbars for user feedback

3. **Test thoroughly:**

   - Run `flutter analyze`
   - Test on iOS and Android
   - Test with/without network
   - Test with invalid data
   - Test edge cases

4. **Document:**
   - Add JSDoc comments to methods
   - Update this guide
   - Update implementation summary
   - Add examples

### Support

For issues or questions:

1. Check debug logs first
2. Review API documentation in `STORIES_API_INTEGRATION_PLAN.md`
3. Check implementation details in `DUAL_CONTENT_CREATION_IMPLEMENTATION.md`
4. Search existing issues
5. Create new issue with:
   - Flutter version
   - Device/OS
   - Steps to reproduce
   - Error logs
   - Expected vs actual behavior
