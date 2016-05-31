
//
//  YJAppInfoModel.h
//  LoadWebImageAsynchronously
//
//  Created by Annabelle on 16/5/28.
//  Copyright © 2016年 annabelle. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface YJAppInfoModel : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *download;
@property (nonatomic, copy) NSString *icon;

/*!
 *  保存网络下载的图像 : 用属性保存,不好释放图像资源, 所以换其他办法
 */
//@property (nonatomic, strong) UIImage *image;

@end
