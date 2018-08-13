//
//  BaseVideoPlayer.swift
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/12.
//  Copyright © 2018年 taobao. All rights reserved.
//

import UIKit
import MediaPlayer
import Photos

class TimeTool {
    static func formatSecondsToString(_ secounds: TimeInterval) -> String {
        if secounds.isNaN {
            return "00:00"
        }
        let Min = Int(secounds / 60)
        let Sec = Int(secounds.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", Min, Sec)
    }
}

class VideoTool {
    static func coverImageAtTime(time: TimeInterval, url: URL) -> UIImage? {
        let asset = AVURLAsset.init(url: url, options: nil)
        let assetImageGenerator = AVAssetImageGenerator(asset: asset)
        assetImageGenerator.appliesPreferredTrackTransform = true
        assetImageGenerator.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels
        
        guard let thumbnailImageRef = try? assetImageGenerator.copyCGImage(at: CMTimeMake(Int64(CFTimeInterval(time)), 60), actualTime: nil) else { return nil }
        let thumbnailImage = UIImage(cgImage: thumbnailImageRef)
        return thumbnailImage
    }
    
    static func saveVideoToLibrary(url: URL, resultBlock: @escaping (_ state: Bool) ->()) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { (state, _) in
            resultBlock(state)
        }
    }
}

protocol RecordPlayerViewDelegate {
    func onBtnPressed(actionType: RecordPlayerView.BtnActionType)
}
class RecordPlayerView: UIView, VideoPlayerDelegate {
    enum BtnActionType: Int {
        case cancle = 0
        case save
        case play
        case stop
    }
    
    fileprivate let BtnWidth: CGFloat = 50
    open var player: VideoPlayer?
    fileprivate var url: URL!
    
    fileprivate var delegate: RecordPlayerViewDelegate?
    
    fileprivate lazy var startBtn: UIButton = {
        let btn = UIButton(frame: CGRect.zero)
        btn.addTarget(self, action: #selector(startBtnClick(btn:)), for: .touchUpInside)
        btn.setBackgroundImage(UIImage(named: "btn-play"), for: .normal)
        btn.setBackgroundImage(UIImage(named: "btn-stop"), for: .selected)
        self.addSubview(btn)
        
        btn.snp.makeConstraints() { make in
            make.bottom.equalToSuperview().offset(-self.BtnWidth)
            make.centerX.equalToSuperview()
            make.size.equalTo(CGSize(width: self.BtnWidth, height: self.BtnWidth))
        }
        return btn
    }()
    
    fileprivate lazy var timeLabel: UILabel = {
        let label = UILabel(frame: CGRect.zero)
        label.backgroundColor = UIColor.clear
        label.textColor = UIColor.white
        label.font = UIFont.systemFont(ofSize: 18)
        label.text = "00:00/00:00"
        self.addSubview(label)
        return label
    }()
    
    fileprivate lazy var cancleBtn: UIButton = {
        let btn = UIButton(frame: CGRect.zero)
        btn.setBackgroundImage(UIImage(named: "btn-delete"), for: .normal)
        btn.addTarget(self, action: #selector(cancleBtnClick), for: .touchUpInside)
        self.addSubview(btn)
        return btn
    }()
    
    fileprivate lazy var saveBtn: UIButton = {
        let btn = UIButton(frame: CGRect.zero)
        btn.setBackgroundImage(UIImage(named: "btn-save"), for: .normal)
        btn.addTarget(self, action: #selector(saveBtnClick), for: .touchUpInside)
        self.addSubview(btn)
        return btn
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(frame: CGRect, url: String, delegate: RecordPlayerViewDelegate?) {
        self.init(frame: frame)
        self.delegate = delegate
        initUI()
        player?.prepare(url: url)
    }
    
    // MARK: - 初始化
    fileprivate func initUI() {
        self.backgroundColor = UIColor.black
        player = VideoPlayer.share
        player?.setDelegate(delegate: self)
        insertSubview(player!, at: 0)
        player?.snp.makeConstraints { (make) in
            make.edges.equalTo(self)
        }
        
        startBtn.isSelected = false
        timeLabel.snp.makeConstraints() { make in
            make.bottom.equalTo(startBtn.snp.top).offset(-28)
            make.centerX.equalTo(startBtn.snp.centerX)
        }
        
        cancleBtn.snp.makeConstraints() { make in
            make.centerY.equalTo(startBtn.snp.centerY)
            make.trailing.equalTo(startBtn.snp.leading).offset(-30)
            make.size.equalTo(startBtn.snp.size)
        }
        
        saveBtn.snp.makeConstraints() { make in
            make.centerY.equalTo(startBtn.snp.centerY)
            make.leading.equalTo(startBtn.snp.trailing).offset(30)
            make.size.equalTo(startBtn.snp.size)
        }
    }
    
    @objc fileprivate func startBtnClick(btn: UIButton) {
        btn.isSelected = !btn.isSelected
        if btn.isSelected {  //开始播放
            play()
        } else {
            pause()
        }
    }
    
    @objc fileprivate func cancleBtnClick() {
        delegate?.onBtnPressed(actionType: .cancle)
        destoryPlayer()
    }
    
    @objc fileprivate func saveBtnClick() {
        delegate?.onBtnPressed(actionType: .save)
        destoryPlayer()
    }
    
    fileprivate func seek(_ to:TimeInterval, completion: ((_ status: Bool)->Void)? = nil) {
        player?.seek(to, completion: completion)
    }
    
    fileprivate func play() {
        player?.play()
    }
    
    fileprivate func pause() {
        player?.pause()
    }
    
    // VideoPlayerDelegate实现
    func updateVideoBufferTime(loadTime: Double, totalTime: Double) {
        DispatchQueue.main.async {
            let totalTimeStr = TimeTool.formatSecondsToString(totalTime)
            
            let str = "00:00/" + totalTimeStr
            self.timeLabel.text = str
        }
    }
    
    func updateVideoPlayTime(curTime: Double, totalTime: Double) {
        DispatchQueue.main.async {
            let curTimeStr = TimeTool.formatSecondsToString(curTime)
            let totalTimeStr = TimeTool.formatSecondsToString(totalTime)
            
            let str = curTimeStr + "/" + totalTimeStr
            self.timeLabel.text = str
        }
    }
    
    func updateVideoPlayState(playState: PlayState) {
        switch playState {
        case .readyToPlay: break
        case .playing:
            DispatchQueue.main.async {[weak self] in
                guard let weakself = self else { return }
                weakself.startBtn.isSelected = true
            }
        case .finish:
            DispatchQueue.main.async {[weak self] in
                guard let weakself = self else { return }
                weakself.startBtn.isSelected = false
            }
            seek(0)
            break
        default: break
        }
    }
    
    fileprivate func destoryPlayer() {
        delegate = nil
        player?.pause()
        player = nil
    }
    
    deinit {
        delegate = nil
        player?.pause()
        player = nil
    }
}
