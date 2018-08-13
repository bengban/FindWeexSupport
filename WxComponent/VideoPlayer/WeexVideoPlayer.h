//
//  WeexVideoPlayer.h
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/20.
//  Copyright © 2018年 taobao. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WeexSDK.h>
@class VideoPlayer;

@interface WeexVideoPlayer : WXComponent
@property (nonatomic, assign) NSString *url;
@property (nonatomic, assign) VideoPlayer* player;
@end
