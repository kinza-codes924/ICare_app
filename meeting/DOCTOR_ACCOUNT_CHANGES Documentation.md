# Doctor Account — UI Changes Documentation

**Role Affected:** Doctor  
**Prepared For:** Development Team

## Summary of All Changes

| **#** | **Change** | **File(s) Affected** | **Status** |
| --- | --- | --- | --- |
| 1   | Sidebar "NAVIGATION" label → "MY ACCOUNT" | lib/navigators/drawer.dart | <span style="color:green">**[DONE]**</span> Done |
| 2   | Sidebar: Remove heart icon quick action, "View Lab Reports", "iCare" text, "PRO" text | lib/navigators/drawer.dart | <span style="color:green">**[DONE]**</span> Done |
| 3   | Sidebar: Remove Logout button from bottom | lib/navigators/drawer.dart | <span style="color:green">**[DONE]**</span> Done |
| 4   | Sidebar: Remove doctor name + image from header | lib/navigators/drawer.dart | <span style="color:green">**[DONE]**</span> Done |
| 5   | Sidebar: Remove "QUICK ACTIONS" section label | lib/navigators/drawer.dart | <span style="color:green">**[DONE]**</span> Done |
| 6   | Logout button → place in profile icon dropdown (Edit Profile + Logout) | lib/screens/home.dart, profile_edit.dart | <span style="color:red">**[PENDING]**</span> Pending (client revised: dropdown, not inside Edit Profile page) |
| 7   | Dashboard: "Clinical Audit" → rename to "Quality Score" | lib/screens/doctor_dashboard.dart | <span style="color:green">**[DONE]**</span> Done |
| 8   | Dashboard: Remove "Care Programs" card | lib/screens/doctor_dashboard.dart | <span style="color:green">**[DONE]**</span> Done |
| 9   | Credential Vault: "Credential Vault" → rename to "Certificate" + change icon | lib/screens/credential_vault_screen.dart | <span style="color:green">**[DONE]**</span> Done |
| 10  | Help Center: Phone number → +923068961564 | lib/screens/help_and_support.dart | <span style="color:green">**[DONE]**</span> Done |
| 11  | Settings: Remove "Danger Zone" section | lib/screens/settings.dart | <span style="color:green">**[DONE]**</span> Done |
| 12  | Settings: Remove "Subscription Plan" item | lib/screens/settings.dart | <span style="color:green">**[DONE]**</span> Done |

## <span style="color:green">**[DONE]**</span> Change 1 — Sidebar: Rename "NAVIGATION" → "MY ACCOUNT"

**File:** lib/navigators/drawer.dart

**Location:** Inside the ListView under if (selectedRole != 'Admin') block.

**Before:**

  
Padding(  
padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),  
child: CustomText(  
text: "NAVIGATION",  
fontSize: 11,  
fontWeight: FontWeight.w900,  
color: const Color(0xFF94A3B8),  
letterSpacing: 1.5,  
),  
),  

**After:**

  
Padding(  
padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),  
child: CustomText(  
text: "MY ACCOUNT",  
fontSize: 11,  
fontWeight: FontWeight.w900,  
color: const Color(0xFF94A3B8),  
letterSpacing: 1.5,  
),  
),  

## <span style="color:green">**[DONE]**</span> Change 2 — Sidebar: Remove Heart Icon, "View Lab Reports", "iCare" text, "PRO" text

**File:** lib/navigators/drawer.dart

**What to remove:** Inside the Doctor role's quick actions block (else if (selectedRole == 'Doctor')), remove any item that has:

- Heart icon (Icons.favorite or Icons.monitor_heart_rounded)
- "View Lab Reports" label
- Any "iCare" branded text widget
- Any "PRO" badge/text widget

These items appear in the \_drawerActionItem calls or as separate widgets in the Doctor section of the drawer.

**Action:** Delete those specific \_drawerActionItem(...) calls and any Text/CustomText widgets showing "iCare" or "PRO".

## <span style="color:green">**[DONE]**</span> Change 3 — Sidebar: Remove Logout Button from Bottom

**File:** lib/navigators/drawer.dart

**Location:** At the bottom of the Column inside SafeArea, after the Expanded list.

**Before:**

  
// Logout button  
Padding(  
padding: EdgeInsets.only(bottom: 30),  
child: CustomButton(  
onPressed: () {  
Navigator.of(context).push(  
MaterialPageRoute(builder: (ctx) => LoginScreen()),  
);  
},  
width: Utils.windowWidth(context) \* 0.6,  
borderRadius: 30,  
label: "Logout",  
),  
),  

**After:** Delete this entire Padding widget containing the Logout CustomButton.

## <span style="color:green">**[DONE]**</span> Change 4 — Sidebar: Remove Doctor Name + Image from Header

**File:** lib/navigators/drawer.dart

**Location:** Inside SafeArea > Column, the profile section with Stack, CircleAvatar, and the two Consumer widgets showing name and email.

