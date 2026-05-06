# Baakhapaa Application Documentation

## 1. App Overview

**Baakhapaa** is a comprehensive quiz and gamification platform built with Flutter. The application combines educational content delivery with interactive gaming elements, allowing users to engage with quiz-based stories and videos while earning points, unlocking achievements, and participating in social features.

### Key Features

- **Dual Content System**: Long-form stories (episodes in seasons) and short-form content (quick quiz videos)
- **Gamification**: Points system, achievements, leaderboards, and level progression
- **Social Features**: User profiles, following/followers, messaging, and community challenges
- **E-commerce Integration**: In-app shopping for products and virtual goods
- **Creator Economy**: Tools for content creators to produce and monetize quiz content
- **Real-time Features**: Live notifications, rewards, and interactive challenges

## 2. User Roles

### Guest User

- **Access Level**: Limited, read-only
- **Capabilities**:
  - View public stories and shorts
  - Play quizzes without saving progress
  - Browse shop items
  - Cannot earn points or participate in social features
- **Limitations**: Cannot create content, purchase items, or access premium features

### Player (Default Registered User)

- **Access Level**: Full player features
- **Capabilities**:
  - Play all stories and shorts with progress tracking
  - Earn points and unlock achievements
  - Participate in leaderboards and challenges
  - Purchase items from the shop
  - Access social features (follow, message)
  - View and manage profile
- **Progression Path**: Can apply to become a Creator or Vendor

### Creator (StoryTeller)

- **Access Level**: Content creation + player features
- **Capabilities**:
  - All player capabilities
  - Create and manage stories (seasons and episodes)
  - Create and manage shorts with quiz questions
  - Access analytics and performance metrics
  - Monetize content through platform
  - Participate in creator challenges and competitions
- **Requirements**: Application and approval process

### Vendor

- **Access Level**: E-commerce + player features
- **Capabilities**:
  - All player capabilities
  - List and manage products in the shop
  - Process orders and manage inventory
  - Access vendor dashboard and analytics
  - Handle customer service and returns
- **Requirements**: Application and approval process

### Admin

- **Access Level**: Full system access
- **Capabilities**:
  - User management and moderation
  - Content approval and oversight
  - System configuration and maintenance
  - Analytics and reporting
  - Platform-wide feature management

## 3. Screen-by-Screen Breakdown

### Authentication & Onboarding Screens

#### Welcome Screen (`/welcome-screen`)

- **Purpose**: App entry point with branding and initial options
- **Features**: Login/Register buttons, guest access option
- **Access**: All users
- **Navigation**: → Login, Register, or main app (guest)

#### Login Screen (`/login-screen`)

- **Purpose**: User authentication
- **Features**: Email/password login, social login (Google, Apple), forgot password
- **Access**: All users
- **Navigation**: → Main app on success, → Register, → Forgot Password

#### Register Screen (`/register-screen`)

- **Purpose**: New user registration
- **Features**: Account creation form, referral code input
- **Access**: All users
- **Navigation**: → OTP verification, → Login

#### Register with Referral (`/register-with-referral`)

- **Purpose**: Registration with referral code
- **Features**: Pre-filled referral code, account creation
- **Access**: All users
- **Navigation**: → OTP verification

#### Forgot Password (`/forgot_password_screen`)

- **Purpose**: Password recovery
- **Features**: Email input for reset link
- **Access**: All users
- **Navigation**: → OTP verification

#### Verify OTP (`/verify_otp_screen`)

- **Purpose**: OTP verification for registration/password reset
- **Features**: OTP input, resend functionality
- **Access**: All users
- **Navigation**: → Main app (registration) or → Reset password

#### Onboarding Screen (`/onboarding`)

- **Purpose**: New user introduction and tutorial
- **Features**: App feature walkthrough, interactive tutorial
- **Access**: New registered users
- **Navigation**: → Main app

### Main Navigation Screens

#### Story Screen (`/story-screen`) - Home/Stories Tab

