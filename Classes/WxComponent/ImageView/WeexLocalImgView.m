//
//  WeexLocalImgView.m
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/25.
//  Copyright © 2018年 taobao. All rights reserved.
//

#import "WeexLocalImgView.h"
#import "WeexDemo-Swift.h"

@implementation WeexLocalImgView

- (instancetype)initWithRef:(NSString *)ref type:(NSString *)type styles:(NSDictionary *)styles attributes:(NSDictionary *)attributes events:(NSArray *)events weexInstance:(WXSDKInstance *)weexInstance
{
    self = [super initWithRef:ref type:type styles:styles attributes:attributes events:events weexInstance:weexInstance];
    if (self) {
        if (attributes[@"natId"]) {
            _natId = attributes[@"natId"];
            if (![_natId isKindOfClass:[NSNull class]] || ![_natId isEqualToString:@""]) {
                [self setImgWithNatId:_natId];
            }
        }
    }
    return self;
}

@end
