# iOS-Logger-Swift 

A logging utility written in Swift. 

* Multiple log levels
* Output to File and Console

## Usage 

Import the Logger.swift file to your project and that's it!

Set Log Levels and Output Medium from the Logger.swift file itself

``` swift
Logger.info("Information")
Logger.warn("Warnings")
Logger.debug("Debugging Statement")
Logger.parse("Parsing Info")
Logger.error("Error")
```

## Log Presenter
Recently, while working on a project, need was to check logs on device while it was not connected to the machine. _LogPresenter_ extends _Logger_ by displaying log on the device itself.

### How to Use Log Presenter?
* Drag the Logger folder inside your project. 
* Setup by calling  ``` LogPresenter.setupOnDeviceWindow() ``` from ``` func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions:) ```
* Press volume up/down button for a long duration (3 seconds) or press to show/dismiss the window

_PS: Do not use it in release mode. This might get you banned from the app store._