- **Purpose**: Main content hub for long-form stories
- **Features**:
  - Featured seasons carousel
  - Continue watching section
  - My list management
  - Creator discovery
  - Search functionality
  - Category browsing
- **Access**: All users
- **Navigation**: → Episode details, → Creator profiles, → Search

#### Shorts Screen (`/shorts-screen`) - Shorts Tab

- **Purpose**: Short-form content and quick quizzes
- **Features**:
  - Video feed with quiz integration
  - Challenge participation
  - Creator shorts discovery
  - Interactive quiz gameplay
- **Access**: All users
- **Navigation**: → Individual shorts, → Challenge details

#### Shop Screen (`/shop-screen`) - Store Tab

- **Purpose**: E-commerce marketplace
- **Features**:
  - Product browsing by categories
  - Search and filtering
  - Cart management
  - Wishlist functionality
- **Access**: All users
- **Navigation**: → Product details, → Cart, → Vendor profiles

#### User Screen (`/user-screen`) - Profile Tab

- **Purpose**: User profile and account management
- **Features**:
  - Profile information display
  - Points and level status
  - Achievement showcase
  - Settings access
  - Social features
- **Access**: Registered users
- **Navigation**: → Edit profile, → Points management, → Settings

### Content Viewing Screens

#### Episode Screen (`/episode_screen`)

- **Purpose**: Individual episode viewing with quiz
- **Features**: Video playback, quiz questions, progress tracking
- **Access**: All users
- **Navigation**: → Question screen, → Win/Lose screens

#### Video Screen (`/video_screen`)

- **Purpose**: Video content playback
- **Features**: Full-screen video player, controls
- **Access**: All users
- **Navigation**: → Quiz questions

#### Question Screen (`/question-screen`)

- **Purpose**: Quiz question interface
- **Features**: Multiple choice questions, timer, scoring
- **Access**: All users
- **Navigation**: → Win/Lose screens

#### Single Shorts Screen (`/single_shorts_screen`)

- **Purpose**: Individual short video viewing
- **Features**: Video playback with integrated quiz
- **Access**: All users
- **Navigation**: → Quiz results

### Game Result Screens

#### Win Screen (`/win-screen`)

- **Purpose**: Success feedback and rewards
- **Features**: Points earned, achievement unlocks, next episode suggestion
- **Access**: All users
- **Navigation**: → Next content, → Leaderboard

#### Lose Screen (`/loose-screen`)

- **Purpose**: Failure feedback with retry options
- **Features**: Score display, retry button, hints
- **Access**: All users
- **Navigation**: → Retry, → Main screen

#### Shorts Win Screen (`/shorts-win-screen`)

- **Purpose**: Short quiz success feedback
- **Features**: Points and rewards display
- **Access**: All users
- **Navigation**: → Next short

#### Shorts Lose Screen (`/shorts-loose-screen`)

- **Purpose**: Short quiz failure feedback
- **Features**: Retry options, score display
- **Access**: All users
- **Navigation**: → Retry

### Creator Tools

#### Creator Story Screen (`/creator_story_screen`)

- **Purpose**: Creator dashboard for content management
- **Features**:
  - Analytics and performance metrics
  - Content library management
  - Earnings tracking
  - Creator challenges
- **Access**: Creators only
- **Navigation**: → Content creation, → Analytics

#### Create Story Type Screen (`/create_story_type_screen`)

- **Purpose**: Choose content type to create
- **Features**: Story vs Shorts selection
- **Access**: Creators only
- **Navigation**: → Story creation or Shorts creation

#### Create Season Screen (`/create_season_screen`)

- **Purpose**: Create new story season
- **Features**: Season metadata input, cover image upload
- **Access**: Creators only
- **Navigation**: → Episode creation

#### Create Episode Screen (`/create_episode_screen`)

- **Purpose**: Create individual episode
- **Features**: Video upload, quiz creation, metadata
- **Access**: Creators only
- **Navigation**: → Question management

