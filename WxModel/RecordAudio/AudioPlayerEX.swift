//
//  AudioPlayerEX.swift
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/16.
//  Copyright © 2018年 taobao. All rights reserved.
//


@objc extension WeexAudioPlayer: AudioPlayerDelegate {
    public func prepare(_ url: String, callback: @escaping WXModuleKeepAliveCallback) {
        var urlT: URL?
        if url.hasPrefix("http") {
            urlT = URL(string: url)
        } else {
            urlT = URL(fileURLWithPath: url)
        }
        guard let lastStr = urlT?.lastPathComponent else {
            callback(false, false)
            return
        }
        if lastStr.contains(".mid") {
            isMidi = true
        }  else {
            isMidi = false
        }
        DispatchQueue.main.async {[weak self] in
            guard let weakself = self else { return }
            weakself.midiPlayer?.stop()
            weakself.playerManager?.stop()
        }
        if isMidi {
            if midiPlayer == nil {
                midiPlayer = FindMidiPlayer.share
            }
            midiPlayer?.setDelegate(delegate: self)
            midiPlayer?.prepare(urlStr: url) {
                status in
                callback(status, false)
            }
        } else {
            if playerManager == nil {
                playerManager = AudioPlayerManager.share
            }
            playerManager?.setDelegate(delegate: self)
            playerManager?.prepare(urlStr: url)
            callback(nil, false)
        }
    }
    
    public func play() {
        DispatchQueue.main.async {[weak self] in
            guard let weakself = self else { return }
            if weakself.isMidi {
                weakself.midiPlayer?.play()
            } else {
                weakself.playerManager?.play()
            }
        }
    }
    
    public func pause() {
        DispatchQueue.main.async {[weak self] in
            guard let weakself = self else { return }
            if weakself.isMidi {
                weakself.midiPlayer?.pause()
            } else {
                weakself.playerManager?.pause()
            }
        }
    }
    
    public func stop() {
        DispatchQueue.main.async {[weak self] in
            guard let weakself = self else { return }
            if weakself.isMidi {
                weakself.midiPlayer?.stop()
            } else {
                weakself.playerManager?.stop()
            }
        }
    }
    
    public func seekToTime(_ time: Double) {
        playerManager?.seek(toTime: time)
    }
    
    public func getCurTime() -> Double {
        return isMidi ? midiPlayer?.getCurTime() ?? 0 : playerManager?.getCurTime() ?? 0
    }
    public func getDuration() -> Double {
        return isMidi ? midiPlayer?.getDuration() ?? 0 : playerManager?.getDuration() ?? 0
    }
    
    func updateAudioPlayTime(curTime: Double, totalTime: Double) {
    }
    
    func updateAudioPlayState(playState: PlayState) {
        let stateStr = getPlayState(state: playState)
        print("状态改变---\(stateStr)")
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotifiName.AudioPlayer.updateState), object: nil, userInfo: ["param": stateStr])
    }
    
    func updateAudioBuffering(ratio: Double) {
    }
}

