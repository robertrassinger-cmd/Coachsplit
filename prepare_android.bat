@echo off
flutter create . --platforms=android
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release
pause