#### Manage Episode Questions (`/manage_episode_questions_screen`)

- **Purpose**: Edit quiz questions for episodes
- **Features**: Question CRUD operations
- **Access**: Creators only
- **Navigation**: → Question editor

#### Create Question Screen (`/create_question_screen`)

- **Purpose**: Create individual quiz questions
- **Features**: Question text, options, correct answer selection
- **Access**: Creators only
- **Navigation**: → Back to episode management

#### Create Shorts Screen (`/create_shorts_screen`)

- **Purpose**: Create short-form content
- **Features**: Video recording/upload, quiz integration
- **Access**: Creators only
- **Navigation**: → Preview, → Question creation

#### Drafts Screen (`/drafts_screen`)

- **Purpose**: Manage unpublished content
- **Features**: Draft content listing, edit/delete options
- **Access**: Creators only
- **Navigation**: → Content editor

### Shopping & E-commerce

#### Single Product Screen (`/single_product_screen`)

- **Purpose**: Product details and purchase
- **Features**: Product images, description, pricing, add to cart
- **Access**: All users
- **Navigation**: → Cart, → Checkout

#### Cart Screen (`/cart_screen`)

- **Purpose**: Shopping cart management
- **Features**: Item list, quantity adjustment, total calculation
- **Access**: Registered users
- **Navigation**: → Checkout, → Shop

#### Vendor Product Screen (`/vendor_product_screen`)

- **Purpose**: Vendor's product management dashboard
- **Features**: Product listing, order management, analytics
- **Access**: Vendors only
- **Navigation**: → Product creation, → Order details

#### Create Product Screen (`/create_product_screen`)

- **Purpose**: Add new products to shop
- **Features**: Product form, image upload, pricing, categories
- **Access**: Vendors only
- **Navigation**: → Product list

### User Management

#### Edit Profile Screen (`/edit_profile_screen`)

- **Purpose**: Profile information editing
- **Features**: Avatar upload, personal details, preferences
- **Access**: Registered users
- **Navigation**: → Profile view

#### Points Screen (`/points_screen`)

- **Purpose**: Points management and history
- **Features**: Balance display, transaction history, charts
- **Access**: Registered users
- **Navigation**: → Point logs, → Withdrawal

#### Point Logs Screen (`/point_logs_screen`)

- **Purpose**: Detailed transaction history
- **Features**: Filtered transaction list, search
- **Access**: Registered users
- **Navigation**: → Points screen

#### Levels Screen (`/levels_screen`)

- **Purpose**: Level progression and achievements
- **Features**: Current level, progress bar, unlocked content
- **Access**: Registered users
- **Navigation**: → Achievement details

#### Achievements Screen (`/achievements_screen`)

- **Purpose**: Achievement showcase
- **Features**: Unlocked/locked achievements, progress tracking
- **Access**: Registered users
- **Navigation**: → Achievement details

#### Orders Screen (`/orders_screen`)

- **Purpose**: Purchase history and order tracking
- **Features**: Order status, details, returns
- **Access**: Registered users
- **Navigation**: → Order details

#### Weekly Rewards Screen (`/weekly_rewards_screen`)

- **Purpose**: Weekly reward claiming
- **Features**: Reward calendar, claim buttons
- **Access**: Registered users
- **Navigation**: → Points screen

#### Wallet Auth Screen (`/wallet_auth_screen`)

- **Purpose**: Wallet connection for withdrawals
- **Features**: Khalti integration, authentication
- **Access**: Registered users
- **Navigation**: → Withdrawal process

### Social & Community

#### Leaderboard Screen (`/leaderboard_screen`)

- **Purpose**: User rankings and competition
- **Features**: Global rankings, friend comparisons
- **Access**: Registered users
- **Navigation**: → Player profiles

#### Gift Screen (`/gift_screen`)

- **Purpose**: Virtual gifts and rewards marketplace
- **Features**: Gift browsing, purchasing, sending
- **Access**: Registered users
- **Navigation**: → Gift details

