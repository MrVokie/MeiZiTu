//
//  ViewController.m
//  MeiZiTu
//
//  Created by Vokie on 5/31/16.
//  Copyright © 2016 Vokie. All rights reserved.
//

#import "ViewController.h"
#import "RegManager.h"
#import "HTTPSessionManager.h"
#import "EncodeManager.h"
#import "CHTCollectionViewWaterfallLayout.h"
#import "CHTCollectionViewWaterfallCell.h"
#import "CHTCollectionViewWaterfallHeader.h"
#import "CHTCollectionViewWaterfallFooter.h"
#import <UIImageView+WebCache.h>
#import "MWPhotoBrowser.h"
#import "MBProgressHUD+EasyUse.h"
#import "SubscribeView.h"
#import "DatabaseManager.h"
#import "SettingViewController.h"
#import "ALAssetsLibrary+CustomPhotoAlbum.h"
#import "SplashView.h"
#import "BloomFilter.h"
#import "CustomTitleView.h"

#define CELL_IDENTIFIER @"WaterfallCell"
#define HEADER_IDENTIFIER @"WaterfallHeader"
#define FOOTER_IDENTIFIER @"WaterfallFooter"

@interface ViewController()<UICollectionViewDataSource, CHTCollectionViewDelegateWaterfallLayout, MWPhotoBrowserDelegate>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray *cellSizes;

@property (nonatomic, strong) NSMutableArray *imageUrlArray;  //当前页面的图片链接
@property (nonatomic, strong) NSMutableArray *urlArray;   //当前页面的url地址
@property (nonatomic, strong) NSMutableArray *mwPhotoArray;

@property (nonatomic, retain) SubscribeView *subView;

@property (nonatomic, retain) NSString *homeWebsite;

@property (nonatomic, strong) ALAssetsLibrary *assetsLibrary;

@property (nonatomic, assign) NSInteger webUrlIndex;

@property (nonatomic, retain) SplashView *splashView;

@property (nonatomic, assign) BOOL isShowStatusBar;

@property (nonatomic, retain) CWStatusBarNotification *notification;

@property (nonatomic, retain) BloomFilter *bloomFilter;

@property (nonatomic, retain) CustomTitleView *customTitleView;
@end

@implementation ViewController

#pragma mark - 懒加载
- (UICollectionView *)collectionView {
    if (!_collectionView) {
        CHTCollectionViewWaterfallLayout *layout = [[CHTCollectionViewWaterfallLayout alloc] init];
        
        layout.sectionInset = UIEdgeInsetsMake(2, 0, 0, 0);
        layout.headerHeight = APP_SCREEN_WIDTH * 2.0 / 5.0f;//宽高比 => 5：2
        layout.footerHeight = 0;
        layout.minimumColumnSpacing = 2;
        layout.minimumInteritemSpacing = 2;
        
        _collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
        _collectionView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        _collectionView.backgroundColor = [UIColor whiteColor];
        [_collectionView registerClass:[CHTCollectionViewWaterfallCell class]
            forCellWithReuseIdentifier:CELL_IDENTIFIER];
        [_collectionView registerClass:[CHTCollectionViewWaterfallHeader class]
            forSupplementaryViewOfKind:CHTCollectionElementKindSectionHeader
                   withReuseIdentifier:HEADER_IDENTIFIER];
        [_collectionView registerClass:[CHTCollectionViewWaterfallFooter class]
            forSupplementaryViewOfKind:CHTCollectionElementKindSectionFooter
                   withReuseIdentifier:FOOTER_IDENTIFIER];
    }
    return _collectionView;
}

- (BloomFilter *)bloomFilter {
    if (!_bloomFilter) {
        NSUInteger maxNumbers = 9999;
        CGFloat falsePositiveRate = 0.01;
        uint32_t seed = 1992;
        
        _bloomFilter = [[BloomFilter alloc] initWithExceptedNumberOfItems:maxNumbers falsePositiveRate:falsePositiveRate seed:seed];
    }
    
    return _bloomFilter;
}

- (NSArray *)cellSizes {
    if (!_cellSizes) {
        _cellSizes = @[
                       [NSValue valueWithCGSize:CGSizeMake(400, 600)],
                       [NSValue valueWithCGSize:CGSizeMake(600, 400)],
                       [NSValue valueWithCGSize:CGSizeMake(1024, 768)],
                       [NSValue valueWithCGSize:CGSizeMake(768, 1024)]
                       ];
    }
    return _cellSizes;
}

- (CWStatusBarNotification *)notification {
    if (!_notification) {
        _notification = [[CWStatusBarNotification alloc]init];
        _notification.notificationLabelBackgroundColor = COLOR_THEME;
        _notification.notificationLabelTextColor = [UIColor whiteColor];
        _notification.notificationAnimationInStyle = CWNotificationAnimationStyleTop;
    }
    return _notification;
}

