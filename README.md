# DVMA - Dementia Virtual Memory App

<div align="center">
  <img src="https://via.placeholder.com/200x200?text=DVMA+Logo" alt="DVMA Logo" width="200"/>
  <h3>Dementia Virtual Memory Assistant</h3>
  <p>A comprehensive mobile app for dementia patients, caregivers, and admins</p>
</div>

---

## 📱 Project Overview

**DVMA (Dementia Virtual Memory Assistant)** is a compassionate mobile application designed to support dementia patients in managing their daily lives, preserving memories, and staying connected with caregivers and family. The app provides role-based access for **Users**, **Caretakers**, and **Admins**, featuring real-time notifications, AI-powered chat assistance, and face recognition capabilities to enhance the quality of life for dementia patients.

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

| Screen | Description | Screenshot |
|--------|-------------|-------------|
| Welcome | Welcome screen with role selection | <img src="https://via.placeholder.com/300x600?text=Welcome+Screen" width="150"> |
| Login | Login screen for each role | <img src="https://via.placeholder.com/300x600?text=Login+Screen" width="150"> |
| User Home | User home with task overview | <img src="https://via.placeholder.com/300x600?text=User+Home" width="150"> |
| AI Chat | AI chat assistant interface | <img src="https://via.placeholder.com/300x600?text=AI+Chat" width="150"> |
| Caretaker Dashboard | Caretaker connected patient view | <img src="https://via.placeholder.com/300x600?text=Caretaker+Dashboard" width="150"> |
| Admin Dashboard | Admin user management view | <img src="https://via.placeholder.com/300x600?text=Admin+Dashboard" width="150"> |
| Family Scanner | Face recognition scanner | <img src="https://via.placeholder.com/300x600?text=Family+Scanner" width="150"> |
| Diary & Album | Diary and memory album | <img src="https://via.placeholder.com/300x600?text=Diary+Album" width="150"> |

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

### Collection: `user`
- **Description**: Stores patient profiles and settings.
- **Fields**:
  - `uid` (String): User ID
  - `fullName` (String): Full name
  - `username` (String): Unique username
  - `email` (String): Email address
  - `phoneNo` (String): Phone number
  - `dob` (Timestamp): Date of birth
  - `gender` (String): Gender (male/female/other)
  - `bio` (String): Short bio
  - `locality` (String): Locality
  - `city` (String): City
  - `state` (String): State
  - `profileImageUrl` (String): Profile image URL
  - `isConnected` (Boolean): Connection status
  - `currentConnectionId` (String): Current connection ID
  - `emergencyContacts` (Array): List of emergency contacts
  - `playerIds` (Array): OneSignal player IDs
  - `isBanned` (Boolean): Ban status
- **Subcollections**:
  - `to_dos`: Task documents (see below)
  - `recurring_tasks`: Recurring task templates
  - `family_members`: Family member documents
  - `album`: Memory photo documents
  - `diary`: Diary entries (document ID is date string)
  - `notifications`: Notification documents

### Collection: `caretaker`
- **Description**: Stores caretaker profiles and credentials.
- **Fields**:
  - `uid` (String): Caretaker ID
  - `fullName` (String): Full name
  - `username` (String): Unique username
  - `email` (String): Email address
  - `phoneNo` (String): Phone number
  - `profileImageUrl` (String): Profile image URL
  - `caregiverType` (String): 'relative' or 'nurse'
  - `relation` (String): Relation to patient (if relative)
  - `experienceYears` (Number): Years of experience (if nurse)
  - `experienceBio` (String): Experience bio (if nurse)
  - `graduationOnNursing` (String): Nursing qualification (if nurse)
  - `graduationCertificateUrl` (String): Certificate URL (if nurse)
  - `isApprove` (Boolean): Approval status
  - `isConnected` (Boolean): Connection status
  - `currentConnectionId` (String): Current connection ID
  - `playerIds` (Array): OneSignal player IDs
  - `isBanned` (Boolean): Ban status
- **Subcollections**:
  - `notifications`: Notification documents

### Collection: `admin`
- **Description**: Admin accounts.
- **Fields**:
  - `uid` (String): Admin ID
  - `email` (String): Email address
  - `createdAt` (Timestamp): Account creation time

### Collection: `connections`
- **Description**: Manages user-caretaker relationships.
- **Fields**:
  - `user_uid` (String): User ID
  - `caretaker_uid` (String): Caretaker ID
  - `status` (String): 'pending', 'accepted', 'unbind_requested', 'unbound'
  - `timestamp` (Timestamp): Connection request time
  - `confirmedBy` (String): UID of who confirmed
  - `requestedBy` (String): UID of who requested

### Collection: `reports`
- **Description**: User-generated reports.
- **Fields**:
  - `sender_uid` (String): Reporter's UID
  - `sender_role` (String): Reporter's role
  - `reported_uid` (String): Reported user's UID (if applicable)
  - `reported_role` (String): Reported user's role (if applicable)
  - `title` (String): Report title
  - `description` (String): Report description
  - `created_at` (Timestamp): Report time
  - `seen` (Boolean): Admin seen status

### Collection: `api`
- **Description**: System configuration.
- **Fields**:
  - `apiURL` (String): Face recognition API URL
  - `email` (String): Support email

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
Flask
deepface
opencv-python
pillow
requests
numpy
tf_keras
```

### Python
```txt
pip install Flask deepface opencv-python pillow requests numpy tf_keras
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