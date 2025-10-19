# DVMA - Dementia Virtual Memory Assistant

<div align="center">
  <img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/logo.png" alt="DVMA Logo" width="200"/>
  <h3>Dementia Virtual Memory Assistant</h3>
  <p><strong>A comprehensive mobile app for dementia patients, caregivers, and admins</strong></p>
  <p>Built with ❤️ using Flutter, Firebase, and AI</p>
  <div>
    <a href="#-features">Features</a> •
    <a href="#-screenshots">Screenshots</a> •
    <a href="#-database-schema">Database</a> •
    <a href="#-api-documentation">API</a> •
    <a href="#-getting-started">Getting Started</a> •
    <a href="#-demo">Demo</a>
  </div>
</div>

---

## 📖 About

**DVMA (Dementia Virtual Memory Assistant)** is a compassionate mobile application designed to support dementia patients in managing their daily lives, preserving memories, and staying connected with caregivers and family. The app provides role-based access for **Users**, **Caretakers**, and **Admins**, featuring real-time notifications, AI-powered chat assistance, and face recognition capabilities to enhance the quality of life for dementia patients.

---

## ✨ Features

### 👤 Patient Features
- 📅 **Task Management**: Create, edit, and track daily/recurring tasks with reminders
- 🤖 **AI Chat Assistant**: Gemini-powered chat for memory support and task reminders
- 📸 **Memory Album**: Capture and organize photos with descriptions
- 👨‍👩‍👧‍👦 **Family Management**: Add and manage family members with emergency contacts
- 📍 **Location Sharing**: Share location with connected caretakers
- 📔 **Personal Diary**: Secure diary with auto-save and character limit
- 🔔 **Smart Notifications**: Receive alerts for tasks, connections, and unbind requests
- 🎭 **Face Recognition**: Identify family members using AI

### 🧑‍⚕️ Caretaker Features
- 🔗 **Connection Management**: Connect with users, accept/decline requests
- 👤 **Patient Monitoring**: View patient tasks, location, and album
- 📞 **Direct Communication**: Call and message connected users
- 📸 **Advanced Scanner**: Identify family members via camera
- 📋 **Task Oversight**: Monitor and manage patient tasks
- 📊 **Reporting System**: Send reports about patients or app issues
- 📍 **Live Tracking**: Real-time patient location tracking

### 👨‍💼 Admin Features
- 👥 **User Management**: View, edit, ban/unban users and caretakers
- 🔔 **Global Notifications**: Send broadcasts or individual notifications
- 📈 **Reports Dashboard**: Review and manage user-generated reports
- ⚙️ **System Settings**: Configure API URLs and support emails
- 👤 **Account Control**: Admin account management and access control
- 📊 **Analytics**: Monitor app usage and engagement

---

## 📸 Screenshots

### Patient Interface
| Screen | Description |
|--------|-------------|
| <img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/user-home-page.jpg" width="200"/> | Home page with task overview and quick actions |
| <img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/user-ai-page.jpg" width="200"/> | AI Chat assistant for memory support |
| <img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/user-caretaker-page.jpg" width="200"/> | Caretaker connection management |
| <img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/user-profile-page.jpg" width="200"/> | Patient profile with emergency contacts |

### Caretaker Interface
| Screen | Description |
|--------|-------------|
| <img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/caretaker-user-page.jpg" width="200"/> | Patient dashboard with task overview |
| <img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/caretaker-user-location-page.jpg" width="200"/> | Real-time patient location tracking |
| <img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/caretaker-profile-page.jpg" width="200"/> | Caretaker profile and settings |

### Admin Interface
| Screen | Description |
|--------|-------------|
| <img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/admin-caretakers-page.jpg" width="200"/> | Caretaker management dashboard |
| <img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/admin-notification-sent-page.jpg" width="200"/> | Global notification system |
| <img src="https://ik.imagekit.io/uthakkan/Dimentia-Memory-Assistant/admin-settings.jpg" width="200"/> | System configuration panel |

---

## 🗄 Database Schema

### 📊 Collections Overview

