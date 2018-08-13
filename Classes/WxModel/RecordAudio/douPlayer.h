//
//  douPlayer.h
//  WeexDemo
//
//  Created by 徐林琳 on 2018/7/3.
//  Copyright © 2018年 taobao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DOUAudioFile.h"
#import "DOUAudioStreamer.h"

@interface FindAudioTrack : NSObject <DOUAudioFile>
//这里可以
@property (nonatomic, strong) NSString *artist;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSURL *audioFileURL;

@end

@interface douPlayer : NSObject

@property (nonatomic, strong) FindAudioTrack *track;

@property (nonatomic) float currentTime;

- (BOOL)isWorking;
- (BOOL)isPlaying;
- (BOOL)isTruePlaying;
- (void)play;
- (void)pause;
- (void)stop;

- (void)shake;

@property(nonatomic,copy) void(^statusBlock)(DOUAudioStreamer *streamer);
@property(nonatomic,copy) void(^durationBlock)(DOUAudioStreamer *streamer);
@property(nonatomic,copy) void(^bufferingRatioBlock)(DOUAudioStreamer *streamer);

@end