**Before:**

  
// Profile section with border and edit icon  
Stack(  
clipBehavior: Clip.none,  
children: \[  
InkWell( ... CircleAvatar ... ),  
Positioned( ... edit icon ... ),  
\],  
),  
const SizedBox(height: 10),  
Consumer( // userName  
builder: (context, ref, child) {  
final userName = ref.watch(authProvider).user?.name ?? 'User';  
return Text(userName, ...);  
},  
),  
Consumer( // userEmail  
builder: (context, ref, child) {  
final userEmail = ref.watch(authProvider).user?.email ?? '';  
return Text(userEmail, ...);  
},  
),  
const SizedBox(height: 25),  

**After:** Delete the entire Stack (profile image), both Consumer widgets (name + email), and their surrounding SizedBox spacers.

**Note:** Keep the close button (Align with IconButton for Icons.close) at the top — only remove the profile image and name/email section.

## <span style="color:green">**[DONE]**</span> Change 5 — Sidebar: Remove "QUICK ACTIONS" Section Label

**File:** lib/navigators/drawer.dart

**Location:** Inside if (selectedRole != 'Admin') block, the Padding widget with "QUICK ACTIONS" text.

**Before:**

  
Padding(  
padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),  
child: CustomText(  
text: "QUICK ACTIONS",  
fontSize: 11,  
fontWeight: FontWeight.w900,  
color: const Color(0xFF94A3B8),  
letterSpacing: 1.5,  
),  
),  

**After:** Delete this entire Padding widget.

**Note:** Also remove the Divider that appears just before "QUICK ACTIONS" if it becomes redundant.

## <span style="color:red">**[PENDING]**</span> Change 6 — Logout Button: Place in Profile Dropdown (Updated Requirement)

**⚠️ Client Update (May 2026):** The original requirement was to place the Logout button inside the Edit Profile page (below the Update Profile button). The client later revised this — Logout should NOT be inside the Edit Profile page. Instead, Logout should appear in a **dropdown menu** accessible from the profile icon (top-right corner of the screen).

**Updated Requirement:**
- Top-right profile icon, when clicked, opens a small dropdown with two options:
  1. **Edit Profile** — navigates to the profile edit screen
  2. **Logout** — logs the user out and redirects to the Login screen
- The Logout button currently added inside `profile_edit.dart` (below Update Profile) should be **removed**.

**Files to modify:**
- lib/screens/profile_edit.dart — remove the Logout OutlinedButton added at the bottom
- lib/screens/home.dart (or wherever the top-right profile icon is rendered) — add dropdown with Edit Profile + Logout options

## <span style="color:green">**[DONE]**</span> Change 7 — Dashboard: Rename "Clinical Audit" → "Quality Score"

**File:** lib/screens/doctor_dashboard.dart

**Location:** Inside \_buildFeatureGrid() method, in the GridView under clinical_management.

**Before:**

  
\_buildFeatureCard(  
'clinical_audit'.tr(),  
Icons.rule_folder_rounded,  
const Color(0xFF0F172A),  
() {  
Navigator.of(context).push(  
MaterialPageRoute(builder: (ctx) => const ClinicalAuditScreen()),  
);  
},  
),  

**After:**

  
\_buildFeatureCard(  
'Quality Score',  
Icons.rule_folder_rounded,  
const Color(0xFF0F172A),  
() {  
Navigator.of(context).push(  
MaterialPageRoute(builder: (ctx) => const ClinicalAuditScreen()),  
);  
},  
),  

**Note:** The translation key 'clinical_audit'.tr() is replaced with a hardcoded string 'Quality Score'. If localization is needed later, add a new key quality_score in assets/translations/en.json and ur.json.

## <span style="color:green">**[DONE]**</span> Change 8 — Dashboard: Remove "Care Programs" Card

**File:** lib/screens/doctor_dashboard.dart

**Location:** Inside \_buildFeatureGrid() method, in the first GridView (clinical management section).

**Before:**

  
\_buildFeatureCard(  
'care_programs'.tr(),  
Icons.monitor_heart_rounded,  
const Color(0xFFEF4444),  
() {  
Navigator.of(context).push(  
MaterialPageRoute(  
builder: (ctx) => const SubscriptionChronicCareScreen(),  
),  
);  
},  
),  

**After:** Delete this entire \_buildFeatureCard(...) call.

**Note:** After removing this card, the grid will have 5 items instead of 6. Adjust childAspectRatio if the layout looks uneven.

## <span style="color:green">**[DONE]**</span> Change 9 — Credential Vault: Rename to "Certificate" + Change Icon

### 9a — Dashboard Feature Card

**File:** lib/screens/doctor_dashboard.dart

**Location:** Inside \_buildFeatureGrid(), the vault card.

**Before:**

  
\_buildFeatureCard(  
'vault'.tr(),  
Icons.verified_user_rounded,  
const Color(0xFF10B981),  
() {  
Navigator.of(context).push(  
MaterialPageRoute(builder: (ctx) => const CredentialVaultScreen()),  
);  
},  
),  

**After:**

  
\_buildFeatureCard(  
'Certificate',  
Icons.workspace_premium_rounded,  
const Color(0xFF10B981),  
() {  
Navigator.of(context).push(  
MaterialPageRoute(builder: (ctx) => const CredentialVaultScreen()),  
);  
},  
),  

