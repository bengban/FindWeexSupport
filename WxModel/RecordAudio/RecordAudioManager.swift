//
//  RecordAudioManager.swift
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/15.
//  Copyright © 2018年 taobao. All rights reserved.
//

import Foundation
import AVFoundation
import Alamofire

protocol RecordAudioDelegate: class {
    func updateAudioRecordTime(curTime: Double, maxTime: Double)
    func updateAudioRecordState(state: RecordState)
}

class RecordAudioManager: NSObject {
    fileprivate var delegate: RecordAudioDelegate?
    
    fileprivate var audioRecorder: AVAudioRecorder!
    
    ////定义音频的编码参数，这部分比较重要，决定录制音频文件的格式、音质、容量大小等，建议采用AAC的编码方式
    fileprivate let recordSettings = [AVSampleRateKey : NSNumber(value: Float(44100.0)),//声音采样率
        AVFormatIDKey : NSNumber(value: Int32(kAudioFormatMPEG4AAC)),//编码格式
        AVNumberOfChannelsKey : NSNumber(value: 1),//采集音轨
        AVEncoderAudioQualityKey : NSNumber(value: Int32(AVAudioQuality.medium.rawValue))]//音频质量
    fileprivate let saveFolder = WeexFilePath.basePath
    
    fileprivate let savePath = WeexFilePath.MediaTmp.audio
    
    fileprivate var recordTime: Double = 0
    
    fileprivate var timer: Timer?
    fileprivate let TimerRefresh: Double = 0.05   // 计时器的刷新帧
    fileprivate var TimerMax: Double = 3   // 计时器的刷新帧
    
    fileprivate var recordState: RecordState = .ready {
        didSet {
            if recordState != oldValue {
                self.delegate?.updateAudioRecordState(state: recordState)
            }
        }
    }
    
    override init() {
        super.init()
        setUpAudioRecorde()
    }
    
    convenience init(delegate: RecordAudioDelegate?, timeMax: Double) {
        self.init()
        self.delegate = delegate
        self.TimerMax = timeMax
        setUpAudioRecorde()
    }
    
    func getSavePath() -> String {
        return savePath
    }
    
