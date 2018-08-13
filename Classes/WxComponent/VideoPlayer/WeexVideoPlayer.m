//
//  WeexVideoPlayer.m
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/20.
//  Copyright © 2018年 taobao. All rights reserved.
//

#import "WeexVideoPlayer.h"
#import "WeexDemo-Swift.h"

@implementation WeexVideoPlayer
WX_EXPORT_METHOD(@selector(prepare:))
WX_EXPORT_METHOD(@selector(play))
WX_EXPORT_METHOD(@selector(pause))
WX_EXPORT_METHOD(@selector(rePlay))
WX_EXPORT_METHOD(@selector(seekToTime:callback:))
WX_EXPORT_METHOD(@selector(getCurState:))
WX_EXPORT_METHOD(@selector(getCurTime:))
WX_EXPORT_METHOD(@selector(getDuration:))
WX_EXPORT_METHOD(@selector(getBufferDuration:))
WX_EXPORT_METHOD(@selector(destory))


- (instancetype)initWithRef:(NSString *)ref type:(NSString *)type styles:(NSDictionary *)styles attributes:(NSDictionary *)attributes events:(NSArray *)events weexInstance:(WXSDKInstance *)weexInstance
{
    self = [super initWithRef:ref type:type styles:styles attributes:attributes events:events weexInstance:weexInstance];
    if (self) {
        if (attributes[@"url"]) {
            _url = attributes[@"url"];
            [self prepare:_url];
        }
    }
    return self;
}

- (void)initUI
{
    
}

@end