| Collection | Purpose | Key Features |
|------------|---------|---------------|
| `user` | Patient profiles and data | Tasks, diary, family, location |
| `caretaker` | Caretaker profiles | Credentials, connections, approvals |
| `admin` | Admin accounts | System access control |
| `connections` | User-caretaker links | Status tracking, requests |
| `reports` | User reports | Issue tracking, moderation |
| `api` | System configuration | URLs, support contacts |

---

### 👤 User Collection

**Purpose**: Stores patient profiles and all related data

```json
{
  "uid": "abc123def",
  "fullName": "John Doe",
  "username": "johndoe2024",
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
    {
      "name": "Jane Doe",
      "relation": "Spouse",
      "number": "+1234567891"
    }
  ],
  "playerIds": ["oneSignalId123"],
  "isBanned": false
}
```

#### Subcollections

| Subcollection | Description | Example Document |
|---------------|-------------|------------------|
| `to_dos` | Patient tasks | `{ "task": "Take medicine", "completed": false, "dueDate": "2024-06-15T10:00:00Z" }` |
| `recurring_tasks` | Task templates | `{ "task": "Morning walk", "dailyDueTime": {"hour": 8, "min": 0} }` |
| `family_members` | Family contacts | `{ "name": "Mary Doe", "relation": "Daughter", "phone": "+1234567892" }` |
| `album` | Memory photos | `{ "title": "Birthday 2024", "imageUrl": "https://example.com/photo.jpg" }` |
| `diary` | Daily entries (doc ID = date) | `{ "content": "Had a good day today...", "createdAt": "2024-06-15T20:00:00Z" }` |
| `notifications` | User notifications | `{ "type": "connection_request", "message": "New request", "isRead": false }` |

---

### 🧑‍⚕️ Caretaker Collection

**Purpose**: Stores caretaker profiles and credentials

```json
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

#### Subcollections

| Subcollection | Description | Example Document |
|---------------|-------------|------------------|
| `notifications` | Caretaker notifications | `{ "type": "unbind_request", "message": "Patient wants to unbind", "isRead": false }` |

---

### 🔗 Connections Collection

**Purpose**: Manages user-caretaker relationships and status

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| user_uid | String | Patient UID | "abc123def" |
| caretaker_uid | String | Caretaker UID | "xyz789abc" |
| status | String | Connection status | "accepted" |
| timestamp | Timestamp | Request time | "2024-06-15T10:00:00Z" |
| confirmedBy | String | Who confirmed | "xyz789abc" |
| requestedBy | String | Who requested | "abc123def" |

---

### 📊 Reports Collection

**Purpose**: User-generated reports for moderation

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| sender_uid | String | Reporter UID | "abc123def" |
| sender_role | String | Reporter role | "user" |
| reported_uid | String | Reported UID | "xyz789abc" |
| reported_role | String | Reported role | "caretaker" |
| title | String | Report title | "Inappropriate behavior" |
| description | String | Report details | "Caretaker was rude during call..." |
| created_at | Timestamp | Report time | "2024-06-15T14:30:00Z" |
| seen | Boolean | Admin seen status | false |

---

### ⚙️ API Collection

**Purpose**: System configuration

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| apiURL | String | Face recognition API | "https://api.dvma.app" |
| email | String | Support email | "support@dvma.app" |

---

## 🔌 API Documentation

### Face Recognition Endpoint
**URL**: `/recognize`  
**Method**: `POST`

#### Request Body
```json
{
  "members": [
    {
      "memberName": "Jane Doe",
      "memberRelation": "Daughter",
      "memberImage": "base64_or_url",
      "memberImageUrl": "https://example.com/jane.jpg"
    }
  ],
  "imageUrl": "base64_or_url"
}
```

#### Response
```json
{
  "matchFound": true,
  "memberName": "Jane Doe",
  "memberRelation": "Daughter",
  "memberImageUrl": "https://example.com/jane.jpg",
  "confidence": 0.95
}
```

### Notification API
**URL**: `https://onesignal.com/api/v1/notifications`  
**Method**: `POST`

#### Request Headers
```
Content-Type: application/json
Authorization: Basic YOUR_API_KEY
```

