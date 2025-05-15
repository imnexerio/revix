# reTracker

![reTracker Logo](https://github.com/user-attachments/assets/3402207c-4d9c-4572-a392-c4c9994816e1)

A Flutter-based task scheduling application integrated with Firebase for secure data storage and authentication.

## 📋 Overview

reTracker helps you organize, schedule, and track your tasks efficiently. Built with Flutter and powered by Firebase, it provides a seamless experience across Android devices.

## ✨ Features

- User authentication via email/password
- Task creation and management
- Schedule tracking
- Real-time data synchronization
- Secure user data storage

## 🔧 Prerequisites

Before getting started, ensure you have the following installed on your development machine:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable version recommended)
- [Dart SDK](https://dart.dev/get-dart) (included with Flutter)
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/) with Flutter extensions
- [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`)
- A [Firebase](https://console.firebase.google.com/) account

## 🚀 Installation

### Step 1: Clone the Repository

```sh
git clone https://github.com/imnexerio/retracker.git
cd retracker
```

### Step 2: Set Up Firebase

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Create a new project (with any name of your choice)
3. Set up Realtime Database:
   - Navigate to "Realtime Database" in the Firebase console
   - Click "Create Database"
   - Start in test mode, then switch to the rules below
4. Enable Email/Password Authentication:
   - Navigate to "Authentication" in the Firebase console
   - Under "Sign-in method", enable "Email/Password"
5. Configure Flutter project with Firebase:
   ```sh
   # Install FlutterFire CLI if not already installed
   dart pub global activate flutterfire_cli
   
   # Configure Firebase for your Flutter project
   flutterfire configure
   ```
   - Select the Firebase project you created
   - **Important**: Use `com.imnexerio.retracker` as the Android package name
6. Update Realtime Database Rules:
   ```json
   {
     "rules": {
       "users": {
         "$uid": {
           ".read": "auth != null && auth.uid == $uid",
           ".write": "auth != null && auth.uid == $uid"
         }
       }
     }
   }
   ```

### Step 3: Install Dependencies

```sh
flutter pub get
```

### Step 4: Run the Application

```sh
flutter run
```

## 🔍 Troubleshooting

### Common Issues

1. **Firebase Connection Issues**
   - Verify that `flutterfire configure` completed successfully
   - Check that the package name matches `com.imnexerio.retracker`
   - Ensure the Firebase configuration files are in the correct locations

2. **Build Failures**
   - Run `flutter clean` followed by `flutter pub get`
   - Ensure Android SDK is properly configured

## 📱 Supported Platforms

- Cross-platform (Android, iOS, Web, Desktop*, etc.)
- Android (extra features)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the GNU General Public License - see the [LICENSE](LICENSE) file for details.

## 📬 Contact

Developer: [imnexerio](https://github.com/imnexerio)

Project Link: [https://github.com/imnexerio/retracker](https://github.com/imnexerio/retracker)
