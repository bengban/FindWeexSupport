//
//  BasePlayerView.swift
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/20.
//  Copyright © 2018年 taobao. All rights reserved.
//

import UIKit
import AVFoundation
public enum BasePlayerState {
    case notSetURL
    case readyToPlay
    case pause
    case buffering
    case bufferFinished
    case playedToTheEnd
    case error
}

public enum BasePlayerAspectRatio : Int {
    case `default`    = 0
    case sixteen2NINE
    case four2THREE
}

protocol BasePlayerViewDelegate : class {
    func basePlayer(player: BasePlayerView ,playerStateDidChange state: BasePlayerState)
    func basePlayer(player: BasePlayerView ,loadedTimeDidChange  loadedDuration: TimeInterval , totalDuration: TimeInterval)
    func basePlayer(player: BasePlayerView ,playTimeDidChange    currentTime   : TimeInterval , totalTime: TimeInterval)
    func basePlayer(player: BasePlayerView ,playerIsPlaying      playing: Bool)
}

open class BasePlayerView: UIView {
    
    var delegate: BasePlayerViewDelegate?
    
    /// 视频跳转秒数置0
    open var seekTime = 0
    
    /// 播放属性
    open var playerItem: AVPlayerItem? {
        didSet {
            onPlayerItemChange()
        }
    }
    
    /// 播放属性
    open lazy var player: AVPlayer? = {
        if let item = self.playerItem {
            let player = AVPlayer(playerItem: item)
            return player
        }
        return nil
    }()
    
    
    open var videoGravity = AVLayerVideoGravityResizeAspect {
        didSet {
            self.playerLayer?.videoGravity = videoGravity
        }
    }
    
    open var isPlaying: Bool = false {
        didSet {
            if oldValue != isPlaying {
                delegate?.basePlayer(player: self, playerIsPlaying: isPlaying)
            }
        }
    }
    