    fileprivate func setUpAudioRecorde() {
        clearTmpRecord()
        recordTime = 0
        recordState = .ready
        
        let url = URL(fileURLWithPath: savePath)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try audioRecorder = AVAudioRecorder(url: url,
                                                settings: recordSettings)//初始化实例
            audioRecorder.prepareToRecord()//准备录音
        } catch {
        }
    }
    
    func clearTmpRecord() {
        try? FileManager.default.removeItem(atPath: savePath)
        let fileManager: FileManager = FileManager.default
        if !(fileManager.fileExists(atPath: saveFolder)){
            try? fileManager.createDirectory(at: URL(fileURLWithPath: saveFolder), withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    @objc fileprivate func refreshTime() {
        DispatchQueue.main.async {
            [weak self] in
            guard let weakself = self else { return }
            weakself.recordTime += weakself.TimerRefresh
            weakself.delegate?.updateAudioRecordTime(curTime: weakself.recordTime, maxTime: weakself.TimerMax)
            if weakself.recordTime >= weakself.TimerMax {
                weakself.stop()
                weakself.recordState = .finish
            }
        }
    }
    
    // MARK: 暴露的接口
    //开始录音
    func start() {
        if !audioRecorder.isRecording {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                audioRecorder.record()
                recordState = .recording
                recordTime = 0
                
                timer = Timer.scheduledTimer(timeInterval: TimeInterval(TimerRefresh), target: self, selector: #selector(refreshTime), userInfo: nil, repeats: true)
                
                print("开始录音")
            } catch {
            }
        }
    }
    
    //结束录音
    func stop() {
        recordState = .pause
        audioRecorder.stop()
        timer?.invalidate()
        timer = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
            print("停止录音")
        } catch {
        }
    }
}

protocol AudioPlayerDelegate {
    func updateAudioPlayTime(curTime: Double, totalTime: Double)
    func updateAudioPlayState(playState: PlayState)
    func updateAudioBuffering(ratio: Double)
}

class AudioPlayerManager: NSObject {
    static let share = AudioPlayerManager()
    fileprivate var audioPlayer: DOUAudioStreamer?
    fileprivate var url: URL?
    
    fileprivate var timer: Timer?
    
    fileprivate var delegate: AudioPlayerDelegate?
    
    fileprivate var playState: PlayState = .finish {
        didSet {
            if playState != oldValue {
                self.delegate?.updateAudioPlayState(playState: playState)
            }
        }
    }
    
    override init() {
        super.init()
    }
    
    convenience init(delegate: AudioPlayerDelegate?) {
        self.init()
        self.delegate = delegate
    }
    
    func setDelegate(delegate: AudioPlayerDelegate?) {
        self.delegate = delegate
    }
    
    func prepare(urlStr: String) {
        if urlStr.hasPrefix("http") {
            guard let urlT = URL(string: urlStr) else { return }
            url = urlT
        } else {
            let urlT = URL(fileURLWithPath: urlStr)
            url = urlT
        }
        resetAudio()
    }
    
    //播放
    func play() {
        audioPlayer?.play()
    }
    
    
    
    //暂停
    func pause() {
        audioPlayer?.pause()
    }
    
    func stop() {
        audioPlayer?.stop()
    }
    
    func seek(toTime: Double )  {
        audioPlayer?.currentTime = toTime
    }
    
    func getCurTime() -> Double {
        return Double(audioPlayer?.currentTime ?? 0)
    }
    
    func getDuration() -> Double {
        guard let urlT = url else { return 0 }
        var totalTime = audioPlayer?.duration ?? 0
        if totalTime == 0 {
            let av = try? AVAudioPlayer(contentsOf: urlT)
            totalTime = av?.duration ?? 0
        }
        return totalTime
    }
    
    deinit {
        destoryAudio()
        delegate = nil
    }
    
    fileprivate func destoryAudio() {
        if audioPlayer != nil {
            audioPlayer?.stop()
            //            audioPlayer?.pause()
            //            audioPlayer?.removeObserver(self, forKeyPath: "duration")
            audioPlayer?.removeObserver(self, forKeyPath: "status")
            audioPlayer?.removeObserver(self, forKeyPath: "bufferingRatio")
        }
        audioPlayer = nil
    }
    
    fileprivate func resetAudio() {
        destoryAudio()
        let file = FindAudioTrack()
        file.audioFileURL = url
        audioPlayer = nil
        audioPlayer = DOUAudioStreamer(audioFile: file)
        audioPlayer?.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil)
        //        audioPlayer?.addObserver(self, forKeyPath: "duration", options: NSKeyValueObservingOptions.new, context: nil)
        audioPlayer?.addObserver(self, forKeyPath: "bufferingRatio", options: NSKeyValueObservingOptions.new, context: nil)
        _ = try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let keyPath = keyPath {
            switch keyPath {
            case "status":
                perform(#selector(updateStatus), on: Thread.main, with: nil, waitUntilDone: false)
            case "bufferingRatio":
                perform(#selector(updateBufferingStatus), on: Thread.main, with: nil, waitUntilDone: false)
                //                case "duration":
            //                    perform(#selector(timerAction), on: Thread.main, with: nil, waitUntilDone: false)
            default:
                break
            }
        }
    }
    
    @objc fileprivate func updateStatus() {
        guard let status = audioPlayer?.status else {
            return
        }
        print("updateStatus")
        switch status {
        case .playing:
            playState = .playing
            //            startTimer()
        //            print("playing---\(audioPlayer?.currentTime)--\(audioPlayer?.duration)")
        case .paused:
            print("paused")
            playState = .pause
            timer?.invalidate()
        case .finished:
            playState = .finish
            timer?.invalidate()
            resetAudio()
        case .idle:
            break
        case .buffering:
            break
        case .error:
            playState = .error
            print("error")
        }
    }
    
    @objc fileprivate func updateBufferingStatus() {
        delegate?.updateAudioBuffering(ratio: (audioPlayer?.bufferingRatio ?? 0))
//        print("updateBufferingStatus:\(String(describing: audioPlayer?.bufferingRatio))")
    }
    
    @objc fileprivate func timerAction() {
        print("timerAction:\(getCurTime())--\(getDuration())")
    }
    
    fileprivate func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(timerAction), userInfo: nil, repeats: true)
        timer?.fireDate = Date()
    }
}

