# DVMA - Dementia Virtual Memory App

<div align="center">
  <img src="assets/logo.png" alt="DVMA Logo" width="200"/>
</div>

## 📱 Project Overview

**DVMA (Dementia Virtual Memory Assistant)** is a comprehensive mobile application designed to help dementia patients manage their daily tasks, preserve memories, and stay connected with caregivers and family members. The app features role-based access for **Users**, **Caretakers**, and **Admins**, with real-time notifications, AI-powered chat assistance, and face recognition capabilities.

---

## ✨ Key Features

### 👤 User Features
- 📅 **Task Management**: Create, edit, and track daily/recurring tasks with reminders
- 🤖 **AI Chat Assistant**: Gemini-powered chat for memory support and task reminders
- 📸 **Memory Album**: Capture and organize photos with descriptions
- 👨‍👩‍👧‍👦 **Family Management**: Add and manage family members with emergency contacts
- 📍 **Location Sharing**: Share location with connected caretakers
- 📔 **Diary**: Personal diary with auto-save and character limit
- 🔔 **Notifications**: Receive alerts for tasks, connections, and unbind requests

### 🧑‍⚕️ Caretaker Features
- 🔗 **Connection Management**: Connect with users, accept/decline requests
- 👤 **Patient Monitoring**: View patient tasks, location, and album
- 📞 **Direct Communication**: Call and message connected users
- 📸 **Face Recognition**: Identify family members via camera
- 📋 **Task Oversight**: Monitor and manage patient tasks
- 📊 **Reports**: Send reports about patients or app issues

### 👨‍💼 Admin Features
- 👥 **User Management**: View, edit, ban/unban users and caretakers
- 🔔 **Global Notifications**: Send broadcasts or individual notifications
- 📈 **Reports Dashboard**: Review and manage user-generated reports
- ⚙️ **System Settings**: Configure API URLs and support emails
- 👤 **Account Control**: Admin account management and access control

---

## 📸 Screenshots

> 📌 **Note**: Add screenshots in the `assets/screenshots/` directory and update paths below.

| Screen | Description |
|--------|-------------|
| `assets/screenshots/welcome.png` | Welcome screen with role selection |
| `assets/screenshots/login.png` | Login screen for each role |
| `assets/screenshots/user_home.png` | User home with task overview |
| `assets/screenshots/ai_chat.png` | AI chat assistant interface |
| `assets/screenshots/caretaker_dashboard.png` | Caretaker connected patient view |
| `assets/screenshots/admin_dashboard.png` | Admin user management view |
| `assets/screenshots/family_scanner.png` | Face recognition scanner |
| `assets/screenshots/diary_album.png` | Diary and memory album |

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
- **Deployment**: Gunicorn (for production)

### 🗄 Database (Firebase Firestore)
- **Collections**: Structured for roles (user, caretaker, admin)
- **Real-time Updates**: Live sync across devices
- **Security**: Firestore rules for role-based access

---

## 📊 Firebase Collections (Database Schema)

| Collection | Fields | Description |
|------------|--------|-------------|
| **user** | `uid`, `fullName`, `username`, `email`, `phoneNo`, `dob`, `gender`, `bio`, `locality`, `city`, `state`, `profileImageUrl`, `isConnected`, `currentConnectionId`, `emergencyContacts`, `playerIds`, `isBanned` | Patient profiles and settings |
| **caretaker** | `uid`, `fullName`, `username`, `email`, `phoneNo`, `profileImageUrl`, `caregiverType` (`relative`/`nurse`), `relation`, `experienceYears`, `experienceBio`, `graduationOnNursing`, `graduationCertificateUrl`, `isApprove`, `isConnected`, `currentConnectionId`, `playerIds`, `isBanned` | Caretaker profiles and credentials |
| **admin** | `uid`, `email`, `createdAt` | Admin accounts |
| **connections** | `user_uid`, `caretaker_uid`, `status` (`pending`/`accepted`/`unbind_requested`/`unbound`), `timestamp`, `confirmedBy`, `requestedBy` | User-caretaker relationships |
| **user/to_dos** | `task`, `description`, `completed`, `createdAt`, `dueDate`, `reminderTime`, `recurringId`, `createdBy` | Patient tasks |
| **user/recurring_tasks** | `task`, `description`, `dailyDueTime`, `dailyReminderTime`, `createdAt` | Recurring task templates |
| **user/family_members** | `name`, `relation`, `phone`, `imageUrl`, `createdAt` | Family member contacts |
| **user/album** | `title`, `description`, `imageUrl`, `createdAt` | Memory photos |
| **user/diary** | `content`, `createdAt`, `updatedAt` | Diary entries (doc ID = date) |
| **reports** | `sender_uid`, `sender_role`, `reported_uid`, `reported_role`, `title`, `description`, `created_at`, `seen` | User reports |
| **notifications** | `type`, `message`, `from`, `to`, `createdAt`, `isRead`, `connectionId` | Role-based notifications |
| **api** | `apiURL`, `email` | System configuration |

---

## 🔌 API Documentation

### Face Recognition Endpoint
- **URL**: `/recognize`
- **Method**: `POST`
- **Body**:
  ```json
  {
    "members": [
      {
        "memberName": "John Doe",
        "memberRelation": "Son",
        "memberImage": "base64_or_url",
        "memberImageUrl": "http://example.com/photo.jpg"
      }
    ],
    "imageUrl": "base64_or_url"
  }
  ```
- **Response**:
  ```json
  {
    "matchFound": true,
    "memberName": "John Doe",
    "memberRelation": "Son",
    "memberImageUrl": "http://example.com/photo.jpg",
    "confidence": 0.95
  }
  ```

---

## 🚀 Setup Instructions

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
# Navigate to API directory
cd api

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run API
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
  image_picker: ^1.2.0
  firebase_core: ^4.0.0
  flutter_animate: ^4.5.2
  cupertino_icons: ^1.0.8
  camera: ^0.11.2
  http: ^1.5.0
  cloud_firestore: ^6.0.0
  firebase_auth: ^6.0.1
  characters: ^1.4.0
  material_color_utilities: ^0.11.1
  meta: ^1.16.0
  cloudinary_public: ^0.23.1
  onesignal_flutter: ^5.3.4
  url_launcher: ^6.3.2
  permission_handler: ^12.0.1
  fluttertoast: ^9.0.0
  intl: ^0.20.2
  file_picker: ^10.3.3
  logger: ^2.6.1
  shared_preferences: ^2.5.3
  flutter_gemini: ^3.0.0
  flutter_dotenv: ^6.0.0
  confetti: ^0.8.0
  flutter_isolate: ^2.1.0
  foundation: ^0.0.5
  image: ^4.5.4
  typed_data: ^1.4.0
  google_maps_flutter: ^2.13.1
  geolocator: ^14.0.2
```

### Python (requirements.txt)
```txt
Flask==3.1.2
deepface==0.0.95
opencv-python==4.12.0.88
pillow==11.3.0
requests==2.32.5
numpy==2.2.6
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

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---


## 📞 Support

For support, email us at: [ajmaluk.me@gmail.com](mailto:ajmaluk.me@gmail.com)

---

<div align="center">
  Made with ❤️ for the dementia community
</div>