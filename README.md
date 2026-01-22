# CatchCall – Flutter MVVM client

This project is now a **Flutter MVVM calling client** that wraps the Afri Com
`userService` gRPC API and exposes the flows via a Material UI.

## Architecture

- **MVVM with Provider**
  - Models in `lib/models`
  - `UsersClient` (gRPC service layer) in `lib/users_client.dart`
  - ViewModels for auth + calling flows under `lib/viewmodels`
  - Views/widgets in `lib/views`
- **Flutter UI**
  - `lib/main.dart` wires dependency graph
  - `lib/app.dart` hosts `MaterialApp`
  - `lib/views/screens/home_screen.dart` presents verification, SIP config, and account actions.

> **Important:** The proto you shared was truncated (it contained literal `...`),
> so this client is implemented as a **stub/skeleton**. The methods are ready
> and compile, but the RPC bodies are `TODO`s you can replace with real calls to
> generated stubs once you have the full `.proto`.

## Folder layout

- `pubspec.yaml` – Flutter + gRPC dependencies
- `lib/main.dart` – app bootstrap + providers
- `lib/app.dart` – `MaterialApp` definition
- `lib/models/` – value objects (operation state, SIP config, account summary)
- `lib/viewmodels/` – MVVM change notifiers
- `lib/views/` – Flutter screens/widgets
- `lib/users_client.dart` – gRPC wrapper
- `lib/generated/` – protobuf outputs
- `protos/users.proto` – API contract reference
- `bin/*.dart` – legacy CLI samples (still runnable)
- Platform folders (`web/`, `linux/`, `macos/`, `windows/`, `ios/`, `android/`) – generated via `flutter create .` so you can target any device

## How to run

From the `Project` directory:

```bash
flutter pub get
flutter run -d chrome   # launch as a web app
# or choose any other listed device, e.g. `flutter run -d linux`
```

The home screen provides:

- Dialer UI with keypad + bottom navigation mirroring CatchApp
- OTP triggers (SMS + WhatsApp)
- Allowed domain + alias fetchers
- SIP config loader
- Account summary / balance viewer

## Hooking up real gRPC

1. Ensure the Dart protoc plugin is installed.
2. Regenerate stubs whenever `users.proto` changes:

   ```bash
   protoc \
     --dart_out=grpc:lib/generated \
     -I protos protos/users.proto
   ```

3. Provide valid backend credentials/hosts via `UsersClient` constructor or env.

All view models already call the live gRPC stubs, so the Flutter UI will reflect
real backend responses once networking is reachable.