    var aspectRatio:BasePlayerAspectRatio = .default {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    /// 计时器
    var timer       : Timer?
    
    fileprivate var urlAsset: AVURLAsset?
    
    fileprivate var lastPlayerItem: AVPlayerItem?
    /// playerLayer
    fileprivate var playerLayer: AVPlayerLayer?
    /// 音量滑杆
    fileprivate var volumeViewSlider: UISlider!
    /// 播发器的几种状态
    internal fileprivate(set) var state = BasePlayerState.notSetURL {
        didSet {
            if state != oldValue {
                delegate?.basePlayer(player: self, playerStateDidChange: state)
            }
        }
    }
    /// 是否为全屏
    fileprivate var isFullScreen  = false
    /// 是否锁定屏幕方向
    fileprivate var isLocked      = false
    /// 是否在调节音量
    fileprivate var isVolume      = false
    /// 是否播放本地文件
    fileprivate var isLocalVideo  = false
    /// slider上次的值
    fileprivate var sliderLastValue:Float = 0
    /// 是否点了重播
    fileprivate var repeatToPlay  = false
    /// 播放完了
    fileprivate var playDidEnd    = false
    // playbackBufferEmpty会反复进入，因此在bufferingOneSecond延时播放执行完之前再调用bufferingSomeSecond都忽略
    // 仅在bufferingSomeSecond里面使用
    fileprivate var isBuffering     = false
    fileprivate var hasReadyToPlay  = false
    fileprivate var shouldSeekTo: TimeInterval = 0
    
    // MARK: - Actions
    open func prepare(url: URL) {
        let asset = AVURLAsset(url: url)
        playAsset(asset: asset)
    }
    
    open func playAsset(asset: AVURLAsset) {
        urlAsset = asset
        onSetVideoAsset()
        //        play()
    }
    
    
    open func play() {
        if let player = player {
            player.play()
            setupTimer()
            isPlaying = true
        }
    }
    
    
    open func pause() {
        player?.pause()
        isPlaying = false
        state = .pause
        timer?.fireDate = Date.distantFuture
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - layoutSubviews
    override open func layoutSubviews() {
        super.layoutSubviews()
        switch self.aspectRatio {
        case .default:
            self.playerLayer?.videoGravity = "AVLayerVideoGravityResizeAspect"
            self.playerLayer?.frame  = self.bounds
            break
        case .sixteen2NINE:
            self.playerLayer?.videoGravity = "AVLayerVideoGravityResize"
            self.playerLayer?.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.width/(16/9))
            break
        case .four2THREE:
            self.playerLayer?.videoGravity = "AVLayerVideoGravityResize"
            let _w = self.bounds.height * 4 / 3
            self.playerLayer?.frame = CGRect(x: (self.bounds.width - _w )/2, y: 0, width: _w, height: self.bounds.height)
            break
        }
    }
    
    open func resetPlayer() {
        // 初始化状态变量
        self.playDidEnd = false
        self.playerItem = nil
        self.seekTime   = 0
        
        self.timer?.invalidate()
        
        self.pause()
        // 移除原来的layer
        self.playerLayer?.removeFromSuperlayer()
        // 替换PlayerItem为nil
        self.player?.replaceCurrentItem(with: nil)
        player?.removeObserver(self, forKeyPath: "rate")
        
        // 把player置为nil
        self.player = nil
    }
    
    open func prepareToDeinit() {
        self.resetPlayer()
    }
    
    open func onTimeSliderBegan() {
        if self.player?.currentItem?.status == AVPlayerItemStatus.readyToPlay {
            self.timer?.fireDate = Date.distantFuture
        }
    }
    
    open func seek(to secounds: TimeInterval, completion:((_ status: Bool)->Void)?) {
        if secounds.isNaN {
            completion?(false)
            return
        }
        setupTimer()
        if self.player?.currentItem?.status == AVPlayerItemStatus.readyToPlay {
            let draggedTime = CMTimeMake(Int64(secounds), 1)
            self.player!.seek(to: draggedTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: { (finished) in
                completion?(finished)
            })
        } else {
            self.shouldSeekTo = secounds
            completion?(true)
        }
    }
    
    
    // MARK: - 设置视频URL
    fileprivate func onSetVideoAsset() {
        repeatToPlay = false
        playDidEnd   = false
        configPlayer()
    }
    
    fileprivate func onPlayerItemChange() {
        if lastPlayerItem == playerItem {
            return
        }
        
        if let item = lastPlayerItem {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item)
            item.removeObserver(self, forKeyPath: "status")
            item.removeObserver(self, forKeyPath: "loadedTimeRanges")
            item.removeObserver(self, forKeyPath: "playbackBufferEmpty")
            item.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
        }
        
        lastPlayerItem = playerItem
        
        if let item = playerItem {
            NotificationCenter.default.addObserver(self, selector: #selector(moviePlayDidEnd),
                                                   name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                                   object: playerItem)
            
            item.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil)
            item.addObserver(self, forKeyPath: "loadedTimeRanges", options: NSKeyValueObservingOptions.new, context: nil)
            // 缓冲区空了，需要等待数据
            item.addObserver(self, forKeyPath: "playbackBufferEmpty", options: NSKeyValueObservingOptions.new, context: nil)
            // 缓冲区有足够数据可以播放了
            item.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: NSKeyValueObservingOptions.new, context: nil)
        }
    }
    
    fileprivate func configPlayer(){
        player?.removeObserver(self, forKeyPath: "rate")
        playerItem = AVPlayerItem(asset: urlAsset!)
        player     = AVPlayer(playerItem: playerItem!)
        player!.addObserver(self, forKeyPath: "rate", options: NSKeyValueObservingOptions.new, context: nil)
        
        
        
        playerLayer?.removeFromSuperlayer()
        playerLayer = AVPlayerLayer(player: player)
        playerLayer!.videoGravity = videoGravity
        
        layer.addSublayer(playerLayer!)
        
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(playerTimerAction), userInfo: nil, repeats: true)
        timer?.fireDate = Date()
    }
    
    
    // MARK: - 计时器事件
    @objc fileprivate func playerTimerAction() {
        if let playerItem = playerItem {
            if playerItem.duration.timescale != 0 {
                let currentTime = CMTimeGetSeconds(self.player!.currentTime())
                let totalTime   = TimeInterval(playerItem.duration.value) / TimeInterval(playerItem.duration.timescale)
                delegate?.basePlayer(player: self, playTimeDidChange: currentTime, totalTime: totalTime)
            }
            updateStatus(inclodeLoading: true)
        }
    }
    
    fileprivate func updateStatus(inclodeLoading: Bool = false) {
        if let player = player {
            if let playerItem = playerItem {
                if inclodeLoading {
                    if playerItem.isPlaybackLikelyToKeepUp || playerItem.isPlaybackBufferFull {
                        self.state = .bufferFinished
                    } else {
                        self.state = .buffering
                    }
                }
            }
            if player.rate == 0.0 {
                if player.error != nil {
                    self.state = .error
                    return
                }
                if let currentItem = player.currentItem {
                    if player.currentTime() >= currentItem.duration {
                        moviePlayDidEnd()
                        return
                    }
                    if currentItem.isPlaybackLikelyToKeepUp || currentItem.isPlaybackBufferFull {
                        
                    }
                }
            }
        }
    }
    
    // MARK: - Notification Event
    @objc fileprivate func moviePlayDidEnd() {
        if state != .playedToTheEnd {
            if let playerItem = playerItem {
                delegate?.basePlayer(player: self,
                                     playTimeDidChange: CMTimeGetSeconds(playerItem.duration),
                                     totalTime: CMTimeGetSeconds(playerItem.duration))
            }
            
            self.state = .playedToTheEnd
            self.isPlaying = false
            self.playDidEnd = true
            self.timer?.invalidate()
        }
    }
    
    // MARK: - KVO
    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let item = object as? AVPlayerItem, let keyPath = keyPath {
            if item == self.playerItem {
                switch keyPath {
                case "status":
                    if player?.status == AVPlayerStatus.readyToPlay {
                        self.state = .buffering
                        if shouldSeekTo != 0 {
                            print("BMPlayerLayer | Should seek to \(shouldSeekTo)")
                            seek(to: shouldSeekTo, completion: { _ in
                                self.shouldSeekTo = 0
                                self.hasReadyToPlay = true
                                self.state = .readyToPlay
                            })
                        } else {
                            self.hasReadyToPlay = true
                            self.state = .readyToPlay
                        }
                    } else if player?.status == AVPlayerStatus.failed {
                        self.state = .error
                    }
                    
                case "loadedTimeRanges":
                    // 计算缓冲进度
                    if let timeInterVarl    = self.availableDuration() {
                        let duration        = item.duration
                        let totalDuration   = CMTimeGetSeconds(duration)
                        delegate?.basePlayer(player: self, loadedTimeDidChange: timeInterVarl, totalDuration: totalDuration)
                    }
                    
                case "playbackBufferEmpty":
                    // 当缓冲是空的时候
                    if self.playerItem!.isPlaybackBufferEmpty {
                        self.state = .buffering
                        self.bufferingSomeSecond()
                    }
                case "playbackLikelyToKeepUp":
                    if item.isPlaybackBufferEmpty {
                        if state != .bufferFinished && hasReadyToPlay {
                            self.state = .bufferFinished
                            self.playDidEnd = true
                        }
                    }
                default:
                    break
                }
            }
        }
        
