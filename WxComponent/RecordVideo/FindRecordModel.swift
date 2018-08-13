//
//  FindRecordModel.swift
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/12.
//  Copyright © 2018年 taobao. All rights reserved.
//

import AVFoundation
import AssetsLibrary
import UIKit
import Foundation

protocol FindRecordModelDelegate {
    //    func updateFlashState(state: FlashState)
    func updateRecordTime(curRecord: CGFloat, maxTime: CGFloat)
    func updateRecordState(state: RecordState)
}

class FindRecordModel: NSObject, AVCaptureFileOutputRecordingDelegate {
    fileprivate var delegate: FindRecordModelDelegate?
    
    fileprivate var superView: UIView!
    
    fileprivate var recordTime: CGFloat = 0
    var recordState: RecordState = .ready {
        didSet {
            if recordState != oldValue {
                self.delegate?.updateRecordState(state: recordState)
            }
        }
    }
    
    fileprivate var videoInput: AVCaptureDeviceInput!
    fileprivate var audioInput: AVCaptureDeviceInput!
    
    fileprivate var fileOutput: AVCaptureMovieFileOutput!
    
    fileprivate var session: AVCaptureSession = {
        let session = AVCaptureSession()
        if session.canSetSessionPreset(AVCaptureSessionPresetHigh) {
            session.sessionPreset = AVCaptureSessionPresetHigh
        }
        return session
    }()
    
    fileprivate var previewlayer: AVCaptureVideoPreviewLayer!
    
    fileprivate lazy var recordCachePath: String = {
        var cachePath = NSSearchPathForDirectoriesInDomains(Foundation.FileManager.SearchPathDirectory.documentationDirectory,Foundation.FileManager.SearchPathDomainMask.userDomainMask,true).first ?? ""
        cachePath += "/recordFolder"
        return cachePath
    }()
    
    fileprivate var recordName = "/recordTmp.mp4"
    fileprivate var recordUrl: URL? = nil
    fileprivate var recordPath: String? = nil
    
    fileprivate var timer: Timer?
    fileprivate let TimerRefresh: CGFloat = 0.05   // 计时器的刷新帧
    fileprivate let TimerMax: CGFloat = 3   // 计时器的刷新帧
    
    override init() {
        super.init()
    }
    
    convenience init(type: FindRecordViewType, delegate: FindRecordModelDelegate?, superView: UIView) {
        self.init()
        self.superView = superView
        self.delegate = delegate
        setUpWithType(type: type)
    }
    
    func setUpWithType(type: FindRecordViewType) {
        ///0. 初始化捕捉会话，数据的采集都在会话中处理
        setUpInit()
        
        ///1. 设置视频的输入
        setUpVideo()
        
        ///2. 设置音频的输入
        setUpAudio()
        
        ///3.添加写入文件的fileoutput
        setUpFileOut()
        
        ///4. 视频的预览层
        setUpPreviewLayer(type: type)
        
        ///5. 开始采集画面
        session.startRunning()
    }
    
    fileprivate func setUpInit() {
        NotificationCenter.default.addObserver(self, selector: #selector(enterBack), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(becomeActive), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        
        clearRecord()
        recordTime = 0
        recordState = .ready
        
        previewlayer = AVCaptureVideoPreviewLayer(session: session)
        previewlayer.videoGravity = AVLayerVideoGravityResizeAspectFill
    }
    
    fileprivate func setUpVideo() {
        // 1.1 获取视频输入设备(摄像头)
        guard let videoCaptureDevice = getCameraDeviceWithPosition(position: AVCaptureDevicePosition.back) else { return }
        // 1.2 创建视频输入源
        try? videoInput = AVCaptureDeviceInput(device: videoCaptureDevice)
        
        // 1.3 将视频输入源添加到会话
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        }
    }
    
