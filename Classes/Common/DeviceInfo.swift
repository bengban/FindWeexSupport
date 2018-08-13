//
//  DeviceInfo.swift
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/12.
//  Copyright © 2018年 taobao. All rights reserved.
//

struct DeviceInfo {
    static let isPad = (UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad)
    static let isPadPro = (DeviceInfo.ScreenHeight>1300 || DeviceInfo.ScreenWidth>1300) ? true : false
    static let allowRotation = (UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad)
    static let ScreenHeight = UIScreen.main.bounds.height
    static let ScreenWidth = UIScreen.main.bounds.width
    
    static var ScaleSizeW = ScreenWidth / 414
    static var ScaleSizeH = ScreenHeight / 736
    
    static let ScaleSizeWPad = ScreenWidth / 768
    static let ScaleSizeHPad = ScreenHeight / 1024
    
    static let ScreenOriginFrame = getScreenOriginFrame()
    static let AppKeyWindow = UIApplication.shared.keyWindow
    
    static func getCurrentTime() -> UInt64 {
        let date = Date.init(timeIntervalSinceNow: 0)
        let time: CGFloat = CGFloat(date.timeIntervalSince1970)*CGFloat(1000)
        return UInt64(time)
    }
    
    static func isLandscape() -> Bool {
        return !UIApplication.shared.statusBarOrientation.isPortrait
    }
    
    static func getScreenWidth() -> CGFloat {
        return UIScreen.main.bounds.width
    }
    
    static func getScreenHeight() -> CGFloat {
        return UIScreen.main.bounds.height
    }
    
    static func getScreenOriginFrame() -> CGRect {
        return UIScreen.main.bounds
    }
    
    static func addDescView(subView: UIView) {
        UIApplication.shared.keyWindow?.addSubview(subView)
        subView.snp.makeConstraints() {
            make in
            make.top.equalToSuperview()
            make.bottom.equalToSuperview()
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
        }
    }

}

class GlobleManager: NSObject {
    static let midiManager = NewPlayMidi.getPlayer()
}

extension UIColor {
    
    convenience init?(hexString: String) {
        self.init(hexString: hexString, alpha: 1.0)
    }
    
    
    convenience init?(hexString: String, alpha: Float) {
        var hex = hexString
        
        if hex.hasPrefix("#") {
            hex = hex.substring(from: hex.characters.index(hex.startIndex, offsetBy: 1))
        }
        
        if let _ = hex.range(of: "(^[0-9A-Fa-f]{6}$)|(^[0-9A-Fa-f]{3}$)", options: .regularExpression) {
            if hex.lengthOfBytes(using: String.Encoding.utf8) == 3 {
                let redHex = hex.substring(to: hex.characters.index(hex.startIndex, offsetBy: 1))
                let greenHex = hex.substring(with: Range<String.Index>(hex.characters.index(hex.startIndex, offsetBy: 1) ..< hex.characters.index(hex.startIndex, offsetBy: 2)))
                let blueHex = hex.substring(from: hex.characters.index(hex.startIndex, offsetBy: 2))
                hex = redHex + redHex + greenHex + greenHex + blueHex + blueHex
            }
            let redHex = hex.substring(to: hex.characters.index(hex.startIndex, offsetBy: 2))
            let greenHex = hex.substring(with: Range<String.Index>(hex.characters.index(hex.startIndex, offsetBy: 2) ..< hex.characters.index(hex.startIndex, offsetBy: 4)))
            let blueHex = hex.substring(with: Range<String.Index>( hex.characters.index(hex.startIndex, offsetBy: 4) ..< hex.characters.index(hex.startIndex, offsetBy: 6)))
            
            var redInt:   CUnsignedInt = 0
            var greenInt: CUnsignedInt = 0
            var blueInt:  CUnsignedInt = 0
            
            Scanner(string: redHex).scanHexInt32(&redInt)
            Scanner(string: greenHex).scanHexInt32(&greenInt)
            Scanner(string: blueHex).scanHexInt32(&blueInt)
            
            self.init(red: CGFloat(redInt) / 255.0, green: CGFloat(greenInt) / 255.0, blue: CGFloat(blueInt) / 255.0, alpha: CGFloat(alpha))
        }
        else
        {
            self.init()
            return nil
        }
    }
    
    convenience init?(hex: Int) {
        self.init(hex: hex, alpha: 1.0)
    }
    
    
    convenience init?(hex: Int, alpha: Float) {
        let hexString = NSString(format: "%2X", hex)
        self.init(hexString: hexString as String, alpha: alpha)
    }
}

struct WeexFilePath {
    static let basePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/WeexCache"
    struct MediaTmp {
        static let audio = basePath + "/recordAudioTmp" + MediaFormat.audio
        static let image = basePath + "/imageTmp/"
    }
    
    struct MediaFormat {
        static let audio = ".aac"
    }
    
    struct RecordFile {
        static let localAudio = basePath + "/RecordFile/localAudio/"
        static let localVideo = basePath + "/RecordFile/localVideo/"
    }
    
    struct MidiFile {
        static let localMidi = basePath + "/MidiFile/localMidi/"
    }
}

struct NotifiName {
    struct AudioRecorder {
        static let updateState = "updateAudioRecordState"
    }
    struct AudioPlayer {
        static let updateState = "updateAudioPlayState"
    }
    struct VideoPlayer {
        static let updateState = "updateVideoPlayState"
        static let viewTapped = "viewTapped"
    }
}

extension NSObject {
    func getRecordStateStr(state: RecordState) -> String{
        var stateStr = ""
        switch state {
        case .ready:
            stateStr = "ready"
        case .recording:
            stateStr = "recording"
        case .pause:
            stateStr = "pause"
        case .finish:
            stateStr = "finish"
        }
        return stateStr
    }
    
    func getPlayState(state: PlayState) -> String {
        var stateStr = ""
        switch state {
        case .playing:
            stateStr = "playing"
        case .error:
            stateStr = "error"
        case .pause:
            stateStr = "pause"
        case .finish:
            stateStr = "finish"
        case .readyToPlay:
            stateStr = "readyToPlay"
        }
        return stateStr
    }
}
