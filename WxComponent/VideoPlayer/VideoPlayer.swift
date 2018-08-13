//
//  VideoPlayer.swift
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/20.
//  Copyright © 2018年 taobao. All rights reserved.
//

import UIKit

protocol VideoPlayerDelegate: class {
    func updateVideoBufferTime(loadTime: Double, totalTime: Double)
    func updateVideoPlayTime(curTime: Double, totalTime: Double)
    func updateVideoPlayState(playState: PlayState)
}

class VideoPlayer: UIView, BasePlayerViewDelegate {
    static let share = VideoPlayer()
    fileprivate lazy var playerLayer: BasePlayerView? = {
        let playerLayer = BasePlayerView()
        //        playerLayer.videoGravity = videoGravity
        self.insertSubview(playerLayer, at: 0)
        playerLayer.snp.makeConstraints { (make) in
            make.edges.equalTo(self)
        }
        return playerLayer
    }()
    
    fileprivate var url: URL?
    fileprivate var delegate: VideoPlayerDelegate?
    
    fileprivate var state = PlayState.finish {
        didSet{
            if state != oldValue {
                delegate?.updateVideoPlayState(playState: state)
            }
        }
    }
    
    fileprivate var curTime: Double = 0
    fileprivate var durationTime: Double = 0
    
    
    fileprivate lazy var activity: UIActivityIndicatorView = {
        let activity = UIActivityIndicatorView(frame: CGRect.zero)
        activity.color = UIColor.white
        activity.hidesWhenStopped = true
        self.addSubview(activity)
        
        activity.snp.makeConstraints() {
            make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 25, height: 25))
        }
        return activity
    }()
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(frame: CGRect, delegate: VideoPlayerDelegate) {
        self.init(frame: frame)
        self.delegate = delegate
        initUI()
    }
    
    func setDelegate(delegate: VideoPlayerDelegate?) {
        self.delegate = delegate
        initUI()
    }
    
    // MARK: - 初始化
    fileprivate func initUI() {
        self.backgroundColor = UIColor.black
        playerLayer?.delegate = self
        activity.startAnimating()
        self.layoutIfNeeded()
    }
    
    func prepare(url: String) {
        if url.hasPrefix("http") {
            self.url = URL(string: url)
        } else {
            self.url = URL(fileURLWithPath: url)
        }
        if let urlT = self.url {
            playerLayer?.prepare(url: urlT)
        }
    }
    
    func play() {
        playerLayer?.play()
    }
    
    func pause() {
        playerLayer?.pause()
    }
    
    func rePlay() {
        if state == .playing {
            pause()
        }
        seek(0)
        play()
    }
    
    func seek(_ to:TimeInterval, completion: ((_ status: Bool)->Void)? = nil) {
        playerLayer?.seek(to: to, completion: completion)
    }
    
    func getCurState() -> PlayState {
        return state
    }
    
    func getCurTime() -> Double {
        return curTime
    }
    
    func getDuration() -> Double {
        return durationTime
    }
    
    func getBufferDuration() -> Double {
        return playerLayer!.availableDuration() ?? 0
    }
    
    // BasePlayerLayerViewDelegate实现
    public func basePlayer(player: BasePlayerView, playerIsPlaying playing: Bool) {
        if playing {
            self.state = .playing
        }
//        self.state = playing ? .playing : .pause
    }
    
    public func basePlayer(player: BasePlayerView ,loadedTimeDidChange loadedDuration: TimeInterval , totalDuration: TimeInterval) {
        durationTime = totalDuration
        delegate?.updateVideoBufferTime(loadTime: loadedDuration, totalTime: totalDuration)
        activity.stopAnimating()
        print("----------loadedDuration:\(loadedDuration)")
    }
    
    public func basePlayer(player: BasePlayerView, playerStateDidChange state: BasePlayerState) {
        switch state {
        case .playedToTheEnd:
            seek(0)
            self.state = .finish
        case .pause:
            self.state = .pause
        case .error:
            self.state = .error
        case .buffering:
            print("----------buffering")
        case .bufferFinished:
            print("----------bufferFinished")
        case .readyToPlay:
            self.state = .readyToPlay
            print("----------readyToPlay")
        default: break
        }
    }
    
    
    public func basePlayer(player: BasePlayerView, playTimeDidChange currentTime: TimeInterval, totalTime: TimeInterval) {
        curTime = currentTime
        delegate?.updateVideoPlayTime(curTime: currentTime, totalTime: totalTime)
    }
    
    deinit {
        playerLayer?.delegate = nil
        playerLayer = nil
        delegate = nil
    }
}
