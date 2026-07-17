# Cockpit27 Demo

A visionOS application demonstrating an immersive Airbus Cockpit experience, built natively with RealityKit and Reality Composer Pro 3 Beta.

## Architecture

This project is built using a monorepo structure, utilizing local Swift Packages to strictly separate concerns and improve compile times:

- **Cockpit27 (App Target)**: The main entry point, containing the SwiftUI lifecycle and root views.
- **Cockpit27Shared**: A local Swift Package containing shared UI components, simulation logic, and extensions.
- **RealityKitContent**: A natively-generated Reality Composer Pro 3 bundle wrapped in a Swift Package. It contains all 3D assets, materials, and volumetric configurations.

## Development Setup

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to manage the Xcode project file programmatically and prevent merge conflicts.

### Prerequisites
- macOS Sequoia (or later)
- Xcode 16 Beta
- Reality Composer Pro 3 Beta
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Generating the Project
Do **not** edit the `.xcodeproj` file directly, as it is ephemeral and ignored by Git. If you add new source files, update the configuration if necessary and regenerate:

```bash
xcodegen
```

This will automatically link the `Cockpit27Shared` and `RealityKitContent` packages to the main app target.

## License

All rights reserved.
