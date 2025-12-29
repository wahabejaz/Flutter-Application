# Medicine Reminder App

[![Flutter](https://img.shields.io/badge/Flutter-3.8.1-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.8.1-blue.svg)](https://dart.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive Flutter-based mobile application designed to help users manage their medication schedules effectively. Built with Firebase Authentication for secure user management, SQLite for local data storage, and integrated with Google Gemini AI for intelligent medicine information.

## 🚀 Features

- **🔐 Secure Authentication**: Firebase-powered user login and registration
- **💊 Medicine Scheduling**: Set up custom medication reminders with flexible timing
- **📅 Refill Tracking**: Monitor medication stock levels and get refill alerts
- **📊 History Logs**: Keep track of taken medications and adherence patterns
- **🔔 Local Notifications**: Receive timely reminders even offline
- **🤖 AI-Powered Insights**: Get detailed medicine information using Google Gemini API
- **🌙 Dark Mode Support**: Comfortable viewing in all lighting conditions
- **📱 Cross-Platform**: Runs on Android, iOS, Web, Windows, Linux, and macOS

## 🛠️ Technologies Used

- **Framework**: Flutter (Dart)
- **Backend Services**:
  - Firebase Authentication
  - Firebase Core
- **Database**: SQLite with sqflite
- **Notifications**: flutter_local_notifications
- **AI Integration**: Google Generative AI (Gemini)
- **State Management**: Provider
- **Other Libraries**:
  - shared_preferences
  - path_provider
  - intl (for date/time formatting)
  - http
  - flutter_dotenv

## 📋 Prerequisites

Before running this project, ensure you have the following installed:

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.8.1 or higher)
- [Dart SDK](https://dart.dev/get-dart) (version 3.8.1 or higher)
- Android Studio or VS Code with Flutter extensions
- For Android development: Android SDK and emulator/device
- For iOS development: Xcode (macOS only)

## 🚀 Installation & Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/medicine-reminder-app.git
   cd medicine-reminder-app
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**:
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Authentication and configure sign-in methods
   - Download `google-services.json` and place it in `android/app/`
   - Update `lib/firebase_options.dart` with your Firebase config

4. **Set up Gemini AI**:
   - Get an API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
   - Create a `.env` file in the project root:
     ```
     GEMINI_API_KEY=your_actual_api_key_here
     ```
   - The app automatically loads the API key from environment variables

5. **Run the app**:
   ```bash
   flutter run
   ```

## 📱 Usage

1. **Sign Up/Login**: Create an account or log in with existing credentials
2. **Add Medications**: Input medicine details, dosage, and schedule
3. **Set Reminders**: Configure notification times and frequencies
4. **Track Refills**: Monitor stock levels and set refill reminders
5. **View History**: Check medication adherence and logs
6. **AI Assistance**: Get detailed information about medications using Gemini AI

## 🏗️ Building for Production

### Android APK
```bash
flutter build apk --release
```

### iOS (macOS only)
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## 🧪 Testing

Run the test suite:
```bash
flutter test
```

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 Development Team

- **Abuzar** - Project Lead & Backend Development
- **Zaraar** - UI/UX Design & Frontend Development
- **Wahab Ejaz** - AI Integration & Testing

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev/) for the amazing cross-platform framework
- [Firebase](https://firebase.google.com/) for authentication and backend services
- [Google Gemini AI](https://ai.google.dev/) for AI-powered medicine information
- [Flutter Community](https://flutter.dev/community) for excellent packages and support

## 📞 Support

If you have any questions or need help, please open an issue on GitHub or contact the development team.

---

**Note**: The `.env` file containing your Gemini API key is already included in `.gitignore` for security purposes. Never commit sensitive information to version control.