### 9b — Credential Vault Screen AppBar Title

**File:** lib/screens/credential_vault_screen.dart

**Location:** Inside build() method, the AppBar title.

**Before:**

  
title: const Text(  
'Credential Vault',  
style: TextStyle(  
color: Color(0xFF0F172A),  
fontWeight: FontWeight.w900,  
),  
),  

**After:**

  
title: const Text(  
'Certificate',  
style: TextStyle(  
color: Color(0xFF0F172A),  
fontWeight: FontWeight.w900,  
),  
),  

### 9c — Credential Vault Screen Header Text

**File:** lib/screens/credential_vault_screen.dart

**Location:** Inside \_buildVaultHeader() method.

**Before:**

  
const Text(  
'Secure Document Storage',  
style: TextStyle(  
fontSize: 18,  
fontWeight: FontWeight.w900,  
color: Color(0xFF0F172A),  
),  
),  

**After:**

  
const Text(  
'My Certificates',  
style: TextStyle(  
fontSize: 18,  
fontWeight: FontWeight.w900,  
color: Color(0xFF0F172A),  
),  
),  

## <span style="color:green">**[DONE]**</span> Change 10 — Help Center: Update Phone Number

**File:** lib/screens/help_and_support.dart

**Location 1:** Inside \_WebHelpAndSupport widget, the \_WebContactItem for "Call Us".

**Before:**

  
\_WebContactItem(  
icon: Icons.phone_outlined,  
title: "Call Us",  
subtitle: "+1 (800) 123-4567",  
),  

**After:**

  
\_WebContactItem(  
icon: Icons.phone_outlined,  
title: "Call Us",  
subtitle: "+923068961564",  
),  

**Location 2:** If there is any other hardcoded phone number in the mobile layout section of HelpAndSupport, update that too to +923068961564.

## <span style="color:green">**[DONE]**</span> Change 11 — Settings: Remove "Danger Zone" Section

**File:** lib/screens/settings.dart

### 11a — Mobile Layout

**Location:** Inside build() method, at the bottom of SingleChildScrollView > Column.

**Before:**

  
const SizedBox(height: 32),  
CustomButton(  
borderRadius: 30,  
onPressed: () {  
// Logout logic  
},  
label: "Logout",  
),  
const SizedBox(height: 12),  
CustomButton(  
borderRadius: 30,  
onPressed: () {  
// Delete logic  
},  
label: "Delete Account",  
),  
const SizedBox(height: 40),  

**After:** Remove the "Delete Account" CustomButton and its SizedBox. Keep the "Logout" button only if it is still needed here (but per Change 6, logout is moving to profile page — so remove both buttons from settings).

### 11b — Web Layout

**Location:** Inside \_WebSettingsScreen > build(), the left side Column.

**Before:**

  
const SizedBox(height: 48),  
<br/>// Delete Account Zone  
Container(  
padding: const EdgeInsets.all(24),  
decoration: BoxDecoration(  
color: const Color(0xFFFEF2F2),  
borderRadius: BorderRadius.circular(16),  
border: Border.all(color: const Color(0xFFFECACA)),  
),  
child: Column(  
crossAxisAlignment: CrossAxisAlignment.start,  
children: \[  
const Text(  
"Danger Zone",  
style: TextStyle(  
fontSize: 16,  
fontWeight: FontWeight.w700,  
fontFamily: "Gilroy-Bold",  
color: Color(0xFFDC2626),  
),  
),  
// ... rest of danger zone content  
\],  
),  
),  

**After:** Delete the entire Container for "Danger Zone" (including the SizedBox(height: 48) before it if it becomes redundant).

## <span style="color:green">**[DONE]**</span> Change 12 — Settings: Remove "Subscription Plan" Item

**File:** lib/screens/settings.dart

**Location:** Inside build() method, the \_settingsList list definition.

**Before:**

  
{  
"id": "2",  
"title": isStudent ? "My Certificates" : "Subscription Plans",  
"onPress": () {  
if (isStudent) {  
Navigator.of(context).push(  
MaterialPageRoute(builder: (ctx) => const CertificatesScreen()),  
);  
} else {  
ScaffoldMessenger.of(context).showSnackBar(  
const SnackBar(content: Text("Subscription Plans coming soon!")),  
);  
}  
},  
},  

**After:** Delete this entire map entry { "id": "2", ... } from \_settingsList.

**Note:** After removing item with id: "2", update the divider logic at the bottom of the list. The current code checks if (item\['id'\] != "8") to show a divider — this still works correctly as long as the last item still has id: "8".

## Files Changed — Quick Reference

  
lib/  
├── navigators/  
│ └── drawer.dart ← Changes 1, 2, 3, 4, 5  
├── screens/  
│ ├── doctor_dashboard.dart ← Changes 7, 8, 9a  
│ ├── credential_vault_screen.dart ← Changes 9b, 9c  
│ ├── help_and_support.dart ← Change 10  
│ ├── settings.dart ← Changes 11, 12  
│ └── profile_edit.dart ← Change 6  

_Document prepared based on client requirements for Doctor role UI changes._
