```markdown
# Retracker

## Overview
This project is a Flutter application that integrates with Firebase to manage subjects and their details. It includes features like navigation, data fetching from Firebase, and a user-friendly interface.

## Prerequisites
- Flutter SDK
- Dart SDK
- Android Studio
- Firebase account

## Installation

### Step 1: Clone the Repository
Clone the repository to your local machine using the following command:
```sh
git clone https://github.com/imnexerio/retracker.git
```

### Step 2: Install Flutter and Dart
Ensure you have Flutter and Dart installed. You can download them from the [official Flutter website](https://flutter-ko.dev/development/tools/sdk/releases).

### Step 3: Set Up Firebase
1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Create a new project(with any name).
3. initiate realtime database and email/password authentication in firebase console.
4. run-flutterfire configure(remember to run this command in the root of your flutter project and make sure you have the firebase-tools installed)
5. use android package name: com.imnexerio.retracker (otherwise android app will not build)
5. turn on email/password authentication in the Firebase Console.
6. turm on realtime database in the Firebase Console.
    ```
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

### Step 4: Install Dependencies
Navigate to the project directory and run the following command to install dependencies:
```sh
flutter pub get
```

## Development

### Step 1: Open the Project in Android Studio
1. Open Android Studio.
2. Select `Open an existing Android Studio project`.
3. Navigate to the cloned repository and open it.

### Step 2: Run the Application
1. Connect an Android device or start an Android emulator.
2. Click on the `Run` button in Android Studio or use the following command:
    ```sh
    flutter run
    ```

### Step 3: Modify Code
You can start modifying the code in the `lib` directory. 

## License
This project is licensed under the MIT License - see the `LICENSE` file for details.
```

This README provides a step-by-step guide to install and develop the Flutter application integrated with Firebase.