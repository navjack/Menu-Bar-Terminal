# Menu Bar Terminal

A simple macOS application that provides a persistent terminal interface accessible directly from your system menu bar.

## Features

*   **Quick Access:** Open a terminal popover by clicking the icon in the menu bar.
*   **Multi-Session:** Manage multiple independent shell sessions using tabs.
*   **Persistent:** Sessions remain active in the background.
*   **Standard Shell:** Uses your default login shell (`zsh` by default) and inherits your environment variables (including PATH, Homebrew setups, etc.).

## How it Works

The application uses:

*   **SwiftUI:** For the user interface (popover, tabs, text input/output).
*   **AppKit:** To create the menu bar item (`NSStatusItem`) and popover (`NSPopover`).
*   **Pseudo-terminals (PTYs):** To create and manage independent, long-running shell sessions for each tab.

## Getting Started

1.  Clone the repository.
2.  Open `Menu Bar Terminal.xcodeproj` in Xcode.
3.  Build and run the application.
4.  Look for the terminal icon ( resembling `􀪏` ) in your menu bar.

Click the icon to open the popover, type your commands, and manage sessions using the tab bar.