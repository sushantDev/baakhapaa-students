# Redesigned Rewards Overlay - Visual Design Mockup

## Overall Layout

```
┌─────────────────────────────────────────────────┐
│  Background: Black with 85% opacity             │
│  ┌───────────────────────────────────────────┐  │
│  │  [X] Close Button (top-right)             │  │
│  │                                           │  │
│  │  ╔═════════════════════════════════════╗  │  │
│  │  ║    EVENT CAROUSEL (if events exist)  ║  │  │
│  │  ║                                       ║  │  │
│  │  ║  ┌─────────────────────────────────┐ ║  │
│  │  ║  │      💰                          │ ║  │
│  │  ║  │  Coins Earned!                   │ ║  │
│  │  ║  │  You earned 50 coins!            │ ║  │
│  │  ║  └─────────────────────────────────┘ ║  │
│  │  ║                                       ║  │
│  │  ║  ● ○ ○  (page indicators)            ║  │
│  │  ║                                       ║  │
│  │  ║  [  🎉  Awesome!  ]  (full-width)    ║  │
│  │  ╚═════════════════════════════════════╝  │  │
│  │                                           │  │
│  │  ╔═══════════════════════════════════╗   │  │
│  │  ║   LEVEL & TASK SECTION            ║   │  │
│  │  ║                                    ║   │  │
│  │  ║   [⭐ Level 4]  →  Level 5        ║   │  │
│  │  ║                                    ║   │  │
│  │  ║   ┌──────────────────────────┐    ║   │  │
│  │  ║   │ 📋 Current Task          │    ║   │  │
│  │  ║   │ Challenge Participation  │    ║   │  │
│  │  ║   │ Complete daily challenges│    ║   │  │
│  │  ║   └──────────────────────────┘    ║   │  │
│  │  ║                                    ║   │  │
│  │  ║   Progress    [████████░░] 2/4    ║   │  │
│  │  ║                                    ║   │  │
│  │  ║   ┌──────────────────────────┐    ║   │  │
│  │  ║   │ 💡 Check new challenges  │    ║   │  │
│  │  ║   │    in Profile section    │    ║   │  │
│  │  ║   └──────────────────────────┘    ║   │  │
│  │  ╚═══════════════════════════════════╝   │  │
│  │                                           │  │
│  │  ╔═══════════════════════════════════╗   │  │
│  │  ║   QUICK ACTIONS                   ║   │  │
│  │  ║                                    ║   │  │
│  │  ║   [🎁 Daily Rewards] [🚩 Go to Task] ║
│  │  ║                                    ║   │  │
│  │  ║   [📈 My Journey (full-width)]    ║   │  │
│  │  ╚═══════════════════════════════════╝   │  │
│  │                                           │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

## Detailed Component Breakdown

### 1. Event Card (when events exist)

```
╔═══════════════════════════════════════════╗
║  Background: Purple → Deep Purple Gradient ║
║  Shadow: Purple glow                       ║
║  Border Radius: 20px                       ║
║                                            ║
║             ┌─────────┐                    ║
║             │   🎉   │  (90x90 circle)     ║
║             └─────────┘                    ║
║                                            ║
║          Level Up!                         ║
║        (24px, bold, white)                 ║
║                                            ║
║   Congratulations! You reached Level 5!   ║
║        (16px, white 90% opacity)           ║
║                                            ║
╚═══════════════════════════════════════════╝
```

### 2. Current Level Badge

```
┌────────────────────────┐
│  ⭐ Level 4            │  <- Golden gradient
│                        │     Amber shadow
└────────────────────────┘     Border radius: 20px
                               Padding: 8px 16px
```

### 3. Task Card

```
┌──────────────────────────────────────┐
│  Background: Black 26% opacity       │
│  Border Radius: 12px                 │
│  Padding: 16px                       │
│                                      │
│  📋 Current Task  (Amber, 14px)      │
│                                      │
│  Challenge Participation             │
│  (White, 16px, semibold)             │
│                                      │
│  Complete daily challenges           │
│  (White 70%, 14px)                   │
└──────────────────────────────────────┘
```

### 4. Progress Bar

```
Progress               2/4
[████████████░░░░░░░░░░░]
 ↑                    ↑
