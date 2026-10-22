# Quick start

## Requirements

- macOS with Xcode 26+ and an iOS 26+ simulator, or a Mac running macOS 26+.
- Git LFS. The bundled SwiftData library is about 196 MiB and is stored in LFS.

## Build and run

1. Clone the repository, then run `git lfs install` and `git lfs pull` in the project directory.
2. Open `SerenesForest.xcodeproj` in Xcode.
3. Select the **SerenesForest** scheme and an iPhone simulator or **My Mac**.
4. Build and run. The preloaded database is copied into the app's writable storage on first launch; no initial content download is needed.

For a physical device, choose your Apple development team and set your own bundle identifier in Xcode. The project does not contain signing credentials.

## Where to start in the code

- `Sources/App`: application entry point and database setup.
- `Sources/Domain`, `Sources/Parsing`, `Sources/Mapping`: models, article parsers, and presentation mapping.
- `Sources/Screens`: SwiftUI screens and `@Observable` view models by feature.
- `Sources/Data`: preloaded catalog, sync, translation, and image loading.
- `Sources/LocalPackages/SerenesParsing`: standalone parsing module.
- `Sources/LocalPackages/SerenesNavigation`: article routes and navigation state for the SwiftUI stack.

Run `swift test --package-path Sources/LocalPackages/SerenesParsing` for the module tests. The article library and media URL index live in `Resources/PreloadedLibrary`; images cache on demand; source JSON build inputs are generated separately and are not part of the repository.

## Content attribution

This is an unofficial companion app. Serenes Forest and Fire Emblem Wiki articles and images retain their source links in the app. Their authors and respective reuse terms apply to that content; this repository does not grant a new license to third-party material. See the main README for data refresh instructions and the bundled GFDL text for wiki articles.