- (NSMutableArray *)imageUrlArray {
    if (!_imageUrlArray) {
        _imageUrlArray = [NSMutableArray array];
    }
    return _imageUrlArray;
}

- (NSMutableArray *)urlArray {
    if (!_urlArray) {
        _urlArray = [NSMutableArray array];
    }
    return _urlArray;
}

- (NSMutableArray *)mwPhotoArray {
    if (!_mwPhotoArray) {
        _mwPhotoArray = [NSMutableArray arrayWithCapacity:50];
    }
    return _mwPhotoArray;
}

- (SubscribeView *)subView {
    if (!_subView) {
        _subView = [[[NSBundle mainBundle]loadNibNamed:@"SubscribeView" owner:self options:nil] firstObject];
        _subView.frame = CGRectMake(-APP_SCREEN_WIDTH, 0, APP_SCREEN_WIDTH, APP_SCREEN_HEIGHT);
        //        _subView.backgroundColor = [UIColor whiteColor];
        
        //订阅网址点击，回调的block
        __weak typeof(self) weakSelf = self;
        _subView.chooseBlock = ^(NSString *name, NSString *address) {
            weakSelf.customTitleView.mainTitle.text = name;
            weakSelf.homeWebsite = address;
            [[DatabaseManager sharedManager] updateFocusWebsite:address name:name];
            [weakSelf.collectionView.mj_header beginRefreshing];
        };
        [[[UIApplication sharedApplication]keyWindow]addSubview:_subView];
    }
    return _subView;
}

- (ALAssetsLibrary *)assetsLibrary {
    if (_assetsLibrary) {
        return _assetsLibrary;
    }
    _assetsLibrary = [[ALAssetsLibrary alloc] init];
    return _assetsLibrary;
}

#pragma mark - 生命周期

