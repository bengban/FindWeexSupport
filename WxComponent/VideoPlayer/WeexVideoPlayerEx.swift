//
//  WeexVideoPlayerEx.swift
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/20.
//  Copyright © 2018年 taobao. All rights reserved.
//

import UIKit

@objc extension WeexVideoPlayer: VideoPlayerDelegate {
    open override func updateAttributes(_ attributes: [AnyHashable : Any] = [:]) {
        if let newUrl = attributes["url"] as? String {
            if newUrl != String(self.url) {
                self.url = newUrl as NSString
                prepare(newUrl)
            }
        }
    }
    
    open override func loadView() -> UIView {
        return UIView()
    }
    
    func prepare(_ url: String) {
        DispatchQueue.main.async {[weak self] in
            guard let weakself = self else { return }
//            if weakself.player != nil {
//                weakself.player.removeFromSuperview()
//                weakself.player = nil
//            }
//            if weakself.player == nil {
//                weakself.player = VideoPlayer(frame: CGRect.zero, delegate: weakself)
                weakself.player = VideoPlayer.share
                
                weakself.view.insertSubview(weakself.player, at: 0)
                
                weakself.player.snp.makeConstraints() {
                    make in
                    make.edges.equalToSuperview()
                }
                let tap = UITapGestureRecognizer(target: weakself, action: #selector(weakself.viewTapped))
                weakself.player.addGestureRecognizer(tap)
//            }
            weakself.player.setDelegate(delegate: weakself)
            weakself.player.prepare(url: url)
        }
    
    }
    
    func play() {
        player.play()
    }
    
    func pause() {
        player.pause()
    }
    
    func rePlay() {
        player.rePlay()
    }
    
    func seekToTime(_ time: Double, callback: @escaping WXModuleKeepAliveCallback) {
        player.seek(time) { status in
            callback(["state": status], false)
        }
    }
    
    func getCurState(_ callback: WXModuleKeepAliveCallback) {
        let stateStr = getPlayState(state: player.getCurState())
        callback(stateStr, false)
    }
    
    func getCurTime(_ callback: WXModuleKeepAliveCallback) {
        callback(player.getCurTime(), false)
    }
    
    func getDuration(_ callback: WXModuleKeepAliveCallback) {
        callback(player.getDuration(), false)
    }
    
    func getBufferDuration(_ callback: WXModuleKeepAliveCallback) {
        callback(player.getBufferDuration(), false)
    }
    
    @objc fileprivate func viewTapped() {
        fireEvent(NotifiName.VideoPlayer.viewTapped, params: nil)
    }
    
    
    // VideoPlayerDelegate实现
    func updateVideoBufferTime(loadTime: Double, totalTime: Double) {
        
    }
    
    func updateVideoPlayTime(curTime: Double, totalTime: Double) {
        
    }
    
    func updateVideoPlayState(playState: PlayState) {
        let stateStr = getPlayState(state: playState)
        fireEvent(NotifiName.VideoPlayer.updateState, params: ["state": stateStr])
    }
    
    func destory() {
        if player != nil {
            player.removeFromSuperview()
            player = nil
//            self.removeFromSuperview()
        }
    }
    
    open override func viewDidUnload() {
        super.viewDidUnload()
        if player != nil {
            player.removeFromSuperview()
            player = nil
        }
    }
    
}
