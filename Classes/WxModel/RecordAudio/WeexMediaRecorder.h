//
//  WeexMediaRecorder.h
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/15.
//  Copyright © 2018年 taobao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WeexSDK/WeexSDK.h>
@class RecordAudioManager;

@interface WeexMediaRecorder : NSObject < WXModuleProtocol >
@property (nonatomic, strong) RecordAudioManager * __nullable recordManager;
//@property (nonatomic,weak,readonly) WXSDKInstance * _Nullable instance;

@end
