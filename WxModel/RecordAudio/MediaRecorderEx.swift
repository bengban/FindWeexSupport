//
//  MediaRecorderEx.swift
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/15.
//  Copyright © 2018年 taobao. All rights reserved.
//

import Foundation
import AVFoundation

struct MediaType {
    static let audio = "audio"
}

@objc extension WeexMediaRecorder: RecordAudioDelegate {
    public func prepare(_ type: String, timeMax: Double) {
        switch type {
        case MediaType.audio:
            if self.recordManager == nil {
                self.recordManager = RecordAudioManager(delegate: self, timeMax: timeMax)
            }
        default:
            return
        }
    }
    
    public func start() {
        recordManager?.start()
    }
    
    public func stop() -> String {
        recordManager?.stop()
        return recordManager?.getSavePath() ?? ""
    }
    
    public func cancle() {
        recordManager?.clearTmpRecord()
    }
    
    public func setFile(_ name: String, type: String) -> String {
        if MediaType.audio == type {
            let filePathFolder = WeexFilePath.RecordFile.localAudio + name
            let filePath = WeexFilePath.RecordFile.localAudio + name + WeexFilePath.MediaFormat.audio
            
            if FileManager.default.fileExists(atPath: filePath) {
                return ""
            }
            if !FileManager.default.fileExists(atPath: filePathFolder) {
                do {
                    try FileManager.default.createDirectory(atPath: filePathFolder, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    return ""
                }
            }
            let tmpPath = WeexFilePath.MediaTmp.audio
            if FileManager.default.fileExists(atPath: tmpPath) {
                do {
                    try FileManager.default.moveItem(atPath: tmpPath, toPath: filePath)
                    return filePath
                } catch let error {
                    print(error)
                    return ""
                }
            }
        }
        return ""
    }
    
    public func getFilePath(_ name: String, type: String) -> String {
        if MediaType.audio == type {
            let path = WeexFilePath.RecordFile.localAudio + name + WeexFilePath.MediaFormat.audio
            if FileManager.default.fileExists(atPath: path) {
                return path
            } else {
                return ""
            }
        }
        return ""
    }
    
    public func updateTime(curTime: Double, maxTime: Double) {

    }
    
    public func updateState(_ state: String) {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotifiName.AudioRecorder.updateState), object: nil, userInfo: ["param": state])
    }
    
    public func getFileList(_ type: String) -> [[String: Any]] {
        var dicAry: [[String: Any]] = []

        if MediaType.audio == type {
            let savePath = WeexFilePath.RecordFile.localAudio
            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(atPath: savePath) else {
                return dicAry
            }
            for subPath in enumerator {
                if let sub = subPath as? String {
                    let fullPath = savePath + sub
                    guard let fileinfo = try? FileManager.default.attributesOfItem(atPath: fullPath),
                        let audioPlayer = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: fullPath)),
                        sub.contains(".aac") else {
                            continue
                    }
                    
                    
                    var dic: [String: Any] = [
                        "name": "default_name",
                        "ceateTime": "0",
                        "durTime": "0",
                        "audioPath": ""
                    ]
                    dic["name"] = sub.replacingOccurrences(of: WeexFilePath.MediaFormat.audio, with: "", options: String.CompareOptions.literal, range: nil)
                    
                    if let ceateTime = fileinfo[FileAttributeKey.creationDate] as? Date {
                        dic["ceateTime"] = UInt64(ceateTime.timeIntervalSince1970*1000)
                    }
                    dic["durTime"] = audioPlayer.duration
                    dic["audioPath"] = fullPath
                    print("\(dic)\n")
                    dicAry.append(dic)
                }
            }
            return dicAry
        }
        return dicAry
    }
    
    /// GCD定时器倒计时⏳
    ///   - timeInterval: 循环间隔时间
    ///   - repeatCount: 重复次数
    ///   - handler: 循环事件, 闭包参数： 1. timer， 2. 剩余执行次数
    public func DispatchTimer(timeInterval: Double, repeatCount:Int, handler:@escaping (DispatchSourceTimer?, Int)->())
    {
        if repeatCount <= 0 {
            return
        }
        let timer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.main)
        var count = repeatCount
        timer.scheduleRepeating(wallDeadline: .now(), interval: timeInterval)
        timer.setEventHandler(handler: {
            count -= 1
            DispatchQueue.main.async {
                handler(timer, count)
            }
            if count == 0 {
                timer.cancel()
            }
        })
        timer.resume()
    }
    
    // RecordAudioDelegate实现
    func updateAudioRecordTime(curTime: Double, maxTime: Double) {

    }
    
    func updateAudioRecordState(state: RecordState) {
        updateState(getRecordStateStr(state: state))
    }
}




