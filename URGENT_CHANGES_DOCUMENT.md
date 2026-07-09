# iCare — Urgent UI Changes Document

---

## Change 1: Public Home Page — Redesign Based on OlaDoc Style

### Reference / Inspiration

> 📸 **[Screenshot: OlaDoc Home Page — https://oladoc.com]**
>
> *(Take a screenshot of oladoc.com homepage and add it here)*

The new iCare public home page should follow the same style and layout approach as OlaDoc's homepage.

---

### Current State of iCare Public Home

The current `public_home.dart` has only **one button** in the top navbar:
- `Sign In` (right side only)

---

### Required Change

The top navbar should have **3 buttons** on the top right, in place of where Sign In currently sits:

```
[ Sign In ]  [ Sign Up ]  [ Work With Us ]
```

| Button | Action |
|---|---|
| **Sign In** | Opens the existing login screen |
| **Sign Up** | Opens patient-only signup |
| **Work With Us** | Opens professional signup — Doctor, Pharmacy, Lab only |

---

### Sign Up Button — Patients Only
- Normal Sign Up opens signup for **patients only**
- All other roles (Doctor, Pharmacy, Lab, Student) are removed from this flow
- Currently when Sign Up is clicked, Doctor and Pharmacy options also appear — those need to be removed

---

### Work With Us Button — Professionals Only
- Clicking Work With Us opens a role selection with exactly **3 options**:
  - Doctor
  - Pharmacy
  - Lab
- **Student is NOT included** in Work With Us

---

### Student Role — No Signup Required
Student has no signup screen anywhere — not in Sign Up, not in Work With Us.
Student access is handled internally. After login, students are taken directly to LMS / My Courses. No separate signup flow is needed for students.

---

### Files to Modify
- `lib/screens/public_home.dart`
- `lib/screens/select_user_type.dart`
- `lib/screens/signup.dart`

---

---

## Change 2: Post-Login Home Page — Remove Right-Side Panel

### Current State

> 📸 **[Screenshot: Current Post-Login Dashboard]**
>
> *(Take a screenshot of the dashboard after login and add it here)*

After login, the home screen currently shows a right-hand side panel with a long list of details — My Appointments, Reports, and many other items.

---

### Required Change

- The entire right-hand side details panel is to be **removed completely**
- All those items (My Appointments, Reports, etc.) already exist in the left-side navigation — so they do not need to appear on the home page again
- After login, the home page should show the **same layout as the public home page** (the one visible before login)
- The only addition after login will be the **left-side navigation drawer**

---

### Files to Modify
- `lib/screens/home.dart` (or whichever screen loads after login)

---

---

## Change 3: Left Navigation Drawer — Remove Top Section

### Required Change

Remove everything above the navigation list in the drawer:

- ❌ Heart / dil icon — remove
- ❌ "iCare" text — remove
- ❌ Profile photo circle — remove
- ❌ Edit icon on profile — remove
- ❌ User name — remove
- ❌ User email — remove
- ❌ "My Reports" label or any label above the navigation list — remove

What stays / changes:
- ✅ iCare **logo image only** (`logo.png`) at the very top — no text beside it, no icon beside it
- ✅ Navigation section label renamed to **"My Account"**
- ✅ All navigation items remain exactly as they are

---

### Files to Modify
- `lib/navigators/drawer.dart`

---

---

## Change 4: Profile — Remove Duplicate, Keep Top-Right Only

### Required Change

Profile is currently appearing in **2 places**:
1. Top-right corner of the main screen
2. Inside the left drawer (profile photo + name + email)

- Once the right-side panel is removed (Change 2), the top-right profile that was on the home page will also be gone
- The drawer profile (photo + name + email) also needs to be removed (covered in Change 3)
- **Only the top-right profile icon remains** — nothing else

---

### Files to Modify
- `lib/navigators/drawer.dart`

---

---

## Summary

| # | Change | Files | Status |
|---|--------|-------|--------|
| 1 | Redesign public home like OlaDoc, add Sign In + Sign Up + Work With Us to navbar | `public_home.dart`, `select_user_type.dart`, `signup.dart` | ⏳ Pending |
| 2 | Remove right-side details panel after login, show public home layout | `home.dart` | ⏳ Pending |
| 3 | Remove drawer top section (heart icon, iCare text, profile, name, email), keep only logo, rename nav to "My Account" | `drawer.dart` | ⏳ Pending |
| 4 | Remove profile from drawer, keep only top-right profile icon | `drawer.dart` | ⏳ Pending (part of Change 3) |

---

## Screenshots Needed

| Location | Screenshot |
|---|---|
| Change 1 — Reference | OlaDoc homepage: https://oladoc.com |
| Change 2 — Current State | iCare post-login dashboard |

---

*Add the actual screenshots in the marked placeholders before developer handoff.*
