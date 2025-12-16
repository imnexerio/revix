# revix

A powerful Flutter-based task scheduling and productivity application integrated with Firebase for secure data storage and authentication, featuring AI-powered assistance for enhanced productivity.

[![Build, Deploy & Release](https://github.com/imnexerio/revix/actions/workflows/build.yml/badge.svg)](https://github.com/imnexerio/revix/actions/workflows/build.yml)
[![GitHub Release](https://img.shields.io/github/v/release/imnexerio/revix?include_prereleases)](https://github.com/imnexerio/revix/releases)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

## 📋 Overview

revix is a comprehensive task management solution designed to help you organize, schedule, and track your tasks efficiently. Built with Flutter and powered by Firebase, it provides a seamless cross-platform experience with real-time synchronization and advanced features.

## 🎯 App Screenshots

### Preview Gallery

<div align="center">
  <img src="public-portfolio/preview.png" alt="App Preview" width="600" style="max-width: 80%; height: auto; margin-bottom: 20px;"/>
</div>

<div align="center">
   <img src="public-portfolio/preview1.png" alt="App Screenshot 1" width="600" style="max-width: 80%; height: auto; margin-bottom: 20px;"/>
</div>
<div align="center">
   <img src="public-portfolio/preview.gif" alt="App Demo" width="600" style="max-width: 80%; height: auto; margin-bottom: 20px;"/>
</div>

## ✨ Key Features

### 🔐 Authentication & Security
- Secure user authentication via email/password
- Firebase-powered user management
- Protected user data storage

### 📱 Task Management
- **Add Entry Form**: Streamlined entry creation interface
- **Schedule Tracking**: Comprehensive scheduling system with today's view
- **Task Details**: Detailed view for each task with full information
- **Real-time Synchronization**: Instant updates across all devices

### 🤖 AI Integration
- **AI Chat Assistant**: Built-in AI chat powered by Gemini API
- **Smart Recommendations**: AI-powered task suggestions and productivity tips
- **Chat History**: Persistent conversation history for reference
- **Model Selection**: Choose from different AI models for varied assistance

### 🎨 Customization
- **Dynamic Theming**: Custom theme generator with multiple color schemes
- **Profile Management**: Personalized user profiles with customizable settings
- **Responsive Design**: Optimized for various screen sizes and orientations

### 📊 Analytics & Tracking
- **Progress Visualization**: Charts and graphs using FL Chart
- **Task Statistics**: Comprehensive tracking of task completion rates
- **Home Widget**: Quick access to tasks directly from home screen (Android)

### 🔧 Technical Features
- **Cross-platform Support**: Android, iOS, Web, and Desktop ready
- **Offline Capability**: Local data storage using Hive database
- **Image Support**: Task attachments with image compression
- **URL Launcher**: Direct links to external resources
- **Package Info**: App version and build information tracking

## 🔧 Prerequisites

Before getting started, ensure you have the following installed on your development machine:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.5.4+ recommended)
- [Dart SDK](https://dart.dev/get-dart) (included with Flutter)
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/) with Flutter extensions
- [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`)
- A [Firebase](https://console.firebase.google.com/) account
- [Git](https://git-scm.com/) for version control

## 🏗️ Tech Stack

### Frontend Framework
- **Flutter**: Cross-platform UI framework
- **Dart**: Programming language

### Backend Services
- **Firebase Core**: Backend infrastructure
- **Firebase Database**: Real-time database
- **Firebase Auth**: Authentication service
- **Firebase Storage**: File storage

### AI Integration
- **Gemini API**: AI-powered chat assistant
- **Custom AI Models**: Multiple model selection

### Local Storage
- **Hive**: Fast, lightweight local database
- **Shared Preferences**: Key-value storage

### Additional Libraries
- **FL Chart**: Data visualization
- **Provider**: State management
- **Image Picker**: Camera and gallery access
- **URL Launcher**: External link handling
- **Path Provider**: File system access

### Desktop (Tauri)
- **Tauri**: Rust-based framework for building lightweight desktop applications
- **WebView**: Native webview for rendering Flutter web builds
- **Auto-updater**: Built-in update mechanism for desktop apps

## 🚀 Installation

### Step 1: Clone the Repository

```sh
git clone https://github.com/imnexerio/revix.git
cd revix
```

### Step 2: Set Up Firebase

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Create a new project (with any name of your choice)
3. Set up Realtime Database:
   - Navigate to "Realtime Database" in the Firebase console
   - Click "Create Database"
   - Start in test mode, then switch to the rules below
4. Set up Firebase Storage:
   - Navigate to "Storage" in the Firebase console
   - Click "Get started" and follow the setup wizard
5. Enable Email/Password Authentication:
   - Navigate to "Authentication" in the Firebase console
   - Under "Sign-in method", enable "Email/Password"
6. Configure Flutter project with Firebase:
   ```sh
   # Install FlutterFire CLI if not already installed
   dart pub global activate flutterfire_cli
   
   # Configure Firebase for your Flutter project
   flutterfire configure
   ```
   - Select the Firebase project you created
   - **Important**: Use `com.imnexerio.revix` as the Android package name
7. Update Realtime Database Rules:
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

### Step 3: Set Up Google Calendar API for Public Holidays

To enable public holiday fetching:

1. **Create Google Cloud Project**:
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project (e.g., "Revix Holidays")

2. **Enable Google Calendar API**:
   - Navigate to "APIs & Services" → "Library"
   - Search for "Google Calendar API" and enable it

3. **Create API Key**:
   - Go to "APIs & Services" → "Credentials"
   - Click "+ CREATE CREDENTIALS" → "API key"
   - Copy the generated API key (e.g., `AIzaSyD...`)

4. **Add API Key to Code**:
   - Open `lib/Utils/PublicHolidayFetcher.dart`
   - Replace `YOUR_API_KEY_HERE` with your actual API key:
   ```dart
   static const String GOOGLE_API_KEY = 'AIzaSyD...your-actual-key...';
   ```

5. **Restrict API Key (Recommended)**:
   - In Google Cloud Console, click on your API key
   - Under "API restrictions", select "Google Calendar API" only
   - Under "Application restrictions", add your package: `com.imnexerio.revix`

6. **Supported Countries**:
   - 🇮🇳 India, 🇺🇸 US, 🇬🇧 UK, 🇨🇦 Canada, 🇦🇺 Australia
   - 🇩🇪 Germany, 🇫🇷 France, 🇯🇵 Japan, 🇨🇳 China, 🇧🇷 Brazil
   - 🇲🇽 Mexico, 🇮🇹 Italy, 🇪🇸 Spain, 🇰🇷 South Korea
   - 🇵🇰 Pakistan, 🇧🇩 Bangladesh, 🇸🇬 Singapore, 🇲🇾 Malaysia
   - 🇮🇩 Indonesia, 🇹🇭 Thailand, and more...

**Free Tier**: 10,000 requests/day (more than enough for personal use)

### Step 4: Set Up AI Features (Optional)

To enable AI chat functionality:

1. Get a Gemini API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
2. The app will prompt you to enter your API key on first use of the AI chat feature
3. API keys are stored securely using local storage

### Step 5: Install Dependencies

```sh
flutter pub get
```

### Step 6: Run the Application

```sh
flutter run
```

## 🎮 Usage Guide

### Getting Started
1. **Sign Up/Login**: Create a new account or login with existing credentials
2. **Add Entries**: Use the "Add Entry" form to create new entries
3. **Schedule View**: Check your daily schedule in the "Today" section
4. **AI Assistant**: Access the AI chat for productivity tips and task suggestions

### Key Features Usage
- **Task Management**: Tap on any task to view detailed information
- **Public Holidays**: Navigate to Settings → Data Management to fetch holidays for your country
- **AI Chat**: Navigate to the chat section for AI-powered assistance
- **Settings**: Customize themes, manage profile, and configure preferences
- **Home Widget**: Enable for quick task access from your home screen (Android)

## 📱 Supported Platforms

- ✅ **Android** (Primary platform with extra features)
- ✅ **iOS** (Full feature support)
- ✅ **Web** (Progressive Web App)
- ✅ **Windows** (Desktop application via Tauri)
- ✅ **macOS** (Desktop application via Tauri - Intel & Apple Silicon)
- ✅ **Linux** (Desktop application via Tauri - AppImage, DEB)

## 📥 Download

### Latest Release

Download the latest version for your platform from the [Releases Page](https://github.com/imnexerio/revix/releases/latest):

| Platform | Download | Format |
|----------|----------|--------|
| **Android** | [Download APK](https://github.com/imnexerio/revix/releases/latest) | `.apk` |
| **Windows** | [Download Installer](https://github.com/imnexerio/revix/releases/latest) | `.msi` / `.exe` / Portable `.zip` |
| **macOS (Apple Silicon)** | [Download DMG](https://github.com/imnexerio/revix/releases/latest) | `.dmg` |
| **macOS (Intel)** | [Download DMG](https://github.com/imnexerio/revix/releases/latest) | `.dmg` |
| **Linux** | [Download](https://github.com/imnexerio/revix/releases/latest) | `.AppImage` / `.deb` / Portable `.tar.gz` |
| **Web** | [Live App](https://revix-e86ea.web.app) | Browser |

> 💡 **Note**: All builds are automatically generated via GitHub Actions CI/CD pipeline.

## 🔧 Configuration

### Firebase Configuration
Ensure your Firebase configuration files are properly placed:
- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`
- Web: `web/firebase-config.js`

## 🔍 Troubleshooting

### Common Issues

1. **Firebase Connection Issues**
   - Verify that `flutterfire configure` completed successfully
   - Check that the package name matches `com.imnexerio.revix`
   - Ensure the Firebase configuration files are in the correct locations
   - Verify Firebase project has the necessary services enabled

2. **Build Failures**
   - Run `flutter clean` followed by `flutter pub get`
   - Ensure Android SDK is properly configured
   - Check that all required permissions are granted

3. **AI Chat Issues**
   - Verify Gemini API key is valid and properly entered
   - Check internet connectivity
   - Ensure API quota hasn't been exceeded

4. **Public Holiday Fetcher Issues**
   - Verify Google Calendar API is enabled in your Google Cloud project
   - Check that API key is correctly set in `PublicHolidayFetcher.dart`
   - Ensure you haven't exceeded the free tier quota (10,000 requests/day)
   - Try selecting a different country if one doesn't work

5. **Home Widget Issues (Android)**
   - Verify home widget permissions are granted
   - Check that the widget is properly added to the home screen
   - Ensure background processing permissions are enabled

### Debug Commands
```sh
# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Check for dependency issues
flutter pub deps
flutter doctor

# Debug Firebase connection
flutterfire configure --project=your-project-id
```

## 🚀 Performance Optimization

- **Local Caching**: Uses Hive for fast local data access
- **Image Compression**: Automatic image optimization for storage
- **Lazy Loading**: Efficient memory usage with on-demand loading
- **Background Services**: Minimal battery impact with optimized background tasks

## � CI/CD Pipeline

This project uses **GitHub Actions** for automated builds, deployments, and releases.

### Automated Build Workflow

The CI/CD pipeline is triggered on:
- Push to `main`/`master` branches
- Pull requests to `main`/`master` branches
- Version tags (e.g., `v1.2.3`)
- Manual workflow dispatch

### Build Jobs

| Job | Description | Outputs |
|-----|-------------|---------|
| **build-flutter** | Builds Android APK and Flutter Web | APK, Web artifacts |
| **build-tauri** | Builds desktop apps for all platforms | Windows (MSI, EXE, Portable), Linux (AppImage, DEB, Portable), macOS (DMG for ARM & Intel) |
| **release** | Creates GitHub Release with all artifacts | Automated release with binaries |

### Deployment

- **Firebase Hosting**: Web app is automatically deployed on push to main/master or version tags
- **GitHub Releases**: Created automatically when pushing a version tag (e.g., `git tag v1.2.3 && git push --tags`)

### Creating a New Release

1. Update version in `pubspec.yaml`
2. Commit your changes
3. Create and push a version tag:
   ```sh
   git tag v1.2.3
   git push origin v1.2.3
   ```
4. GitHub Actions will automatically:
   - Build all platform binaries
   - Deploy web app to Firebase Hosting
   - Create a GitHub Release with all artifacts

### Required Secrets

For maintainers setting up the CI/CD pipeline, the following secrets must be configured in GitHub repository settings.

#### How to Add GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Enter the secret name and value
5. Click **Add secret**

<details>
<summary>📱 Android Signing Secrets</summary>

| Secret Name | Description | How to Get It |
|-------------|-------------|---------------|
| `KEYSTORE_BASE64` | Base64 encoded keystore file | Run: `base64 -i upload-keystore.jks` (macOS/Linux) or `certutil -encode upload-keystore.jks encoded.txt` (Windows) |
| `KEYSTORE_PASSWORD` | Keystore password | The password you set when creating the keystore |
| `KEY_ALIAS` | Key alias | The alias you specified (e.g., `upload`) |
| `KEY_PASSWORD` | Key password | The key password (often same as keystore password) |
| `GOOGLE_SERVICES_JSON` | Base64 encoded google-services.json | Run: `base64 -i android/app/google-services.json` |

**Creating a Keystore (if you don't have one):**
```sh
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

</details>

<details>
<summary>🔥 Firebase Configuration Secrets</summary>

| Secret Name | Description | Where to Find It |
|-------------|-------------|------------------|
| `FIREBASE_SERVICE_ACCOUNT` | Service account JSON for deployment | Firebase Console → Project Settings → Service Accounts → Generate new private key |
| `FIREBASE_PROJECT_ID` | Firebase project ID | Firebase Console → Project Settings → General → Project ID |
| `FIREBASE_API_KEY_WEB` | Web API key | Firebase Console → Project Settings → General → Web API key |
| `FIREBASE_API_KEY_ANDROID` | Android API key | Found in `google-services.json` under `api_key[0].current_key` |
| `FIREBASE_APP_ID_WEB` | Web app ID | Firebase Console → Project Settings → General → Your apps → Web app ID |
| `FIREBASE_APP_ID_ANDROID` | Android app ID | Found in `google-services.json` under `mobilesdk_app_id` |
| `FIREBASE_MESSAGING_SENDER_ID` | Messaging sender ID | Firebase Console → Project Settings → Cloud Messaging → Sender ID |
| `FIREBASE_AUTH_DOMAIN` | Auth domain | Format: `your-project-id.firebaseapp.com` |
| `FIREBASE_DATABASE_URL` | Realtime Database URL | Firebase Console → Realtime Database → Copy URL |
| `FIREBASE_STORAGE_BUCKET` | Storage bucket | Format: `your-project-id.appspot.com` |

</details>

<details>
<summary>🖥️ Tauri Signing Secrets (Optional - for auto-updates)</summary>

| Secret Name | Description | How to Get It |
|-------------|-------------|---------------|
| `TAURI_SIGNING_PRIVATE_KEY` | Tauri signing private key | Generated using Tauri CLI |
| `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` | Signing key password | Password you set during key generation |

**Generating Tauri Signing Keys:**
```sh
npm install -g @tauri-apps/cli
tauri signer generate -w ~/.tauri/revix.key
```

This will output a public key and save the private key. Add the private key content to `TAURI_SIGNING_PRIVATE_KEY`.

</details>

## �🔒 Security & Privacy

- **Data Encryption**: All user data is encrypted in transit and at rest
- **Authentication**: Secure Firebase authentication
- **API Security**: Secure API key management
- **Privacy**: No personal data is shared with third parties

## 📈 Version History

- **v1.2.1**: Current version with AI integration and enhanced UI
- **v1.2.0**: Added AI chat functionality and improved theming
- **v1.1.0**: Introduced home widget support and enhanced task management
- **v1.0.0**: Initial release with core task management features

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### How to Contribute

1. **Fork the repository**
2. **Create your feature branch**
   ```sh
   git checkout -b feature/amazing-feature
   ```
3. **Commit your changes**
   ```sh
   git commit -m 'Add some amazing feature'
   ```
4. **Push to the branch**
   ```sh
   git push origin feature/amazing-feature
   ```
5. **Open a Pull Request**

### Development Guidelines

- Follow Flutter/Dart best practices
- Ensure all tests pass before submitting
- Update documentation for new features
- Follow the existing code style and formatting
- Add appropriate comments for complex logic

### Areas for Contribution

- 🐛 Bug fixes
- ✨ New features
- 📚 Documentation improvements
- 🎨 UI/UX enhancements
- 🔧 Performance optimizations
- 🧪 Test coverage improvements

## 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## 📬 Contact & Support

- **Developer**: [imnexerio](https://github.com/imnexerio)
- **Project Repository**: [https://github.com/imnexerio/revix](https://github.com/imnexerio/revix)
- **Issues**: [Report bugs or request features](https://github.com/imnexerio/revix/issues)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for robust backend services
- Google AI for Gemini API integration
- Open source community for various packages and libraries

---

<div align="center">
  <p>Made with ❤️ by <a href="https://github.com/imnexerio">imnexerio</a></p>
  <p>⭐ Star this repo if you find it helpful!</p>
</div>
