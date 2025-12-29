# Medicine Reminder App (Flutter)

## Team Members
- Abuzar
- Zaraar
- Wahab Ejaz

## Description
A Flutter-based Medicine Reminder app using Firebase Authentication
and SQLite for local storage.

## Features
- User Authentication
- Medicine Scheduling
- Refill Tracking
- History Logs
- Local Notifications
- AI-Generated Medicine Information (Gemini API)

## Technologies
- Flutter (Dart)
- Firebase Authentication
- SQLite
- Google Gemini AI (for medicine information)

## Setup

### AI Features Setup
The app includes AI-generated medicine information using Google Gemini API.

1. Get a Gemini API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create a `.env` file in the project root
3. Add your API key to the `.env` file:
   ```
   GEMINI_API_KEY=your_actual_api_key_here
   ```
4. The app will automatically load the API key from environment variables

**Note:** The `.env` file is already added to `.gitignore` for security.

## APK
APK is available in GitHub Releases.