#### Request Body
```json
{
  "app_id": "YOUR_APP_ID",
  "include_player_ids": ["playerId1", "playerId2"],
  "contents": {"en": "Task reminder: Take medicine"},
  "priority": 10
}
```

---

## 🛠 Tech Stack

### 📱 Mobile App (Flutter)
- **Framework**: Flutter 3.9.2+
- **State Management**: StatefulWidget + Streams
- **Authentication**: Firebase Auth
- **Database**: Cloud Firestore
- **Storage**: Cloudinary (images)
- **Notifications**: OneSignal
- **Maps**: Google Maps Flutter
- **AI**: Gemini API

### 🧠 Face Recognition API (Flask)
- **Backend**: Flask 3.1.2
- **Face Recognition**: DeepFace (ArcFace model)
- **Image Processing**: Pillow, OpenCV
- **Deployment**: Gunicorn

### 🗄 Database (Firebase Firestore)
- **Collections**: Role-based structured data
- **Real-time Updates**: Live sync across devices
- **Security**: Firestore rules for access control

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: [Install Flutter](https://docs.flutter.dev/get-started/install)
- **Firebase Project**: [Create Firebase Project](https://console.firebase.google.com/)
- **Python 3.9+**: For Flask API
- **Cloudinary Account**: For image storage

### 1. Clone Repository
```bash
git clone https://github.com/yourusername/dvma.git
cd dvma
```

### 2. Flutter App Setup
```bash
# Install dependencies
flutter pub get

# Configure Firebase
# - Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
# - Update `lib/firebase_options.dart` with your config

# Run app
flutter run
```

### 3. Face Recognition API Setup
```bash
cd api
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

### 4. Environment Variables
Create `.env` in Flutter root:
```env
CLOUDINARY_CLOUD_NAME=your_cloud_name
```

---

## 📦 Dependencies

### Flutter (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^4.0.0
  cloud_firestore: ^6.0.0
  firebase_auth: ^6.0.1
  image_picker: ^1.2.0
  camera: ^0.11.2
  http: ^1.5.0
  onesignal_flutter: ^5.3.4
  google_maps_flutter: ^2.13.1
  geolocator: ^14.0.2
  flutter_gemini: ^3.0.0
  flutter_animate: ^4.5.2
  intl: ^0.20.2
  shared_preferences: ^2.5.3
  logger: ^2.6.1
  confetti: ^0.8.0
```

### Python (requirements.txt)
```txt
Flask==3.1.2
deepface==0.0.79
opencv-python==4.8.1.78
Pillow==10.0.1
requests==2.31.0
numpy==1.24.3
tf_keras==2.13.0
```

---

## 🏃‍♂️ How to Run

1. **Start Firebase Emulator** (optional for development):
   ```bash
   firebase emulators:start
   ```

2. **Run Face Recognition API**:
   ```bash
   cd api && python app.py
   ```

3. **Run Flutter App**:
   ```bash
   flutter run
   ```

4. **Build APK**:
   ```bash
   flutter build apk --release
   ```

---

## 🔧 Configuration

### Firebase Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /user/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /caretaker/{caretakerId} {
      allow read, write: if request.auth != null && request.auth.uid == caretakerId;
    }
    match /admin/{adminId} {
      allow read, write: if request.auth != null && request.auth.uid == adminId;
    }
  }
}
```

---

## 📱 Demo

Experience the DVMA app firsthand by downloading our demo APK:

<div align="center">
  <a href="https://mega.nz/file/m94lALhJ#yFUFa0AdSg3tuhSrvESzdnJ0Vy5d1qnypS-JOApCUQs" style="display: inline-block; padding: 12px 24px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; text-decoration: none; border-radius: 8px; font-weight: bold; box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);">
    📥 Download Demo APK
  </a>
</div>

> **Note**: The demo APK is for testing purposes only and may not contain all production features.

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📞 Support

For support, email us at: **ajmaluk.me@gmail.com**

---

<div align="center">
  <p>Made with ❤️ for the dementia community</p>
  <p>© 2024 DVMA - Dementia Virtual Memory Assistant</p>
</div>