#### Conversations Screen (`/conversations_screen`)

- **Purpose**: Message inbox
- **Features**: Conversation list, unread indicators
- **Access**: Registered users
- **Navigation**: → Individual chats

#### Messages Screen (`/messages_screen`)

- **Purpose**: Individual chat interface
- **Features**: Real-time messaging, media sharing
- **Access**: Registered users
- **Navigation**: → User profiles

#### Player Profile Screen (`/player_profile_screen`)

- **Purpose**: View other users' profiles
- **Features**: Stats, achievements, follow/unfollow
- **Access**: Registered users
- **Navigation**: → Message, → Follow

### Challenges & Competitions

#### Challenges Screen (`/challenges_screen`)

- **Purpose**: Challenge participation hub
- **Features**: Active challenges, leaderboards
- **Access**: All users
- **Navigation**: → Challenge details

#### Challenge Detail Screen (`/challenge_detail_screen`)

- **Purpose**: Individual challenge information
- **Features**: Rules, participants, progress tracking
- **Access**: All users
- **Navigation**: → Challenge participation

#### All Challenges Screen (`/all_challenges_screen`)

- **Purpose**: Browse all available challenges
- **Features**: Challenge filtering, search
- **Access**: All users
- **Navigation**: → Challenge details

### Settings & Support

#### Setting Screen (`/setting_screen`)

- **Purpose**: App preferences and configuration
- **Features**: Language, notifications, privacy settings
- **Access**: Registered users
- **Navigation**: → Various setting screens

#### Profile Privacy Screen (`/profile_privacy_screen`)

- **Purpose**: Privacy settings management
- **Features**: Visibility controls, data sharing preferences
- **Access**: Registered users
- **Navigation**: → Settings

#### Language Screen (`/language_screen`)

- **Purpose**: Language selection
- **Features**: Supported languages, locale switching
- **Access**: All users
- **Navigation**: → Settings

#### Contact Us Screen (`/contact_us_screen`)

- **Purpose**: Customer support
- **Features**: Contact form, FAQ, social links
- **Access**: All users
- **Navigation**: → External links

#### Notification Screen (`/notification_screen`)

- **Purpose**: Notification history and management
- **Features**: Notification list, mark as read
- **Access**: Registered users
- **Navigation**: → Related content

#### Referrals Screen (`/referrals_screen`)

- **Purpose**: Referral program management
- **Features**: Referral code, earnings tracking
- **Access**: Registered users
- **Navigation**: → Share options

### Analytics & Insights

#### Analytics Screen (`/analytics_screen`)

- **Purpose**: Content performance metrics
- **Features**: Views, engagement, earnings reports
- **Access**: Creators and Vendors
- **Navigation**: → Detailed reports

### Utility Screens

#### Search Screen (`/search_screen`)

- **Purpose**: Content and user search
- **Features**: Search bar, filters, results display
- **Access**: All users
- **Navigation**: → Content details

#### Search Product Screen (`/search_product_screen`)

- **Purpose**: Product search functionality
- **Features**: Product search, filtering
- **Access**: All users
- **Navigation**: → Product details

#### Address Screen (`/address_screen`)

- **Purpose**: Shipping address management
- **Features**: Address form, saved addresses
- **Access**: Registered users
- **Navigation**: → Checkout

#### Social Media Screen (`/social_media_screen`)

- **Purpose**: Social account linking
- **Features**: YouTube, Instagram, Facebook integration
- **Access**: Creators
- **Navigation**: → Profile

#### Ads Screen (`/ads_screen`)

- **Purpose**: Advertisement management
- **Features**: Ad preferences, earnings
- **Access**: Registered users
- **Navigation**: → Settings

## 4. Key Features

### Stories/Content Viewing

- **Season-based episodes** with integrated quizzes
- **Progress tracking** and resume functionality
- **Creator discovery** and following system
- **Content categorization** and search
- **Offline viewing** capabilities

### Games/Quizzes

