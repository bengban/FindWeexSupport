//
//  EnumFile.swift
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/15.
//  Copyright © 2018年 taobao. All rights reserved.
//

enum FindRecordViewType: Int {
    case half = 0
    case fullscreen
}

enum FlashState: Int {
    case close = 0
    case open
    case auto
}

@objc enum RecordState: NSInteger {
    case ready = 0
    case recording
    case pause
    case finish
}

@objc enum PlayState: NSInteger {
    case playing = 0
    case pause
    case finish
    case error
    case readyToPlay
}
