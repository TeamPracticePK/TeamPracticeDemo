//
//  ViewController.m
//  LoadWebImageAsynchronously
//
//  Created by Annabelle on 16/5/28.
//  Copyright © 2016年 annabelle. All rights reserved.
//

#import "ViewController.h"
#import "AFNetworking.h"
#import "YJAppInfoModel.h"
#import "YJAppInfoCell.h"


static NSString *cellId = @"cellId";

@interface ViewController () <UITableViewDataSource>

/*!
 *  应用程序信息列表数组
 */
@property (nonatomic, strong) NSArray <YJAppInfoModel *> *appInfoList;

/*!
 *  表格视图
 */
@property (nonatomic, strong) UITableView *tableView;

/*!
 *  下载列队
 */
@property (nonatomic, strong) NSOperationQueue *downloadQueue;

/*!
 *  图像缓冲池
 */
@property (nonatomic, strong) NSMutableDictionary *imageCachePool;

@end

@implementation ViewController

// 根视图设置为 tableView
- (void)loadView {
    
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    
    _tableView.rowHeight = 100;
    
    // 注册原型cell
//    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:cellId];
    
    // 用xib注册原型cell
    [_tableView registerNib:[UINib nibWithNibName:@"YJAppInfoCell" bundle:nil] forCellReuseIdentifier:cellId];
    
    // 设置数据源
    _tableView.dataSource = self;
    
    self.view = _tableView;
    
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 实例化下载列队
    _downloadQueue = [[NSOperationQueue alloc] init];
    
    // 实例化图像缓冲池
    _imageCachePool = [[NSMutableDictionary alloc] init];
    
    [self loadData];
}

/**
 * 接受到内存警告 - 释放资源
 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
   
    // 1> 释放视图，从 iOS 6.0 开始默认不在释放视图！
    // 2> 释放资源！
    // a) 下载的网络图片 - 目前图像保存在 模型中！不好单独释放！
    [_imageCachePool removeAllObjects];
    // b) 没有完成的下载操作
    [_downloadQueue cancelAllOperations];
    

}

- (void)loadData {
    
    // 1. 获取 http 请求管理器
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    
    // 2. 使用 GET 方法，获取网络数据
    NSString *urlName = @"https://raw.githubusercontent.com/Annabelle1024/LoadWebImageAsynchronously/master/appsInfo.json";
    
    [manager GET:urlName
            parameters:nil
            progress:nil
            success:^(NSURLSessionDataTask * _Nonnull task, NSArray *responseObject) {
        
                // 服务器返回的字典或者数组(AFN 已经做好了－可以直接字典转模型即可！)
                NSLog(@"%@, %@", responseObject, [responseObject class]);
                
                // 遍历数组字典转模型
                NSMutableArray *arrayM = [NSMutableArray array];
                
                for (NSDictionary *dict in responseObject) {
                    
                    YJAppInfoModel *model = [[YJAppInfoModel alloc] init];
                    [model setValuesForKeysWithDictionary:dict];
                    [arrayM addObject:model];
                    
                }
                
                // 使用属性记录
                self.appInfoList = arrayM;
                
                // 刷新表格数据
                // 因为是异步加载的数据，表格的数据源方法已经执行过！
                // 加载完成数据之后，需要刷新表格数据，重新执行数据源方法
                [self.tableView reloadData];
    
            }
            failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
                NSLog(@"请求失败: %@", error);
    
            }];
   
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return _appInfoList.count;
    
}


/**
 问题列表
 1. cell 复用 -> 使用占位图像
 2. 图像重复下载：
 - 图像下载完成，保存在本地
 - 下次再使用的时候，从本地加载
 
 关于`本地`：内存缓存／沙盒缓存
 
 3. 内存缓存的解决办法
 1> 在模型中定义一个属性，有缺陷！内存警告的时候，不好释放在内存中缓存的图像！
 2> 自定义一个`缓存池`
 */

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    YJAppInfoCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId forIndexPath:indexPath];
    
    YJAppInfoModel *model = _appInfoList[indexPath.row];
    
    cell.nameLabel.text = model.name;
    cell.downloadLabel.text = model.download;
    
    // 判断模型中是否有 image 属性, 如果有, 直接返回该image, 如果没有, 启用占位图像
    // 判断缓冲池中是否缓存了 modle.icon 对应的 image
    UIImage *cachedImage = _imageCachePool[model.icon];
    
    if (cachedImage != nil) {
        
        NSLog(@"此时返回的是内存缓存的图片");
        
        cell.iconView.image = cachedImage;
        
        return cell;
        
    }
    
    // 增加占位图像
    UIImage *placeholderImage = [UIImage imageNamed:@"user_default"];
    cell.iconView.image = placeholderImage;
    
    // 异步设置图像
    NSURL *url = [NSURL URLWithString:model.icon];
    
    // 异步加载图像
    // 1> 创建下载操作
    NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
        
        // **** 模拟延时, 让占位图像发挥作用
        [NSThread sleepForTimeInterval:1.0];
        
        // a> 根据 url 加载二进制数据
        NSData *data = [NSData dataWithContentsOfURL:url];
        
        // b> 将二进制数据转换成 image
        UIImage *image = [UIImage imageWithData:data];
        
        // *** 记录图像属性
        // model.image = image;
        // *** 将图片保存到图片缓存池
        [_imageCachePool setObject:cachedImage forKey:model.icon];
        
        // c> 主线程更新 UI
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            
            cell.iconView.image = image;
            
        }];
        
    }];
    
    // 将图像添加到队列
    [_downloadQueue addOperation:op];
    
    
    return cell;
    
}


@end