- **Multiple choice questions** with timers
- **Scoring system** with points and bonuses
- **Difficulty levels** and adaptive challenges
- **Instant feedback** and explanations
- **Retry mechanisms** and hints

### Shopping/Products

- **Product marketplace** with categories
- **Secure checkout** via Khalti integration
- **Order tracking** and history
- **Vendor system** for product listing
- **Wishlist and cart** functionality

### Creator Tools

- **Content creation studio** for stories and shorts
- **Quiz builder** with multiple question types
- **Analytics dashboard** for performance tracking
- **Monetization options** through platform
- **Draft management** and publishing tools

### Vendor Dashboard

- **Product management** interface
- **Order processing** and fulfillment
- **Inventory tracking** and analytics
- **Customer service** tools
- **Sales reporting** and insights

### Rewards/Points System

- **Point earning** through gameplay and activities
- **Daily/weekly rewards** calendar
- **Achievement system** with badges
- **Level progression** with unlocks
- **Point conversion** to real currency

### Achievements

- **Badge system** for milestones
- **Progress tracking** with visual indicators
- **Social sharing** of achievements
- **Category-based** achievements (gaming, social, creation)
- **Rare achievements** for special accomplishments

### Social Features

- **User profiles** with stats and achievements
- **Follow/follower system** for networking
- **Real-time messaging** and chat
- **Community challenges** and competitions
- **Referral program** with rewards

## 5. User Flows

### New User Onboarding

1. **App Launch** → Welcome Screen
2. **Registration Choice** → Register/Login/Guest
3. **Account Creation** → Register Screen → OTP Verification
4. **Profile Setup** → Onboarding Tutorial
5. **Content Discovery** → Main App (Stories Tab)

### Player to Creator Progression

1. **Earn Experience** → Play content, earn points
2. **Apply for Creator** → Creator Request Screen
3. **Approval Process** → Admin review
4. **Creator Onboarding** → Content creation tutorial
5. **Content Creation** → Access to creator tools

### Player to Vendor Progression

1. **Build Reputation** → Active participation
2. **Apply for Vendor** → Vendor application process
3. **Business Verification** → Document submission
4. **Vendor Setup** → Product listing training
5. **Shop Management** → Access to vendor dashboard

### Content Creation Workflow

1. **Access Creation** → FAB in main navigation
2. **Content Type Selection** → Story or Shorts
3. **Content Planning** → Season/Episode structure (Stories)
4. **Media Upload** → Video recording or selection
5. **Quiz Creation** → Question builder interface
6. **Preview & Edit** → Draft review and modifications
7. **Publishing** → Content goes live

### Product Listing Workflow

1. **Vendor Dashboard** → Product management section
2. **Product Creation** → Create Product Screen
3. **Media & Details** → Images, description, pricing
4. **Category Assignment** → Product categorization
5. **Publishing** → Product goes live in shop
6. **Order Management** → Monitor sales and fulfill orders

## 6. Navigation Structure

### Bottom Navigation Bar

- **Stories Tab**: Main content hub (episodes, seasons, creators)
- **Shorts Tab**: Short-form content and quick quizzes
- **Store Tab**: E-commerce marketplace
- **Profile Tab**: User account and settings

### Floating Action Button (FAB)

- **Create Content**: Central FAB for content creation
- **Content Type Selection**: Modal bottom sheet for Story/Shorts choice
- **Role-based Access**: Only visible for Creators and Vendors

### Drawer Navigation (Hamburger Menu)

- **User Profile**: Avatar, name, points balance
- **Main Sections**: Stories, Shorts, Shop, Profile
- **Social Links**: Facebook, Messenger, YouTube, Instagram
- **Support**: Contact Us, Settings
- **Account**: Logout, App version

### Tab-based Navigation

- **Shop Tabs**: For You, Categories, Search
- **User Profile Tabs**: Overview, Achievements, Orders
- **Creator Dashboard Tabs**: Content, Analytics, Earnings