- (void)initNavigationBar {
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"" style:UIBarButtonItemStylePlain target:self action:nil];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"订阅" style:UIBarButtonItemStylePlain target:self action:@selector(subscribe)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"设置" style:UIBarButtonItemStylePlain target:self action:@selector(openSettings)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //显示广告加载页面
    [self showSplashView];
    
    //初始化导航栏
    [self initNavigationBar];
    
    //初始化订阅界面
    self.subView.hidden = NO;
    
    //初始化CollectionView
    [self.view addSubview:self.collectionView];
    
    NSDictionary *dict = [[DatabaseManager sharedManager] getFocusWebsite];
    self.homeWebsite = dict[@"site"];
    
    _customTitleView = [[CustomTitleView alloc]initWithFrame:CGRectMake(0, 0, APP_SCREEN_WIDTH * 0.6, 40)];
    _customTitleView.mainTitle.text = dict[@"name"];
    _customTitleView.subTitle.text = @"欣赏这一刻的感动";
    self.navigationItem.titleView = _customTitleView;
    
    
    __weak typeof(self) weakSelf = self;
    
    //Header下拉刷新
    self.collectionView.mj_header = [MJRefreshNormalHeader headerWithRefreshingBlock:^{
        
        
        _webUrlIndex = 0;
        _imageUrlArray = nil;
        _urlArray = nil;
        _mwPhotoArray = nil;
        _bloomFilter = nil;
        
        //切换网址或者重新头部刷新时、停下footer刷新
        [self.collectionView.mj_footer endRefreshing];
        [self.notification displayNotificationWithMessage:self.homeWebsite forDuration:2.0f];
        // 进入刷新状态后会自动调用这个block
        [[HTTPSessionManager sharedManager]requestWithMethod:GET path:self.homeWebsite params:nil successBlock:^(id responseObject) {
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    // 耗时的操作
                    NSString *result = [EncodeManager encodeWithData:responseObject];
                    if (result == nil || result.length == 0) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            // 更新界面
                            [self.collectionView.mj_header endRefreshing];
                            [self.notification displayNotificationWithMessage:@"站点无数据.." forDuration:2.0f];
                        });
                        return;
                    }
                    
                    //对网址文本进行正则筛选图片链接，网址，并去重
                    weakSelf.imageUrlArray = [self excludeDuplicated:[RegManager regProcessWithContent:result originURL:self.homeWebsite]];
                    weakSelf.urlArray = [self excludeDuplicated:[RegManager crawWebWithContent:result originURL:self.homeWebsite]];
                    
                    for (NSString *imgUrl in self.imageUrlArray) {
                        [self.mwPhotoArray addObject:[MWPhoto photoWithURL:[NSURL URLWithString:imgUrl]]];
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // 更新界面
                        [self.collectionView reloadData];
                        [self.collectionView.mj_header endRefreshing];
                        self.webUrlIndex++;
                        //继续请求下一网页
                        [self.collectionView.mj_footer beginRefreshing];
                    });
                });
                
            } failureBlock:^(NSError *error) {
                [self.notification displayNotificationWithMessage:@"网址没响应.." forDuration:2.0f];
                [self.collectionView.mj_header endRefreshing];
                
            }];
            
        
    }];
    
    //Footer上拉加载更多
    self.collectionView.mj_footer = [MJRefreshAutoNormalFooter footerWithRefreshingBlock:^{
        
            if (self.webUrlIndex >= self.urlArray.count) {
                [self.notification displayNotificationWithMessage:@"已经全部加载" forDuration:2.0f];
                [self.collectionView.mj_footer endRefreshing];
                return;
            }
        
            NSString *urlPath = self.urlArray[self.webUrlIndex];
        
            self.customTitleView.subTitle.text = [NSString stringWithFormat:@"收录：%ld，当前：%ld", self.urlArray.count, self.webUrlIndex + 1];
        
            [self.notification displayNotificationWithMessage:urlPath forDuration:2.0f];
            // 进入刷新状态后会自动调用这个block
            [[HTTPSessionManager sharedManager]requestWithMethod:GET path:urlPath params:nil successBlock:^(id responseObject) {
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    // 耗时的操作
                    NSString *result1 = [EncodeManager encodeWithData:responseObject];
                    
                    
                    NSMutableArray *currentPageImageUrls = nil;
                    
                    if (result1 == nil || result1.length == 0) {
                        currentPageImageUrls = nil;
                    }else{
                        currentPageImageUrls = [self excludeDuplicated:[RegManager regProcessWithContent:result1 originURL:urlPath]];
                    }
                    
                    if (currentPageImageUrls == nil || currentPageImageUrls.count == 0) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            // 更新界面
                            [self.collectionView.mj_footer endRefreshing];
                            
                            self.webUrlIndex++;
                            if ([AppDefault sharedManager].autoLoadMore) {
                                [self.notification displayNotificationWithMessage:@"站点无数据，已为您跳过.." forDuration:2.0f];
                                [self.collectionView.mj_footer beginRefreshing];
                            }else{
                                [self.notification displayNotificationWithMessage:@"站点无数据.." forDuration:2.0f];
                            }
                        });
                        
                        return;
                    }
                    
                    [weakSelf.imageUrlArray addObjectsFromArray:currentPageImageUrls];
                    
                    [weakSelf.urlArray addObjectsFromArray:[self excludeDuplicated:[RegManager crawWebWithContent:result1 originURL:urlPath]]];
                    
                    for (NSString *urlString in currentPageImageUrls) {
                        NSURL *url = [NSURL URLWithString:urlString];
                        [self.mwPhotoArray addObject:[MWPhoto photoWithURL:url]];
                    }
                    self.webUrlIndex++;
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // 更新界面
                        [self.collectionView reloadData];
                        [self.collectionView.mj_footer endRefreshing];
                    });
                });
            } failureBlock:^(NSError *error) {
                [self.collectionView.mj_footer endRefreshing];
                [self.notification displayNotificationWithMessage:@"站点无数据，已为您跳过.." forDuration:2.0f];
                self.webUrlIndex++;
                [self.collectionView.mj_footer beginRefreshing];
                
            }];
        
    }];
    
    [self.collectionView.mj_header beginRefreshing];
}


- (BOOL)prefersStatusBarHidden {
    return !_isShowStatusBar;
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self updateLayoutForOrientation:[UIApplication sharedApplication].statusBarOrientation];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self updateLayoutForOrientation:toInterfaceOrientation];
}

- (void)updateLayoutForOrientation:(UIInterfaceOrientation)orientation {
    CHTCollectionViewWaterfallLayout *layout =
    (CHTCollectionViewWaterfallLayout *)self.collectionView.collectionViewLayout;
    layout.columnCount = UIInterfaceOrientationIsPortrait(orientation) ? 2 : 3;
}

- (void)dealloc {
    _collectionView.delegate = nil;
    _collectionView.dataSource = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    self.assetsLibrary = nil;
}

#pragma mark - Custom Method

- (void)showSplashView {
    _splashView = [[[NSBundle mainBundle] loadNibNamed:@"SplashView" owner:self options:nil] firstObject];
    _splashView.frame = CGRectMake(0, 0, APP_SCREEN_WIDTH, APP_SCREEN_HEIGHT);
    _splashView.showTime = 2.5f;  //启动广告展示时间
    
    //提前0.3秒显示状态栏，修复状态栏显示引起的导航栏跳跃
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((_splashView.showTime) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        _isShowStatusBar = YES;
        [self setNeedsStatusBarAppearanceUpdate];
    });
    [_splashView showInView];
}

