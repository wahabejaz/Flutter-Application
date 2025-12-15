Build a simple but attractive Flutter mobile application titled:
“Medicine Reminder App: A Smart Medication Tracking & Notification System.”

The app is for a university semester project, so keep it simple, easy to understand, and beginner-friendly.
Use clean code, meaningful naming, and proper comments throughout.

📌 Project Requirements
1. UI Implementation

I will provide the UI designs for few screens.
Use those exact UI designs to build the interface and for screens design isn't provided, make similiar matching design UI for those screens.
UI designs have been attached in @UI schema folder.

Do not create your own design.
Match layout, spacing, colors, and structure according to the designs I provide.

📌 2. Core Features
A. User Interface Module

Splash Screen

Home Screen showing:

Today’s medicine reminders

Buttons for:

Add Medicine

View All Medicines

History

Add Medicine Screen:

Medicine name input

Dosage input

Time picker for reminder time

All Medicines Screen:

List of all reminders

Edit button

Delete button

History Screen:

Show taken / missed medicines

Simple list layout

📌 3. Medicine Management Module

Add new medicine

Edit medicine

Delete medicine

Store everything in SQLite only

Use sqflite package

Create tables:

Medicines table

History table

CRUD operations must be fully implemented

Database helper class in a separate file with comments

📌 4. Notifications Module

Use flutter_local_notifications package

Schedule a notification at the selected time

When notification appears:

Mark as Taken

Mark as Missed

Store the result in SQLite history table

📌 5. History Module

Track daily medicine intake

Show list:

Medicine name

Scheduled time

Status (taken/missed)

Simple and minimal UI—follow my provided design.

📌 6. Technology Stack

Flutter SDK

Dart

SQLite using sqflite

flutter_local_notifications

State management: setState or simple Provider (no Bloc, no GetX, no Riverpod)


📌 8. Deliverables

The AI must generate:

✔ Complete Flutter project code
✔ All screens according to my provided UI designs
✔ SQLite database helper class
✔ CRUD operations
✔ Notification scheduling logic
✔ History tracking implementation
✔ Comments in every class and function
✔ Clear explanations:

How database works

How notifications work

How to run the project

How to test notifications

📌 Final Instruction to the AI Tool

Keep the whole project attractive and perfect for a student-level semester assignment.
Use only SQLite (no Hive).
Strictly follow the UI that I provide.
Ensure clean code, proper comments, and readable structure.