### Modal Navigation

- **Content Creation**: Bottom sheet modals for creation flow
- **Settings**: Nested settings screens
- **Product Details**: Full-screen overlays
- **Challenge Participation**: Modal challenge interfaces

## 7. Complete Feature List

### Core Platform Features

- **Dual Content System**: Stories (season-based episodes) and Shorts (quick videos)
- **Interactive Quizzes**: Multiple choice questions with timers and scoring
- **Gamification System**: Points, levels, achievements, and leaderboards
- **E-commerce Marketplace**: Product browsing, purchasing, and vendor management
- **Creator Economy**: Content creation tools and monetization
- **Social Networking**: User profiles, following, messaging, and community features
- **Real-time Notifications**: Pusher integration for live updates
- **Multi-language Support**: Localization (English, Nepali, Chinese)
- **Offline Capabilities**: Content caching and offline viewing

### User Management Features

- **Authentication**: Email/password, social login (Google, Apple), guest access
- **Profile Management**: Avatar upload, personal details, privacy settings
- **Referral System**: User-to-user referrals with rewards
- **Wallet Integration**: Khalti payment gateway for purchases and withdrawals
- **Subscription System**: Premium features and content access

### Content Features

- **Video Playback**: FlickVideoPlayer for stories, MediaKit for shorts
- **Progress Tracking**: Resume watching, completion status
- **Content Discovery**: Search, categories, recommendations
- **Creator Tools**: Video recording, quiz builder, draft management
- **Analytics Dashboard**: Performance metrics for creators and vendors

### Gaming Features

- **Quiz Mechanics**: Timed questions, scoring, hints, retries
- **Challenge System**: Community challenges and competitions
- **Reward System**: Daily/weekly rewards, achievement unlocks
- **Level Progression**: Experience points and level advancement
- **Leaderboards**: Global and friend rankings

### Social Features

- **Messaging System**: Real-time chat with Pusher integration
- **Follow System**: Creator and user following/followers
- **Community Challenges**: Group competitions and events
- **Gift System**: Virtual gifts and rewards marketplace
- **User Profiles**: Stats, achievements, social links

### E-commerce Features

- **Product Catalog**: Category-based browsing and search
- **Shopping Cart**: Add/remove items, quantity management
- **Secure Checkout**: Khalti payment integration
- **Order Management**: Tracking, history, returns
- **Vendor Dashboard**: Product management, sales analytics

### Technical Features

- **State Management**: Provider pattern with multiple specialized providers
- **Real-time Updates**: Pusher for notifications and live features
- **Caching System**: Image and content caching for performance
- **Error Handling**: Sentry integration for crash reporting
- **Analytics**: Clarity (Microsoft) for user behavior tracking
- **Push Notifications**: FCM for device notifications

## 8. Complete Page/Screen List

### Authentication & Onboarding (7 screens)

- Welcome Screen (`/welcome-screen`)
- Login Screen (`/login-screen`)
- Register Screen (`/register-screen`)
- Register with Referral (`/register-with-referral`)
- Forgot Password (`/forgot_password_screen`)
- Verify OTP (`/verify_otp_screen`)
- Onboarding Screen (`/onboarding`)

### Main Navigation (4 screens)

- Story Screen (`/story-screen`) - Stories tab
- Shorts Screen (`/shorts-screen`) - Shorts tab
- Shop Screen (`/shop-screen`) - Store tab
- User Screen (`/user-screen`) - Profile tab

### Content Viewing (4 screens)

- Episode Screen (`/episode_screen`)
- Video Screen (`/video_screen`)
- Question Screen (`/question-screen`)
- Single Shorts Screen (`/single_shorts_screen`)

### Game Results (4 screens)

- Win Screen (`/win-screen`)
- Lose Screen (`/loose-screen`)
- Shorts Win Screen (`/shorts-win-screen`)
- Shorts Lose Screen (`/shorts-loose-screen`)

### Creator Tools (13 screens)

