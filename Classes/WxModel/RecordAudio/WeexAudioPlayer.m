//
//  WeexAudioPlayer.m
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/16.
//  Copyright © 2018年 taobao. All rights reserved.
//

#import "WeexAudioPlayer.h"
#import "WeexDemo-Swift.h"

@implementation WeexAudioPlayer
WX_EXPORT_METHOD(@selector(prepare:callback:))
WX_EXPORT_METHOD(@selector(play))
WX_EXPORT_METHOD(@selector(pause))
WX_EXPORT_METHOD(@selector(stop))
WX_EXPORT_METHOD(@selector(seekToTime:))
WX_EXPORT_METHOD_SYNC(@selector(getCurTime))
WX_EXPORT_METHOD_SYNC(@selector(getDuration))

@end
