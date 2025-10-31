# DVMA - Dementia Virtual Memory Assistant
<p align="center">
  <img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/logo.png" alt="DVMA Logo" width="200" />
</p>
<h2 align="center">Dementia Virtual Memory Assistant</h2>
<p align="center"><strong>A compassionate mobile app empowering dementia patients, caregivers, and admins</strong></p>
<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=white" alt="Firebase" />
  <img src="https://img.shields.io/badge/Gemini-AI-FF6B35?style=for-the-badge&logo=google&logoColor=white" alt="Gemini AI" />
</p>
<p align="center">
  <a href="#features">Features</a> •
  <a href="#screenshots">Screenshots</a> •
  <a href="#database-schema">Database</a> •
  <a href="#api-documentation">API</a> •
  <a href="#getting-started">Getting Started</a> •
  <a href="#demo">Demo</a>
</p>

---

## 📖 About
**DVMA (Dementia Virtual Memory Assistant)** is an innovative mobile application crafted to support individuals with dementia in navigating daily life, cherishing memories, and fostering connections with loved ones and caregivers. With intuitive role-based access for **Patients**, **Caretakers**, and **Admins**, DVMA delivers real-time notifications, AI-driven chat support, and advanced face recognition to uplift the well-being of dementia patients and their support networks.

<p align="center">
  <img src="https://media.giphy.com/media/3o7btPCcdNniyf0ArS/giphy.gif" alt="Content available animation" width="220" />
</p>

---

## ✨ Features
### 👤 Patient Features
- 📅 **Task Management**: Effortlessly create, edit, and track daily or recurring tasks with smart reminders
- 🤖 **AI Chat Assistant**: Powered by Gemini for personalized memory prompts and gentle task nudges
- 📸 **Memory Album**: Capture heartfelt photos and add descriptive notes to relive cherished moments
- 👨‍👩‍👧‍👦 **Family Management**: Easily add family members and set emergency contacts for peace of mind
- 📍 **Location Sharing**: Share your location securely with trusted caretakers
- 📔 **Personal Diary**: A private space for daily reflections with auto-save and thoughtful character limits
- 🔔 **Smart Notifications**: Stay informed with timely alerts for tasks, connections, and unbind requests
- 🎭 **Face Recognition**: Instantly identify family members using cutting-edge AI

### 🧑‍⚕️ Caretaker Features
- 🔗 **Connection Management**: Seamlessly connect with patients and handle requests with ease
- 👤 **Patient Monitoring**: Gain insights into tasks, location, and shared albums
- 📞 **Direct Communication**: Make calls or send messages to connected patients
- 📸 **Advanced Scanner**: Use your camera to recognize family members on the go
- 📋 **Task Oversight**: Supervise and assist with patient tasks remotely
- 📊 **Reporting System**: Submit detailed reports on patient well-being or app feedback
- 📍 **Live Tracking**: Monitor patient location in real-time for added safety

### 👨‍💼 Admin Features
- 👥 **User Management**: Oversee, edit, and manage bans/unbans for users and caretakers
- 🔔 **Global Notifications**: Broadcast announcements or send targeted alerts
- 📈 **Reports Dashboard**: Review and resolve user-submitted reports efficiently
- ⚙️ **System Settings**: Customize API endpoints and support channels
- 👤 **Account Control**: Securely manage admin accounts and permissions
- 📊 **Analytics**: Track app engagement and usage patterns for continuous improvement
---
## 📸 Screenshots
Explore the app's interfaces through compact thumbnails. Click to enlarge in an overlay. The overlay includes a persistent close button.