class FindMidiPlayer: NSObject {
    static let share = FindMidiPlayer()
    fileprivate lazy var player: NewPlayMidi = {
        return GlobleManager.midiManager
    }()
    
    fileprivate var delegate: AudioPlayerDelegate?
    fileprivate var url: URL?
    fileprivate var midiPath: String?
    
    fileprivate var currentSecond: Double = 0
    fileprivate var totalSeconds: Double = 0
    
    fileprivate var playState: PlayState = .finish {
        didSet {
            if playState != oldValue {
                self.delegate?.updateAudioPlayState(playState: playState)
            }
        }
    }
    
    override init() {
        super.init()
    }
    
    convenience init(delegate: AudioPlayerDelegate?) {
        self.init()
        self.delegate = delegate
    }
    
    func setDelegate(delegate: AudioPlayerDelegate?) {
        self.delegate = delegate
    }
    
    func prepare(urlStr: String, block:@escaping (_ status : Bool)->()) {
        if urlStr.hasPrefix("http") {
            guard let urlT = URL(string: urlStr) else { return }
            url = urlT
        } else {
            let urlT = URL(fileURLWithPath: urlStr)
            url = urlT
        }
        downloadMidiData(urlStr: urlStr) {[weak self]
            status in
            guard let weakself = self else { return }
            block(status)
            if status {
                weakself.totalSeconds = 0
                weakself.currentSecond = 0
                if weakself.playState == .playing {
                    weakself.playState = .finish
                }
                weakself.playState = .readyToPlay
            } else {
                weakself.playState = .error
            }
        }
        NewPlayMidi.resetMidiPlayer()
        player.statusBlock = {[weak self]
            str in
            guard let weakself = self else { return }
            guard let str = str else { return }
            if str == "playing" {
                weakself.playState = .playing
            } else if str == "finish" {
                if weakself.playState != .pause && weakself.playState != .readyToPlay {
                    weakself.playState = .finish
                }
            }
        }
        player.curtimeBlock = {[weak self]
            curTime in
            guard let weakself = self else { return }
            weakself.currentSecond = curTime
        }
    }
    
    fileprivate func downloadMidiData(urlStr: String, block:@escaping (_ status : Bool)->()) {
        let fileManager = FileManager.default
        let strArray = urlStr.components(separatedBy: "/")
        let lastArray = strArray.last?.components(separatedBy: "?")
        guard let midiName = lastArray?.first else {
            block(false)
            return
        }
        var filePath = WeexFilePath.MidiFile.localMidi
        if !fileManager.fileExists(atPath: filePath) {
            try?fileManager.createDirectory(atPath: filePath,
                                            withIntermediateDirectories: true, attributes: nil)
        }
        filePath += "/\(midiName)"
        if fileManager.fileExists(atPath: filePath) {
            midiPath = filePath
            block(true)
        } else {
            Alamofire.request(urlStr, method: .get)
                .response {[weak self]
                    ret in
                    guard let weakself = self else { return }
                    if let data = ret.data {
                        let createSuccess = fileManager.createFile(atPath: filePath, contents:data, attributes:nil)
                        if createSuccess {
                            weakself.midiPath = filePath
                            block(true)
                        }
                    } else {
                        block(false)
                    }
            }
        }
    }
    
    func play() {
//        if playState == .pause {
//            player.pause(false)
//        } else
        if playState == .finish || playState == .readyToPlay || playState == .pause {
            rePlay()
        }
    }
    
    func rePlay() {
        guard let midiPath = midiPath else {
            return
        }
        let url = URL(fileURLWithPath: midiPath)
        if let data = try? Data.init(contentsOf: url) {
            totalSeconds = Double(player.playMidi(data, target: self, progressAction: #selector(midiIsPlaying)))
        }
    }
    
    @objc private func midiIsPlaying() {
    }
    
    func pause() {
        playState = .pause
        player.stop()
        NewPlayMidi.closePlayer()
    }
    
    func stop() {
        player.stop()
        NewPlayMidi.closePlayer()
    }
    
    //    func seek(toTime: Double )  {
    //        audioPlayer?.currentTime = toTime
    //    }
    
    func getCurTime() -> Double {
        return currentSecond
    }
    
    func getDuration() -> Double {
        return totalSeconds
    }
    
    deinit {
        delegate = nil
    }
}
