//  MIT License
//
//  Copyright (c) 2017 Tushar Mohan
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import AVFoundation
import UIKit

private enum Constants {
    static let observerKey = "outputVolume"
    static let nibName = "LogConsole"
    static let errorBtnPressMsg = "Some error in detecting volume button press"
    static let errorReadingFile = "Some error in reading log file"
    
    // Change color codes here for different levels
    static let infoColor = UIColor.blue
    static let warnColor = UIColor.orange
    static let debugColor = UIColor.yellow
    static let parseColor = UIColor.magenta
    static let errorColor = UIColor.red
}

class LogPresenter: NSObject {
    
    // Sets up the listeners and inits singleton for displaying log on device
    class func setupOnDeviceWindow() {
        Logger.getLogFile { (logPath) -> (Bool) in
            LogPresenter.sharedInstance.logFilePath = logPath
            return false
        }
    }
    
    private var volumeBtnPressTimer: Timer?
    private var timeElapsed: Double
    private var logFilePath: String?
    private var isConsoleViewPresented: Bool
    
    private static let sharedInstance: LogPresenter = {
        let instance = LogPresenter()
        return instance
    }()
    
    private override init() {
        timeElapsed = 0
        isConsoleViewPresented = false
        super.init()
        listenVolumeButton()
    }
    
    private func listenVolumeButton() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(true)
        } catch {
            Logger.error(Constants.errorBtnPressMsg)
        }
        audioSession.addObserver(self, forKeyPath: Constants.observerKey, options: NSKeyValueObservingOptions.new, context: nil)
    }
    
    internal override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == Constants.observerKey {
            volumeButtonPressed()
        }
    }
    
    //triggers when the volume button is pressed for long
    private func volumeButtonPressed() {
        if volumeBtnPressTimer != nil {
            //permit execution of required method if the button press is long
            if timeElapsed == 3 {
                timeElapsed = 0
                
                pushWKWebViewOverRoot()
            }
            timeElapsed = timeElapsed + 1
            volumeBtnPressTimer!.invalidate()
        }
        
        volumeBtnPressTimer = Timer.init(timeInterval: 0.5, target: self, selector: #selector(timerSet), userInfo: nil, repeats: false)
    }
    
    @objc private func timerSet() {
        if timeElapsed != 0 {
            timeElapsed = 0
        }
    }
    
    // display log view on top of any view controller that is visible currently
    private func pushWKWebViewOverRoot() {
        if !isConsoleViewPresented, let topVC = getTopMostViewController() {
            isConsoleViewPresented = true
            
            let consoleView = configConsoleWith(topVC)
            let consoleNavigation = configNavigationForConsoleWith(root: consoleView)
            
            topVC.present(consoleNavigation, animated: true, completion: nil)
        } else {
            getTopMostViewController()?.dismiss(animated: true, completion: {
                self.isConsoleViewPresented = false
            })
        }
        
    }
    
    //reference to the top most view controller in stack
    private func getTopMostViewController() -> UIViewController? {
        if var topController = UIApplication.shared.keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            return topController
        }
        return nil
    }
    
    // configure the view controller that will contain our logs
    private func configConsoleWith(_ topVC:UIViewController) -> UIViewController {
        let consoleV = UIViewController.init()
        consoleV.view.frame = topVC.view.bounds
        consoleV.view.alpha = 1
        consoleV.view.backgroundColor = UIColor.white
        
        consoleV.navigationItem.title = "Logger by TM 👨🏻‍💻"
        
        let textContainer = configTextViewFor(consoleV)
        consoleV.view.addSubview(textContainer)
        
        return consoleV
    }
    
    // display the log in a text view
    private func configTextViewFor(_ consoleView: UIViewController) -> UITextView {
        let textView = UITextView.init(frame: consoleView.view.bounds)
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = true
        
        do {
            let textFromFile = try String(contentsOf: URL.init(fileURLWithPath: logFilePath!), encoding: .utf8)
            textView.attributedText = colorLoglevels(fileText: textFromFile)
        } catch {
            Logger.error(Constants.errorReadingFile)
        }
        
        self.perform(#selector(self.scrollToBottom(_:)), with: textView, afterDelay: 0.25)
        
        return textView
    }
    
    private func configNavigationForConsoleWith(root:UIViewController) -> UINavigationController {
        let navController = UINavigationController(rootViewController: root)
        navController.navigationBar.barTintColor = UIColor.lightGray
        
        return navController
    }
    
    // scroll down to the bottom of the text view to display the recent log
    @objc private func scrollToBottom (_ textV: UITextView) {
        if textV.text.characters.count > 0 {
            textV.scrollRangeToVisible(NSMakeRange(textV.text.characters.count - 1 , 0))
        }
    }
    
    // change colors of log level identifiers when displaying on device
    private func colorLoglevels(fileText:String) -> NSAttributedString {
        let attrStr = NSMutableAttributedString(string: fileText)
        
        let concurrentQueue = DispatchQueue(label: "botfather.logpresenter.helper", attributes: .concurrent)
        
        let logLevels = [LogLevel.LogLevelInfo,LogLevel.LogLevelWarn,LogLevel.LogLevelDebug,LogLevel.LogLevelParse,LogLevel.LogLevelError]
        
        for level in logLevels {
            concurrentQueue.sync {
                self.modifyLogLevelColors(level, attributedString: attrStr)
            }
        }
       
        return attrStr
        
    }
    
    private func modifyLogLevelColors (_ level:LogLevel, attributedString:NSMutableAttributedString) {
        let inputLength = attributedString.string.characters.count
        let searchString = level.getLevel()
        let searchLength = searchString.characters.count
        var range = NSRange(location: 0, length: attributedString.length)
        
        while (range.location != NSNotFound) {
            range = (attributedString.string as NSString).range(of: searchString, options: [], range: range)
            if (range.location != NSNotFound) {
                attributedString.addAttribute(NSForegroundColorAttributeName, value: getColorFor(level), range: NSRange(location: range.location, length: searchLength))
                range = NSRange(location: range.location + range.length, length: inputLength - (range.location + range.length))
            }
        }
    }
    
    private func getColorFor(_ level:LogLevel) -> UIColor {
        var color = UIColor.blue
        switch level {
        case .LogLevelInfo:
            color = Constants.infoColor
        case .LogLevelWarn:
            color = Constants.warnColor
        case .LogLevelDebug:
            color = Constants.debugColor
        case .LogLevelParse:
            color = Constants.parseColor
        case .LogLevelError:
            color = Constants.errorColor
        }
        
        return color
    }
}