<style>
/***** Compact thumbnails + overlay *****/
.dvma-thumbs { display:flex; flex-wrap:wrap; gap:10px; justify-content:center; }
.dvma-thumbs a { display:inline-block; border:1px solid #e5e7eb; border-radius:8px; overflow:hidden; background:#fff; }
.dvma-thumbs img { width:120px; height:255px; object-fit:cover; display:block; }
/* Lightbox using :target (works on GitHub Markdown) */
.lightbox { display:none; }
.lightbox:target { display:block; position:fixed; inset:0; background:rgba(0,0,0,0.85); z-index:9999; }
.lightbox .content { position:absolute; top:50%; left:50%; transform:translate(-50%,-50%); max-width:92vw; max-height:86vh; }
.lightbox img { width:auto; height:auto; max-width:92vw; max-height:86vh; border-radius:10px; box-shadow:0 10px 40px rgba(0,0,0,0.5); }
.lightbox .close { position:fixed; top:16px; right:16px; width:40px; height:40px; line-height:40px; text-align:center; font-size:22px; font-weight:700; color:#111; background:#fff; border-radius:999px; text-decoration:none; box-shadow:0 2px 10px rgba(0,0,0,0.35); z-index:10000; }
@media (max-width:600px){ .dvma-thumbs img{ width:100px; height:212px; } .dvma-thumbs { gap:8px; } }
</style>

### Patient Interface
<div class="dvma-thumbs">
  <a href="#lb-user-home"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/user-home-page.jpg" alt="Home Page" /></a>
  <a href="#lb-user-ai"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/user-ai-page.jpg" alt="AI Chat" /></a>
  <a href="#lb-user-caretaker"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/user-caretaker-page.jpg" alt="Caretaker Connections" /></a>
  <a href="#lb-user-profile"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/user-profile-page.jpg" alt="Profile" /></a>
</div>
<div id="lb-user-home" class="lightbox">
  <a class="close" href="#screenshots" aria-label="Close">×</a>
  <div class="content"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/user-home-page.jpg" alt="Home Page - full" /></div>
</div>
<div id="lb-user-ai" class="lightbox">
  <a class="close" href="#screenshots" aria-label="Close">×</a>
  <div class="content"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/user-ai-page.jpg" alt="AI Chat - full" /></div>
</div>
<div id="lb-user-caretaker" class="lightbox">
  <a class="close" href="#screenshots" aria-label="Close">×</a>
  <div class="content"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/user-caretaker-page.jpg" alt="Caretaker Connections - full" /></div>
</div>
<div id="lb-user-profile" class="lightbox">
  <a class="close" href="#screenshots" aria-label="Close">×</a>
  <div class="content"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/user-profile-page.jpg" alt="Profile - full" /></div>
</div>

### Caretaker Interface
<div class="dvma-thumbs">
  <a href="#lb-ct-dashboard"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/caretaker-user-page.jpg" alt="Patient Dashboard" /></a>
  <a href="#lb-ct-location"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/caretaker-user-location-page.jpg" alt="Location Tracking" /></a>
  <a href="#lb-ct-profile"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/caretaker-profile-page.jpg" alt="Caretaker Profile" /></a>
</div>
<div id="lb-ct-dashboard" class="lightbox">
  <a class="close" href="#screenshots" aria-label="Close">×</a>
  <div class="content"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/caretaker-user-page.jpg" alt="Patient Dashboard - full" /></div>
</div>
<div id="lb-ct-location" class="lightbox">
  <a class="close" href="#screenshots" aria-label="Close">×</a>
  <div class="content"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/caretaker-user-location-page.jpg" alt="Location Tracking - full" /></div>
</div>
<div id="lb-ct-profile" class="lightbox">
  <a class="close" href="#screenshots" aria-label="Close">×</a>
  <div class="content"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/caretaker-profile-page.jpg" alt="Caretaker Profile - full" /></div>
</div>

### Admin Interface
<div class="dvma-thumbs">
  <a href="#lb-admin-ct"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/admin-caretakers-page.jpg" alt="Caretaker Management" /></a>
  <a href="#lb-admin-noti"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/admin-notification-sent-page.jpg" alt="Notifications" /></a>
  <a href="#lb-admin-settings"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/admin-settings.jpg" alt="Settings" /></a>
</div>
<div id="lb-admin-ct" class="lightbox">
  <a class="close" href="#screenshots" aria-label="Close">×</a>
  <div class="content"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/admin-caretakers-page.jpg" alt="Caretaker Management - full" /></div>
</div>
<div id="lb-admin-noti" class="lightbox">
  <a class="close" href="#screenshots" aria-label="Close">×</a>
  <div class="content"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/admin-notification-sent-page.jpg" alt="Notifications - full" /></div>
</div>
<div id="lb-admin-settings" class="lightbox">
  <a class="close" href="#screenshots" aria-label="Close">×</a>
  <div class="content"><img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/admin-settings.jpg" alt="Settings - full" /></div>
</div>

---

## 🗄 Database Schema
The following models reflect the current Firestore structure used in the app. Names are normalized to singular collection names as used in code.

### 📊 Collections Overview
| Collection | Purpose | Key Features |
|------------|---------|--------------|
| `user` | Patient profiles and data | Tasks, diary, family, location, notifications |
| `caretaker` | Caretaker profiles | Credentials, approvals, connections, notifications |
| `admin` | Admin accounts | System access control |
| `connections` | User–caretaker links | Status tracking, request/confirm actors, timestamps |
| `reports` | User-submitted reports | Issue tracking, moderation workflow |
| `api` | System configuration | URLs, support contacts |

### 👤 User Collection
**Purpose**: Stores patient profiles and related data.

**Example document**:
```
{
  "uid": "abc123def",
  "fullName": "John Doe",
  "username": "johndoe2025",
  "email": "john@example.com",
  "phoneNo": "+1234567890",
  "dob": "1950-05-15",
  "gender": "male",
  "bio": "Loves gardening and music",
  "locality": "Springfield",
  "city": "Los Angeles",
  "state": "California",
  "profileImageUrl": "https://example.com/profile.jpg",
  "isConnected": true,
  "currentConnectionId": "conn789",
  "emergencyContacts": [
    { "name": "Jane Doe", "relation": "Spouse", "number": "+1234567891" }
  ],
  "playerIds": ["oneSignalId123"],
  "isBanned": false
}
```

**Subcollections**:
- `to_dos` — Patient tasks. Example: `{ "task": "Take medicine", "completed": false, "dueDate": "2025-06-15T10:00:00Z" }`
- `recurring_tasks` — Task templates. Example: `{ "task": "Morning walk", "dailyDueTime": {"hour": 8, "min": 0} }`
- `family_members` — Family contacts including face data references. Example: `{ "name": "Mary Doe", "relation": "Daughter", "phone": "+1234567892", "imageUrl": "https://..." }`
- `album` — Memory photos. Example: `{ "title": "Birthday 2025", "imageUrl": "https://example.com/photo.jpg" }`
- `diary` — Daily entries (doc ID = date). Example: `{ "content": "Had a good day today...", "createdAt": "2025-06-15T20:00:00Z" }`
- `notifications` — User notifications. Example: `{ "type": "connection_request", "message": "New request", "isRead": false, "createdAt": "2025-06-15T10:00:00Z" }`

### 🧑‍⚕️ Caretaker Collection
**Purpose**: Manages caretaker profiles and professional credentials.

**Example document**:
```
{
  "uid": "xyz789abc",
  "fullName": "Sarah Smith",
  "username": "sarahsmith",
  "email": "sarah@example.com",
  "phoneNo": "+0987654321",
  "profileImageUrl": "https://example.com/caretaker.jpg",
  "caregiverType": "nurse",
  "relation": "",
  "experienceYears": 5,
  "experienceBio": "5 years of elderly care experience",
  "graduationOnNursing": "BSN from UCLA",
  "graduationCertificateUrl": "https://example.com/cert.pdf",
  "isApprove": true,
  "isConnected": true,
  "currentConnectionId": "conn789",
  "playerIds": ["oneSignalId456"],
  "isBanned": false
}
```

**Subcollections**:
- `notifications` — Caretaker notifications. Example: `{ "type": "unbind_request", "message": "Patient wants to unbind", "isRead": false, "createdAt": "2025-06-15T12:00:00Z" }`

### 🔗 Connections Collection
**Purpose**: Tracks user–caretaker relationships and statuses.

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `user_uid` | String | Patient UID | `"abc123def"` |
| `caretaker_uid` | String | Caretaker UID | `"xyz789abc"` |
| `status` | String | Connection status | `"accepted"` |
| `timestamp` | Timestamp | Request time | `"2025-06-15T10:00:00Z"` |
| `confirmedBy` | String | Who confirmed | `"xyz789abc"` |
| `requestedBy` | String | Who requested | `"abc123def"` |

### 📊 Reports Collection
**Purpose**: Handles user-submitted reports for admin review.

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `sender_uid` | String | Reporter UID | `"abc123def"` |
| `sender_role` | String | Reporter role | `"user"` |
| `reported_uid` | String | Reported UID | `"xyz789abc"` |
| `reported_role` | String | Reported role | `"caretaker"` |
| `title` | String | Report title | `"Inappropriate behavior during visit"` |
| `description` | String | Report details | `"The caretaker was unresponsive to requests for assistance."` |
| `status` | String | Review status | `"pending"` |
| `createdAt` | Timestamp | Submission time | `"2025-06-15T14:00:00Z"` |

### ⚙️ API Collection
**Purpose**: Stores system-wide configuration for dynamic endpoints and support info.

**Example document**:
```
{
  "geminiApiUrl": "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent",
  "supportEmail": "support@dvma.app",
  "supportPhone": "+1-800-DVMA-HELP",
  "version": "1.0.0",
  "lastUpdated": "2025-06-15T00:00:00Z"
}
```
---
## 🔌 API Documentation
DVMA leverages Firebase for authentication and Firestore for data persistence, with Gemini AI for chat features. Key endpoints are dynamically loaded from the `api` collection.

### Authentication
- **Sign Up/Login**: Firebase Auth (`signInWithEmailAndPassword` / `createUserWithEmailAndPassword`)
- **Role Assignment**: Post-signup, users select role (patient/caretaker/admin) and complete profile.

### Core APIs (Firestore)
- **User Tasks**: `user/{uid}/to_dos` (CRUD via Firebase SDK)
- **Connections**: `connections` (add/update for requests/approvals)
- **Notifications**: OneSignal integration for push alerts, stored in user subcollections.
- **Face Recognition**: Client-side ML Kit or serverless Cloud Vision API calls.

### AI Integration
- **Chat Assistant**: POST to Gemini API with prompt: `"As a compassionate assistant for dementia patients, respond to: {user_input}"`

For full API specs, refer to [Firebase Docs](https://firebase.google.com/docs) and [Gemini API](https://ai.google.dev/gemini-api/docs).

---
## 🚀 Getting Started
### Prerequisites
- Flutter SDK (v3.10+)
- Firebase project setup
- OneSignal account for notifications
- Gemini API key

### Installation
1. Clone the repo: `git clone https://github.com/ajmal-uk/dementia-virtual-memory.git`
2. Install dependencies: `flutter pub get`
3. Configure Firebase: Add `google-services.json` (Android) / `GoogleService-Info.plist` (iOS)
4. Set environment vars: Update `lib/config/app_config.dart` with API keys.
5. Run: `flutter run`

### Development
- **Patient Flow**: Test task creation and AI chat in simulator.
- **Caretaker**: Simulate connections via Firestore emulator.
- **Admin**: Use elevated privileges for testing bans/notifications.

Contribute via pull requests—focus on accessibility and privacy enhancements!

---

<div align="center">
  <small>Made with ❤️ for dementia care | © 2025 DVMA Team</small>
</div>
