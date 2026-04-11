# App Localization Update Guide

## Purpose

This document defines a strict process to scan the existing app for non-localized user-facing text, add missing localization keys, and update all supported languages consistently. The goal is zero hardcoded strings in the UI and complete coverage across all languages.

## Scope

- Applies to **all user-facing text**: UI labels, buttons, dialogs, toasts, snackbars, validation messages, empty states, error messages, success messages, and onboarding text.
- Applies to **all platforms** in the app (mobile, web, desktop if applicable).
- Applies to **all supported languages** configured in the app.

## Non‑Negotiable Rules

- No hardcoded user-facing strings in code.
- Every string must have a localization key.
- Every localization key must exist in **all supported languages**.
- Keys must be stable (do not rename casually).
- No duplicate or semantically overlapping keys.

## Step 1: Inventory Supported Languages

1. Identify the source-of-truth localization folder/file.
2. List all supported locales (example):
   - en
   - es
   - fr
   - de
   - hi
   - ne

3. Confirm that each locale has a complete localization file.

## Step 2: Scan the Codebase for Non‑Localized Text

Perform a systematic scan using **all** methods below.

### A. Automated Search

Search for hardcoded strings in UI code:

- Quoted strings (" ", ' ')
- Common UI keywords ("Submit", "Cancel", "Error", "Success", etc.)
- Regex-based search for visible text patterns

Exclude:

- Logs intended only for developers
- Debug-only strings

### B. Manual UI Walkthrough

- Navigate through every screen and flow
- Trigger:
  - Error states
  - Empty states
  - Permission dialogs
  - Network failure messages
  - Success confirmations

- Capture screenshots or notes for every visible string

### C. API & Backend Messages (If Displayed to Users)

- Identify backend messages surfaced directly to users
- Either:
  - Map them to localization keys, or
  - Replace with client-side localized equivalents

## Step 3: Identify Missing or Invalid Localization

For each string found:

- Check if it already exists as a localization key
- Validate:
  - Correct usage of the localization API
  - Correct pluralization and parameter handling

Classify issues as:

- ❌ Hardcoded string
- ⚠️ Existing key but wrong usage
- ⚠️ Key exists in some languages but missing in others

## Step 4: Define New Localization Keys

When adding new keys:

### Naming Rules

- Use descriptive, semantic names
- Group by feature or screen

**Good:**

- `login_button_sign_in`
- `error_network_unavailable`
- `profile_update_success`

**Bad:**

- `text1`
- `message`
- `btn_ok`

### Structure Example

```
feature_context_purpose
```

## Step 5: Update Localization Files (All Languages)

For every new or updated key:

1. Add the key to **every** language file
2. English (or base language) is written first
3. Other languages must:
   - Match meaning, not word-for-word translation
   - Respect cultural tone and grammar

If translation is unavailable:

- Use a **temporary English fallback**
- Mark clearly with a comment for later replacement

## Step 6: Replace Hardcoded Strings in Code

- Replace every hardcoded string with the localization lookup method
- Ensure:
  - Parameters are correctly injected
  - Pluralization rules are used where applicable

No screen should compile with hardcoded user-facing text.

## Step 7: Validation Checklist

Before marking localization as complete:

- [ ] No hardcoded user-facing strings remain
- [ ] All keys exist in all languages
- [ ] App runs without missing-key warnings
- [ ] UI renders correctly in every language
- [ ] Text does not overflow or break layouts

## Step 8: Regression Protection

- Add lint rules or CI checks to block new hardcoded strings
- Enforce localization review in pull requests
- Maintain a single source-of-truth for localization keys

## Common Mistakes to Avoid

- Reusing a key with different meanings
- Adding keys to only one language
- Translating without UI context
- Ignoring plural and gender rules

## Ownership

- Developers: responsible for adding and wiring keys
- Reviewers: responsible for enforcing localization completeness
- Product/QA: responsible for validating UI correctness across languages

## Definition of Done

Localization update is complete only when:

- The app contains **zero** hardcoded user-facing strings
- All supported languages are fully covered
- No missing or fallback strings appear in production
