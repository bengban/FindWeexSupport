//
//  WeexMediaRecorder.m
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/15.
//  Copyright © 2018年 taobao. All rights reserved.
//

#import "WeexMediaRecorder.h"
#import "WeexDemo-Swift.h"

@implementation WeexMediaRecorder
//@synthesize instance = _instance;

WX_EXPORT_METHOD(@selector(prepare:timeMax:))
WX_EXPORT_METHOD(@selector(start))
WX_EXPORT_METHOD_SYNC(@selector(stop))
WX_EXPORT_METHOD(@selector(cancle))
WX_EXPORT_METHOD_SYNC(@selector(setFile:type:))
WX_EXPORT_METHOD_SYNC(@selector(getFilePath:type:))
WX_EXPORT_METHOD(@selector(updateTimeWithCurTime:maxTime:))
WX_EXPORT_METHOD(@selector(updateState:))
WX_EXPORT_METHOD_SYNC(@selector(getFileList:))

- (id)init
{
    self = [super init];
    return self;
}

//-(WXSDKInstance *)instance
//{
//    if (!_instance) {
//        WXSDKInstance * instance = [[WXSDKInstance alloc] init];
//        instance.viewController = self;
//        _instance = instance;
//        CGFloat width = self.view.frame.size.width;
//        _instance.frame = CGRectMake(self.view.frame.size.width - width, 0, width, _weexHeight);
//    }
//    return _instance;
//}
@end
