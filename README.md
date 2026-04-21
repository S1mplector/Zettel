# Zettel

Zettel is a macOS menu bar app built with SwiftUI and AppKit. It stores notes as a hierarchical node tree, so you can create structures like `2026 -> Swift -> Research` and attach rich text or pasted images to every node.

## Features

- Menu bar app shell with a reopenable main window
- Recursive node tree with root and child creation
- Inline node renaming and node deletion
- Rich text editing backed by `NSTextView`
- Image pasting support inside node content
- Versioned staged persistence in `~/Library/Application Support/Zettel/Store`
- Automatic migration from the older single-file `nodes.json` store

## Run

Open `Package.swift` in Xcode and run the `Zettel` executable target, or launch it from Terminal:

```bash
swift run Zettel
```

## Package

Build a lightweight local `.dmg` and copy it to the Desktop:

```bash
make dmg
```

The script builds the release binary, wraps it in a minimal `.app` bundle, creates `dist/Zettel.dmg`, and copies the same file to `~/Desktop/Zettel.dmg`.

## Notes

The current environment only has the macOS Command Line Tools installed, so `swift build` works, but `swift test` requires full Xcode because XCTest is unavailable here.
