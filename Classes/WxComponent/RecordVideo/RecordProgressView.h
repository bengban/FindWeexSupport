//
//  RecordProgressView.h
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/12.
//  Copyright © 2018年 taobao. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RecordProgressView : UIView
- (instancetype)initWithFrame:(CGRect)frame;
-(void)updateProgressWithValue:(CGFloat)progress;
-(void)resetProgress;
@end

