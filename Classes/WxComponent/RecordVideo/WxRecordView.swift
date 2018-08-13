//
//  WxRecordView.swift
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/12.
//  Copyright © 2018年 taobao. All rights reserved.
//

import UIKit

class WxRecordView: WXComponent, FindRecordViewDelegate {
    fileprivate lazy var videoView: FindRecordView? = {
        let videoView = FindRecordView(frame: CGRect.zero, viewType: .fullscreen, delegate: self)
        self.view.addSubview(videoView)
        
        videoView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        return videoView
    }()
    
    override init(ref: String, type: String, styles: [AnyHashable : Any]?, attributes: [AnyHashable : Any]? = nil, events: [Any]?, weexInstance: WXSDKInstance) {
        super.init(ref: ref, type: type, styles: styles, attributes: attributes, events: events, weexInstance: weexInstance);
    }
    
    override func updateAttributes(_ attributes: [AnyHashable : Any] = [:]) {
        super.updateAttributes(attributes)
    }
    
    override func loadView() -> UIView {
        return UIView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        videoView?.isHidden = false
    }
    
    override func viewDidUnload() {
        super.viewDidUnload()
        videoView = nil
        videoView?.removeFromSuperview()
    }
    
    // FindRecordViewDelegate实现
    func dismissVC() {
        fireEvent("backBtnClick", params: nil)
    }
    
    func recordFinish(videoStr: String) {
        fireEvent("recordFinish", params: ["videoStr": videoStr])
    }
}

class WxPlayRecordView: WXComponent, RecordPlayerViewDelegate {
    fileprivate var player: RecordPlayerView?
    fileprivate var videoUrl: URL?
    var url: String?

    override init(ref: String, type: String, styles: [AnyHashable : Any]?, attributes: [AnyHashable : Any]? = nil, events: [Any]?, weexInstance: WXSDKInstance) {
        super.init(ref: ref, type: type, styles: styles, attributes: attributes, events: events, weexInstance: weexInstance);
        
        if let url = attributes?["url"] as? String {
            self.url = url
        }
    }
    
    override func updateAttributes(_ attributes: [AnyHashable : Any] = [:]) {
        super.updateAttributes(attributes)
        if let url = attributes["url"] as? String {
            self.url = url
            setPlayer(url: url)
        }
    }
    
    override func loadView() -> UIView {
        return UIView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setPlayer(url: url)
    }
    
    func setPlayer(url: String?) {
        guard let url = url else { return }
        self.videoUrl = URL(fileURLWithPath: url)
//        guard let videoUrl = videoUrl else {
//            return
//        }
        if player == nil {
            player = RecordPlayerView(frame: CGRect.zero, url: url, delegate: self)
            view.addSubview(player!)
            
            player?.snp.makeConstraints { (make) in
                make.edges.equalToSuperview()
            }
        } else {
            player?.player?.prepare(url: url)
        }
    }
    
    func onBtnPressed(actionType: RecordPlayerView.BtnActionType) {
        switch actionType {
        case .cancle:
            fireEvent("backBtnClick", params: nil)
        case .save:
            guard let videoUrl = videoUrl else { return }
            VideoTool.saveVideoToLibrary(url: videoUrl) {(state) in
                print("保存成功！！！\(state)")
                DispatchQueue.main.async {[weak self] in
                    guard let weakself = self else { return }
                    weakself.fireEvent("saveBtnClick", params: nil)
                }
            }
        case .play:
            fireEvent("playStateChanged", params: ["state": "play"])
        case .stop:
            fireEvent("playStateChanged", params: ["state": "stop"])
        }
    }
}