- Creator Story Screen (`/creator_story_screen`)
- Create Story Type Screen (`/create_story_type_screen`)
- Create Season Screen (`/create_season_screen`)
- Create Episode Screen (`/create_episode_screen`)
- View Episodes Screen (`/view_episodes_screen`)
- Manage Episode Questions (`/manage_episode_questions_screen`)
- Create Question Screen (`/create_question_screen`)
- Create Shorts Screen (`/create_shorts_screen`)
- Create Shorts Question Screen (`/create_shorts_question_screen`)
- Create Shorts Question Form (`/create_shorts_question_form`)
- Drafts Screen (`/drafts_screen`)
- Preview Shorts Screen (`/preview_shorts_screen`)
- Camera Recording Screen (`/camera-recording-screen`)
- YouTube Video Selector (`/youtube-video-selector-screen`)

### Shopping & E-commerce (6 screens)

- Single Product Screen (`/single_product_screen`)
- Cart Screen (`/cart_screen`)
- Vendor Product Screen (`/vendor_product_screen`)
- Create Product Screen (`/create_product_screen`)
- Vendor Product Type Screen (`/vendor_product_type_screen`)
- For You Products Screen (`/for_you_products_screen`)
- Tab View Product (`/tab_view_product`)
- Tab View Order (`/tab_view_order`)

### User Management (12 screens)

- Edit Profile Screen (`/edit_profile_screen`)
- Points Screen (`/points_screen`)
- Point Logs Screen (`/point_logs_screen`)
- Levels Screen (`/levels_screen`)
- Achievements Screen (`/achievements_screen`)
- Orders Screen (`/orders_screen`)
- Weekly Rewards Screen (`/weekly_rewards_screen`)
- Wallet Auth Screen (`/wallet_auth_screen`)
- User Details Screen (`/user_details_screen`)
- Address Screen (`/address_screen`)
- Social Media Screen (`/social_media_screen`)
- Language Selector Screen (`/language_screen`)

### Social & Community (7 screens)

- Leaderboard Screen (`/leaderboard_screen`)
- Gift Screen (`/gift_screen`)
- Single Gift Screen (`/single_gift_screen`)
- Conversations Screen (`/conversations_screen`)
- Messages Screen (`/messages_screen`)
- Player Profile Screen (`/player_profile_screen`)
- Chatbot Screen (`/chatbot_screen`)

### Challenges & Competitions (4 screens)

- Challenges Screen (`/challenges_screen`)
- Challenge Detail Screen (`/challenge_detail_screen`)
- All Challenges Screen (`/all_challenges_screen`)
- Challenge Request Screen (`/challenge_request_screen`)

### Settings & Support (6 screens)

- Setting Screen (`/setting_screen`)
- Profile Privacy Screen (`/profile_privacy_screen`)
- Contact Us Screen (`/contact_us_screen`)
- Notification Screen (`/notification_screen`)
- Referrals Screen (`/referrals_screen`)
- Ads Screen (`/ads_screen`)

### Analytics & Insights (1 screen)

- Analytics Screen (`/analytics_screen`)

### Utility & Special (9 screens)

- Search Screen (`/search_screen`)
- Search Product Screen (`/search_product_screen`)
- Discover Screen (`/discover_screen`)
- Creator Request Screen (`/creator_request_screen`)
- Subscription Screen (`/subscription_screen`)
- Creators Screen (`/creators_screen`)
- Level Map Screen (`/level_map_screen`)
- MLBB Registration Screen (`/mlbb_registration_screen`)
- BKP Fortune Wheel (`/bkp_fortune_wheel`)
- Intro Screen (`/intro_screen`)
- Guest Winner Screen (`/guest_win_screen`)
- Affiliate Dashboard Screen (`/affiliate_dashboard_screen`)

**Total Screens: 78**

---

**Version**: 3.0.47+130
**Last Updated**: February 2, 2026
**Platform**: Flutter (iOS/Android)
**Architecture**: Provider pattern with multiple state management providers
