# BajetKu Finance Tracker

A simple, beautiful personal finance app built with Flutter.

## Getting Started

### Prerequisites
- Flutter SDK installed
- VS Code or Android Studio
- Connected device (iPhone or Android)

### How to Run on Android Phone
1.  **Enable Developer Mode**: Go to Settings > About Phone > Tap "Build Number" 7 times.
2.  **Enable USB Debugging**: Go to Settings > System > Developer Options > Toggle "USB Debugging".
3.  **Connect**: Plug your phone into your laptop via USB.
4.  **Accept**: Accept the "Allow USB Debugging" prompt on your phone screen.
5.  **Run**:
    ```bash
    flutter run
    ```

### How to Run on iPhone (Mac only)
1.  **Open Project in Xcode**:
    ```bash
    open ios/Runner.xcworkspace
    ```
2.  **Signing**:
    - In Xcode, select the "Runner" project in the left navigator.
    - Go to "Signing & Capabilities".
    - Select your personal "Team" (you may need to log in with your Apple ID).
    - Change the "Bundle Identifier" if needed (e.g., `com.yourname.bajetku`).
3.  **Connect**: Plug your iPhone into your Mac.
4.  **Trust**: On your iPhone, verify you trust the computer if asked.
5.  **Run**: You can run from Xcode (Play button) or terminal:
    ```bash
    flutter run
    ```
    *Note: If using a free Apple account, the provisioning profile usually lasts 7 days.*

### Simulator/Emulator
- **iOS**: Run `open -a Simulator`
- **Android**: Launch your AVD from Android Studio.
