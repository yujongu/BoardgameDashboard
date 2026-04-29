---
name: UI verification required before reporting done
description: Never report a UI task complete without visually verifying in a simulator
type: feedback
---

Always run `flutter run` and visually verify UI changes in a simulator before declaring a UI task done. Static analysis and tests are not sufficient.

**Why:** Claude reported UI fixes as complete twice without actually verifying visually, forcing the user to ask for corrections a second time.

**How to apply:** On any task that touches widget/screen files, explicitly run the app and confirm the UI looks correct. If no simulator is available, say so explicitly rather than claiming success. The `flutter analyze` hook will flag code issues automatically, but layout bugs, overflow, wrong colors, and missing widgets only show up visually.
