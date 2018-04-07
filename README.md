![Apptivator Banner](./Resources/banner.png)

With Apptivator, you can create global hotkeys that will activate chosen apps (or scripts/anything executable) with predefined shortcuts. This means you can have a shortcut to show/hide/execute any application at any time!

I created this because I liked iTerm2's concept of a "hotkey" window, and I wanted to try kitty as my main terminal for a while and found I couldn't live without a window I could activate at any time. So, I created this in order to have a global hotkey to activate/deactivate kitty (and any other apps) at the touch of a button.

It's also sometimes useful to run a script easily via a keyboard shortcut.

## Installation

Simply download the dmg from the [releases](https://github.com/acheronfail/apptivator/releases) tab and drag Apptivator.app into your `/Applications` folder.

![screenshot of apptivator](./Resources/screenshot.png)

## Usage

It's simple really. Once Apptivator is running you'll see an icon in your menubar - click it to enable/disable Apptivator's functionality. You can open the shortcuts window by right-clicking on the icon and choosing it from the menu.

In the menu, select an application (or exectuable) from the Finder (or optionally choose from running applications) and register a shortcut for it. From now on (as long as Apptivator is enabled) you can activate that application via the shortcut you set for it.

#### Options

Apptivator provides some neat options:

* **Automatically hide when app loses focus**
	- When enabled, if an application in the list loses focus then Apptivator will automatically hide that application for you.
* **Show on the screen with mouse**
	- When this is on, then when activated the application will show up on whichever monitor your mouse is on.
* **Hide when active and shortcut is fired**
	- If this is set then when you press the shortcut the application will hide if it's shown, or be shown if it's hidden.
* **Launch app if it's not running**
	- When set, if the application is fired then Apptivator will attempt to launch it.
	- There are some known issues with this at the moment, see: [#18](https://github.com/acheronfail/apptivator/issues/18)
* **Launch Apptivator at login**
	- self-explanatory

## Questions/Concerns

* **When I activate my app its window doesn't appear**
	- Set the application to appear on all spaces. This can be done by right-clicking on the icon in the dock and selecting -> `Options` -> `All Desktops` (see [#12](https://github.com/acheronfail/apptivator/issues/12#issuecomment-370787813) for a discussion and ways to automate this).
* **Activating my app always moves my computer to another space**
	- This behaviour can be adjusted by going to `System Preferences` -> `Mission Control` -> and enabling/disabling the checkbox: `When switching to an application, switch to a Space with open windows for the application`
* **Apptivator doesn't run my executable/script**
	- Ensure that the file has execute permissions! Run `chmod +x path/to/file` to be sure.

## Developing

#### Setting up the project

Apptivator uses `carthage` to manage its dependencies (you can install it with `brew`). To build Apptivator on your machine:

```bash
# Clone the repository
git clone git@github.com:acheronfail/apptivator.git && cd apptivator
# Install dependencies with carthage
carthage update --platform macos
# Open the project
open Apptivator.xcodeproj
```

Once you've opened the Xcode project, it should be enough to make your changes and then just hit the build/run button and go from there.

#### Creating a DMG

The process to create build artefacts for this app is extremely simple:

1. Archive a build in Xcode (`Products` -> `Archive`)
2. Export the app
3. Run [`create-dmg`](https://github.com/sindresorhus/create-dmg)
4. 🎉

## License

[MIT](./LICENSE)