Amber fill        White 12% background
Height: 12px
Border radius: 10px
```

### 5. Hint Section

```
┌──────────────────────────────────────┐
│  Background: Green 30% opacity       │
│  Border: Green accent 30%            │
│  Border Radius: 12px                 │
│                                      │
│  💡 Check new challenges in Profile  │
│     section and participate          │
│     (White, 14px)                    │
└──────────────────────────────────────┘
```

### 6. Quick Action Buttons

**Daily Rewards & Go to Task (side by side)**

```
┌──────────────────┐  ┌──────────────────┐
│  🎁             │  │  🚩              │
│  Daily Rewards  │  │  Go to Task      │
└──────────────────┘  └──────────────────┘
 Amber 20% bg          Purple 20% bg
 Amber border          Purple border
 14px bold             14px bold
```

**My Journey (full width)**

```
┌────────────────────────────────────┐
│          📈 My Journey              │
└────────────────────────────────────┘
 Blue 20% bg, Blue border
 14px bold, Full width
```

### 7. Awesome Button

```
┌────────────────────────────────────┐
│      🎉  Awesome!                   │
└────────────────────────────────────┘
 Background: Amber (solid)
 Foreground: Black
 Icon + Text, 18px bold
 Border radius: 16px
 Elevation: 8
 Full width
```

## Color Specifications

### Primary Colors

- **Amber**: `#FFC107` (CTAs, accents)
- **Dark Background 1**: `#1a1a2e`
- **Dark Background 2**: `#16213e`
- **White**: `#FFFFFF`
- **White 90%**: `rgba(255, 255, 255, 0.9)`
- **White 70%**: `rgba(255, 255, 255, 0.7)`
- **White 12%**: `rgba(255, 255, 255, 0.12)`
- **Black 26%**: `rgba(0, 0, 0, 0.26)`

### Event-Specific Gradients

```
reward_earned:     #388E3C → #1B5E20 (Green shades)
level_upgraded:    #7B1FA2 → #4A148C (Purple shades)
gift_available:    #1976D2 → #006064 (Blue → Cyan)
progress_updated:  #F57C00 → #BF360C (Orange shades)
```

### Section Colors

```
Level Section:     Purple 30% → Deep Purple 30%
                   Border: Purple accent 30%

Task Card:         Black 26%

Hint Section:      Green 30%
                   Border: Green accent 30%

Quick Actions:
  - Daily Rewards: Amber 20%, Amber border 50%
  - Go to Task:    Purple accent 20%, Purple accent border 50%
  - My Journey:    Blue accent 20%, Blue accent border 50%
```

## Dimensions

### Container

- Max Height: 85% screen height
- Max Width: 450px
- Margin: 16px horizontal, 40px vertical
- Border Radius: 28px

### Event Card

- Height: 280px
- Margin: 8px horizontal
- Border Radius: 20px

### Emoji Circle

- Size: 90x90px
- Shape: Circle
- Background: White 20%

### Buttons

- Height: 48px (minimum)
- Border Radius: 12px (quick actions), 16px (awesome button)
- Padding: 16px vertical, 12px horizontal

### Progress Bar

- Height: 12px
- Border Radius: 10px

## Typography

### Headings

- **Event Title**: 24px, Bold, White
- **Level Badge**: 18px, Bold, White
- **Next Level**: 16px, Semi-bold, Purple accent
- **Task Title**: 16px, Semi-bold, White

### Body Text

- **Event Description**: 16px, Regular, White 90%
- **Task Description**: 14px, Regular, White 70%
- **Hint Text**: 14px, Regular, White
- **Button Text**: 14px, Bold (quick actions), 18px Bold (awesome)

### Labels

- **Section Labels**: 14px, Semi-bold, White 70%
- **Progress Label**: 16px, Bold, Amber

## Spacing

### Vertical Spacing

- Between sections: 16-20px
- Inside cards: 12-16px
- Between buttons: 12px
- Event card top margin: 8px

### Horizontal Spacing

