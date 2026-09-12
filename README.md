# Good Catch for iPhone — 2.7.0 source project

Status: source prepared on Windows. NOT compiled, Apple-signed, installed on an iPhone, or uploaded to TestFlight. This ZIP is not an installable app or IPA. Native compilation may reveal issues that must be resolved in Xcode before distribution.

## What is included

A native SwiftUI iOS app targeting iOS 16 or newer with a dark metallic interface, multiple-photo picker, persistent photo queue, location shortcuts and custom location, all Android 2.7 report settings, response-copy preference, embedded Smartsheet form, current-photo attachment, Go to Submit, expandable form view and manually confirmed Next Report.

New users start with blank names and emails. Settings and queue copies are stored in the app's local Application Support folder, excluded from device backup. Selected photos are converted to JPEG for upload compatibility and receive generated filenames. Up to 50 photos can be selected per batch; source and converted images are limited to 20 MB each. The app copies selected photos into its private storage. Replacing the queue removes its old copies, not the original photo-library images.

The form-filling JavaScript is copied from the Android 2.7 app. It relies on the supported Good Catch form's field layout; editing the URL does not make unrelated forms compatible. Each report must be reviewed for accuracy. CAPTCHA and Smartsheet's own Submit button stay manual. Go to Submit only scrolls; it does not send the report. Photo delivery into the file input does not prove server upload completion. Use the form's Browse control as a manual fallback if attachment fails.

## Build and test on a Mac

1. Install a current Xcode supporting iOS 16 deployment and open GoodCatch.xcodeproj. No third-party packages or project generator are required.
2. Select the GoodCatch scheme and an iPhone simulator. Build and Run. A paid Apple Developer membership is not needed for simulator compilation.
3. Resolve any compiler or runtime issues, then complete Tests/DEVICE-CHECKLIST.md. The Windows checks are not a replacement for this step.
4. For a connected iPhone, choose your signing team under Signing & Capabilities and change the bundle identifier to one your team controls. Configure signing in Xcode; never share account passwords or private keys in this ZIP.

Command-line simulator build on a Mac:

    xcodebuild -project GoodCatch.xcodeproj -scheme GoodCatch -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

## Share with friends through TestFlight

You need Apple Developer Program membership and a build made with Xcode or an authorized Mac build service. This workspace has neither a Mac nor your Apple developer signing setup, so no IPA or TestFlight invitation has been generated.

After successful device testing, configure the signing team and bundle identifier, create the matching App Store Connect app record, select a generic iOS device destination in Xcode, and use Product > Archive. Distribute the archive to App Store Connect. Complete the required app information and beta review details. Invite friends as external TestFlight testers once Apple approves the beta for external testing. TestFlight is for beta distribution; it is not a permanent unrestricted APK-style installer.

Review the privacy disclosures for the actual form and its third-party services before distribution. The selected report details and photos are sent to the Smartsheet form the user chooses to submit. Do not describe this as an offline-only app. Apple review and Smartsheet WebView compatibility are not guaranteed.

Apple references:
- https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases
- https://developer.apple.com/testflight/
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers

## Checks performed here

Node's built-in JavaScript runtime checks binary photo assembly, generated File metadata, change/input notifications, disabled and missing attachment inputs, empty file rejection, stale transfer rejection, fill.js syntax and static safeguards against submission calls. See TEST-RESULTS.md. These checks do not establish Safari or WKWebView compatibility.

Run: node Tests/attachment.test.cjs