//        if keyPath == "rate" {
//            updateStatus()
//        }
    }
    
    /**
     缓冲进度
     
     - returns: 缓冲进度
     */
    func availableDuration() -> TimeInterval? {
        if let loadedTimeRanges = player?.currentItem?.loadedTimeRanges,
            let first = loadedTimeRanges.first {
            let timeRange = first.timeRangeValue
            let startSeconds = CMTimeGetSeconds(timeRange.start)
            let durationSecound = CMTimeGetSeconds(timeRange.duration)
            let result = startSeconds + durationSecound
            return result
        }
        return nil
    }
    
    /**
     缓冲比较差的时候
     */
    fileprivate func bufferingSomeSecond() {
        self.state = .buffering
        // playbackBufferEmpty会反复进入，因此在bufferingOneSecond延时播放执行完之前再调用bufferingSomeSecond都忽略
        
        if isBuffering {
            return
        }
        isBuffering = true
        // 需要先暂停一小会之后再播放，否则网络状况不好的时候时间在走，声音播放不出来
        player?.pause()
        let popTime = DispatchTime.now() + Double(Int64( Double(NSEC_PER_SEC) * 1.0 )) / Double(NSEC_PER_SEC)
        
        DispatchQueue.main.asyncAfter(deadline: popTime) {
            
            // 如果执行了play还是没有播放则说明还没有缓存好，则再次缓存一段时间
            self.isBuffering = false
            if let item = self.playerItem {
                if !item.isPlaybackLikelyToKeepUp {
                    self.bufferingSomeSecond()
                } else {
                    // 如果此时用户已经暂停了，则不再需要开启播放了
                    self.state = BasePlayerState.bufferFinished
                }
            }
        }
    }
}