- Container padding: 16px
- Card padding: 20px (level section), 16px (task card), 12px (hint)
- Button padding: 12px horizontal

## Shadows & Effects

### Container Shadow

```
color: Amber with 30% opacity
blurRadius: 30px
spreadRadius: 2px
```

### Event Card Shadow

```
color: Event gradient color with 40% opacity
blurRadius: 20px
spreadRadius: 2px
```

### Button Elevation

```
Awesome button: elevation 8
Quick actions: elevation 0 (outlined style)
```

## Animation Specifications

### Entry Animation

```
Type: ScaleTransition
Curve: Curves.elasticOut
Duration: 600ms
Scale: 0 → 1
```

### Page Transition

```
Type: PageView slide
Duration: 300ms
Curve: Curves.easeInOut
```

### Progress Bar Fill

```
Type: LinearProgressIndicator
Animation: Smooth fill (system default)
```

## Responsive Behavior

### Small Screens (<400px)

- Reduce padding to 12px
- Font sizes -2px
- Event card height: 260px

### Large Screens (>450px)

- Max width: 450px (centered)
- Maintain aspect ratio
- Increase margins

## Accessibility

### Contrast Ratios

- White on Dark: 15:1 (AAA)
- Amber on Black: 8:1 (AA)
- Purple on Dark: 4.5:1 (AA)

### Touch Targets

- All buttons: ≥48px height
- Close button: 44x44px
- Page swipe area: 280px height

### Visual Hierarchy

1. Event emoji (largest, centered)
2. Event title (24px)
3. Event description (16px)
4. Awesome button (prominent)
5. Level badge (golden, stands out)
6. Task card (clear structure)
7. Quick actions (equal weight)

## States

### Default

- Full opacity
- All colors as specified
- Shadows visible

### Pressed (buttons)

- Slight scale down (0.95)
- Increased opacity
- Haptic feedback (future)

### Disabled

- 50% opacity
- No shadow
- Cursor: not-allowed

### Loading (future)

- Skeleton loader
- Shimmer effect
- Disabled interactions

## Comparison Table

| Element       | Old Design    | New Design                        |
| ------------- | ------------- | --------------------------------- |
| Background    | White         | Dark gradient (#1a1a2e → #16213e) |
| Container     | Sharp corners | Soft 28px radius                  |
| Colors        | Muted         | Vibrant gradients                 |
| Events        | Single        | Carousel with pagination          |
| Level Display | Text only     | Golden badge with gradient        |
| Progress      | Percentage    | Actual numbers + bar              |
| Hints         | Plain text    | Highlighted box with icon         |
| Buttons       | Basic         | Styled with colors & borders      |
| Dismissal     | Close only    | "Awesome!" per event              |
| Spacing       | Tight         | Generous, breathable              |
| Typography    | Standard      | Hierarchy with bold/regular       |
| Shadows       | Minimal       | Ambient glow effects              |

## Implementation Notes

1. **Dark Mode Only**: Design optimized for dark backgrounds
2. **Gradient Support**: Requires Flutter's LinearGradient widget
3. **Icons**: Using Material Icons from Flutter
4. **Emojis**: Unicode emojis (💰🎉🎁📊💡📋⭐🚩📈)
5. **Animations**: SingleTickerProviderStateMixin for animations
6. **Scrolling**: SingleChildScrollView for overflow content

## Testing Scenarios

### Visual Testing

1. ✅ Single event display
2. ✅ Multiple events with pagination
3. ✅ Long text handling (ellipsis)
4. ✅ Empty events (level/task section only)
5. ✅ Small screen (<400px)
6. ✅ Large screen (>450px)

### Interaction Testing

1. ✅ Awesome button dismisses event
2. ✅ Page swipe works
3. ✅ Quick action buttons navigate
4. ✅ Close button works
5. ✅ Background tap closes
6. ✅ Animations play smoothly

### Data Testing

1. ✅ Real API data displays
2. ✅ Progress updates correctly
3. ✅ Hints from backend
4. ✅ Event descriptions accurate
5. ✅ Multiple simultaneous events

This visual design creates a modern, engaging overlay that motivates users through positive reinforcement and clear visual feedback!
