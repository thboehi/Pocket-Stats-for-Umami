# Contributing

Thanks for helping improve Pocket Stats for Umami!

## Bugs and ideas

Open an issue. For a bug, include:
- the app version (Settings);
- your device and iOS version;
- your Umami version (self-hosted v2 or v3, or Umami Cloud);
- the steps to reproduce.

Never paste passwords, API keys, tokens or share links of private websites into an issue.

## Pull requests

1. Read the [development guide](docs/DEVELOPMENT.md) first: it lists the rules the code follows (native SwiftUI components, loading in models rather than list rows, every API feature in both `UmamiClient` and `DemoService`…).
2. Keep the change focused, and match the style of the surrounding code.
3. Translate every new string into French and German in `Shared/Localizable.xcstrings`.
4. Check the change on iPhone and iPad, in light and dark mode, and in demo mode.
5. Never test write operations (create, edit, delete, reset) on websites you care about.

## License of contributions

By submitting a contribution, you confirm that you wrote it or have the right to submit it, and you agree that:
- it is licensed to everyone under the project's [PolyForm Shield License 1.0.0](LICENSE.md);
- the author of the project, Thomas Böhi, may also use, modify and distribute it under any terms, including in the App Store version of the app.
