//
//  WeexAudioPlayer.h
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/16.
//  Copyright © 2018年 taobao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WeexSDK/WeexSDK.h>
//#import <StreamingKit/STKAudioPlayer.h>
@class AudioPlayerManager;
@class FindMidiPlayer;

@interface WeexAudioPlayer : NSObject <WXModuleProtocol>
@property (nonatomic, assign) BOOL isMidi;
@property (nonatomic, strong) AudioPlayerManager * __nullable playerManager;
@property (nonatomic, strong) FindMidiPlayer * __nullable midiPlayer;

@end