    fileprivate func setUpAudio() {
        guard let audioCaptureDevice = AVCaptureDevice.devices(withMediaType: AVMediaTypeAudio).first as?  AVCaptureDevice else { return }
        try? audioInput = AVCaptureDeviceInput(device: audioCaptureDevice)
        if session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }
    }
    
    fileprivate func setUpFileOut() {
        // 3.1初始化设备输出对象，用于获得输出数据
        fileOutput = AVCaptureMovieFileOutput()
        // 3.2设置输出对象的一些属性
        if let captureConnection = fileOutput.connection(withMediaType: AVMediaTypeVideo) {
            //设置防抖
            //视频防抖 是在 iOS 6 和 iPhone 4S 发布时引入的功能。到了 iPhone 6，增加了更强劲和流畅的防抖模式，被称为影院级的视频防抖动。相关的 API 也有所改动 (目前为止并没有在文档中反映出来，不过可以查看头文件）。防抖并不是在捕获设备上配置的，而是在 AVCaptureConnection 上设置。由于不是所有的设备格式都支持全部的防抖模式，所以在实际应用中应事先确认具体的防抖模式是否支持：
            if captureConnection.isVideoStabilizationSupported {
                captureConnection.preferredVideoStabilizationMode = .auto
            }
            //预览图层和视频方向保持一致
            captureConnection.videoOrientation = previewlayer.connection.videoOrientation
        }
        // 3.3将设备输出添加到会话中
        if session.canAddOutput(fileOutput) {
            session.addOutput(fileOutput)
        }
    }
    
    fileprivate func setUpPreviewLayer(type: FindRecordViewType) {
        var rect = CGRect.zero
        switch type {
        case .half:
            rect = CGRect(x: 0, y: 0, width: DeviceInfo.ScreenWidth, height: DeviceInfo.ScreenWidth*4/3)
        case .fullscreen:
            rect = UIScreen.main.bounds
        }
        previewlayer.frame = rect
        superView.layer.insertSublayer(previewlayer, at: 0)
    }
    
    fileprivate func getCameraDeviceWithPosition(position: AVCaptureDevicePosition) -> AVCaptureDevice? {
        let cameras: [AVCaptureDevice] = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as! [AVCaptureDevice]
        for e in cameras {
            if e.position == position {
                return e
            }
        }
        return nil
    }
    
    fileprivate func clearRecord() {
        try? FileManager.default.removeItem(atPath: recordCachePath)
        let fileManager: FileManager = FileManager.default
        if !(fileManager.fileExists(atPath: recordCachePath)){
            try? fileManager.createDirectory(at: URL(fileURLWithPath: recordCachePath), withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    //Mark---notification
    @objc fileprivate func enterBack() {
        recordUrl = nil
        recordPath = nil
        stopRecord()
    }
    
    @objc fileprivate func becomeActive() {
        reset()
    }
    
    // 暴露的方法
    func getRecordStr() -> String? { return recordPath }
    
    func startRecord() {
        writeDataTofile()
    }
    
    func stopRecord() {
        fileOutput.stopRecording()
        session.stopRunning()
        recordState = .pause
        timer?.invalidate()
        timer = nil
    }
    
    func reset() {
        recordState = .ready
        recordTime = 0
        session.startRunning()
    }
    
    
    func turnCameraAction() {
        session.stopRunning()
        
        var position = videoInput.device.position
        
        if position == .back {
            position = .front
        } else {
            position = .back
        }
        
        guard let device = getCameraDeviceWithPosition(position: position) else {
            return
        }
        guard let newInput = try? AVCaptureDeviceInput(device: device) else { return }
        session.beginConfiguration()
        session.removeInput(videoInput)
        session.addInput(newInput)
        session.commitConfiguration()
        videoInput = newInput
        
        session.startRunning()
    }
    
    fileprivate func writeDataTofile() {
        let videoPath = recordCachePath + recordName
        recordPath = videoPath
        recordUrl  = URL(fileURLWithPath: videoPath)
        fileOutput.startRecording(toOutputFileURL: recordUrl, recordingDelegate: self)
    }
    
    @objc fileprivate func refreshTimeLabel() {
        DispatchQueue.main.async {
            [weak self] in
            guard let weakself = self else { return }
            weakself.recordTime += weakself.TimerRefresh
            weakself.delegate?.updateRecordTime(curRecord: weakself.recordTime, maxTime: weakself.TimerMax)
            if weakself.recordTime >= weakself.TimerMax {
                weakself.stopRecord()
            }
        }
        
    }
    
    // 实现AVCaptureFileOutputRecordingDelegate
    func capture(_ output: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        recordState = .recording
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(TimerRefresh), target: self, selector: #selector(refreshTimeLabel), userInfo: nil, repeats: true)
    }
    
    func capture(_ output: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        guard let path = recordUrl?.path else {
            return
        }
        if FileManager.default.fileExists(atPath: path) {
            recordState = .finish
        }
    }
    
    deinit {
        delegate = nil
        timer?.invalidate()
        timer = nil
        NotificationCenter.default.removeObserver(self)
    }
}