- (NSMutableArray *)excludeDuplicated:(NSMutableArray *)array {
    
    NSLog(@">>>>数量前:%ld", array.count);
    
    NSMutableArray *filterArray = [NSMutableArray arrayWithCapacity:20];
    for (NSString *url in array) {
        if (![self.bloomFilter containsString:url]) {
            [self.bloomFilter addWithString:url];
            [filterArray addObject:url];
        }
    }
    
    NSLog(@">>>>数量后:%ld", filterArray.count);
    return filterArray;
}

#pragma mark - Selector

- (void)openSettings {
    SettingViewController *svc = [[SettingViewController alloc]init];
    [self.navigationController pushViewController:svc animated:YES];
}

- (void)subscribe {
    [UIView animateWithDuration:0.2f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
        CGRect rect = CGRectMake(0, 0, APP_SCREEN_WIDTH, APP_SCREEN_HEIGHT);
        self.subView.frame = rect;
    } completion:^(BOOL finished) {
        
    }];
    
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.imageUrlArray.count;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    CHTCollectionViewWaterfallCell *cell =
    (CHTCollectionViewWaterfallCell *)[collectionView dequeueReusableCellWithReuseIdentifier:CELL_IDENTIFIER
                                                                                forIndexPath:indexPath];
//    cell.imageView.image = [UIImage imageNamed:self.imageUrlArray[indexPath.item % 4]];
    [cell.imageView sd_setImageWithURL:[NSURL URLWithString:self.imageUrlArray[indexPath.item]] placeholderImage:[UIImage imageNamed:@"default_image"] options:(SDWebImageRetryFailed | SDWebImageProgressiveDownload) completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        
    }];
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    UICollectionReusableView *reusableView = nil;
    
    if ([kind isEqualToString:CHTCollectionElementKindSectionHeader]) {
        reusableView = [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                          withReuseIdentifier:HEADER_IDENTIFIER
                                                                 forIndexPath:indexPath];
    } else if ([kind isEqualToString:CHTCollectionElementKindSectionFooter]) {
        reusableView = [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                          withReuseIdentifier:FOOTER_IDENTIFIER
                                                                 forIndexPath:indexPath];
    }
    
    return reusableView;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate:self];
    
    // Set options
    browser.displayActionButton = YES; // Show action button to allow sharing, copying, etc (defaults to YES)
    browser.displayNavArrows = NO; // Whether to display left and right nav arrows on toolbar (defaults to NO)
    browser.displaySelectionButtons = NO; // Whether selection buttons are shown on each image (defaults to NO)
    browser.zoomPhotosToFill = NO; // Images that almost fill the screen will be initially zoomed to fill (defaults to YES)
    browser.alwaysShowControls = NO; // Allows to control whether the bars and controls are always visible or whether they fade away to show the photo full (defaults to NO)
    browser.enableGrid = YES; // Whether to allow the viewing of all the photo thumbnails on a grid (defaults to YES)
    browser.startOnGrid = NO; // Whether to start on the grid of thumbnails instead of the first photo (defaults to NO)
    browser.autoPlayOnAppear = NO; // Auto-play first video
    
    // Customise selection images to change colours if required
//    browser.customImageSelectedIconName = @"ImageSelected.png";
//    browser.customImageSelectedSmallIconName = @"ImageSelectedSmall.png";
    
    // Present
    [self.navigationController pushViewController:browser animated:YES];
//    [self presentViewController:browser animated:YES completion:nil];
    // Manipulate
    [browser showNextPhotoAnimated:YES];
    [browser showPreviousPhotoAnimated:YES];
    [browser setCurrentPhotoIndex:indexPath.item];
}

#pragma mark - CHTCollectionViewDelegateWaterfallLayout
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [self.cellSizes[indexPath.item % 4] CGSizeValue];
}

#pragma mark - MWPhotoBrowserDelegate

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return self.mwPhotoArray.count;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    if (index < self.mwPhotoArray.count) {
        return [self.mwPhotoArray objectAtIndex:index];
    }
    return nil; 
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser actionButtonPressedForPhotoAtIndex:(NSUInteger)index {
    MWPhoto *photo = self.mwPhotoArray[index];
    [self.assetsLibrary saveImage:photo.underlyingImage toAlbum:@"MZT" completion:^(NSURL *assetURL, NSError *error) {
        [MBProgressHUD showWithText:@"已保存到MZT相册"];
    } failure:^(NSError *error) {
        [MBProgressHUD showWithText:@"保存失败"];
    }];
}

@end
