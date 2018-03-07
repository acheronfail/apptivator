![Apptivator Banner](./Resources/banner.png)

With Apptivator, you can create global hotkeys that will activate chosen apps with a predefined shortcuts. This means you can have a shortcut to show/hide any application at any time.

I created this because I liked iTerm2's concept of a "hotkey" window, but I prefer to use kitty as my main terminal. So I created this so I could have a global hotkey to activate/deactivate kitty at the touch of a button.

## Installation

Simply download the dmg from the [releases](https://github.com/acheronfail/apptivator/releases) tab and drag Apptivator.app into your `/Applications` folder.

## Usage

It's simple really. Once Apptivator is running you'll see an icon in your menubar - click it to enable/disable Apptivator's functionality. You can open the shortcuts window by right-clicking on the icon and choosing it from the menu.

In the menu, select an application (or exectuable) from the Finder (or optionally choose from running applications) and register a shortcut for it. From now on (as long as Apptivator is enabled) you can activate that application via the shortcut you set for it.

#### Options

Apptivator provides some neat options:

* **Automatically hide apps when they lose focus**
	- When enabled, if an application in the list loses focus then Apptivator will automatically hide that application for you.
* **Hide apps when active and shortcut is fired**
	- If this is set then when you press the shortcut the application will hide if it's shown, or be shown if it's hidden.
* **Launch apps if they're not running**
	- When set, if the application is fired then Apptivator will attempt to launch it.
	- There are some known issues with this at the moment, see: [#18](https://github.com/acheronfail/apptivator/issues/18)
* **Launch Apptivator at login**
	- self-explanatory

## License

[MIT](./LICENSE)
