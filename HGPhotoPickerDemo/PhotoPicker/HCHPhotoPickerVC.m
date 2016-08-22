//
//  HCHPhotoPickerVC.m
//  matchbox
//
//  Created by Heng Gong on 3/22/16.
//  Copyright © 2016 matchbox. All rights reserved.
//

#import "HCHPhotoPickerVC.h"
#import "HCHAlbumView.h"
#import "HCHImageCropView.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>

#define SCREEN_WIDTH                       ([UIScreen mainScreen].bounds.size.width)
#define SCREEN_HEIGHT                      ([UIScreen mainScreen].bounds.size.height)
#define IOS8_OR_LATER	( [[[UIDevice currentDevice] systemVersion] compare:@"8.0"] != NSOrderedAscending )
#define WEAKSELF        typeof(self) __weak weakSelf = self;
#define STRONGSELF      typeof(weakSelf) __strong strongSelf = weakSelf;


@interface HCHPhotoPickerVC () <UITableViewDataSource, UITableViewDelegate, PHPhotoLibraryChangeObserver>

@property (weak, nonatomic) IBOutlet UIView     *photoLibraryViewerContainer;
@property (weak, nonatomic) IBOutlet UIView     *menuView;
@property (weak, nonatomic) IBOutlet UILabel    *titleLabel;
@property (nonatomic, strong) HCHAlbumView      *albumView;
@property (nonatomic, strong) NSMutableArray    *groupList;
@property (nonatomic, strong) ALAssetsGroup     *currentGroup;
@property (nonatomic, strong) UIImageView       *arrow;

@property (nonatomic, strong) UITableView       *tableView;
@property (weak, nonatomic) IBOutlet UIButton   *titleBtn;

@property (nonatomic, assign) BOOL              firstTime;

@property (nonatomic, assign) BOOL              phAvailable;

@property (nonatomic, strong) NSArray           *assetCollectionSubtypes;

@property (nonatomic, assign) NSUInteger        currentIndex;

@property (nonatomic, retain) NSObject          *guideManager;

@property (weak, nonatomic)  HCHImageCropView   *imageCropViewForGuide;

@property (weak, nonatomic) IBOutlet UIButton   *doneBtn;

@property (nonatomic, assign) BOOL              photoAccessAllowed;

@property (weak, nonatomic) IBOutlet UIView     *noContentView;
@property (weak, nonatomic) IBOutlet UIButton   *accessBtn;

@end

@implementation HCHPhotoPickerVC

- (BOOL)photoAccessIsAllowed {
    
    if (IOS8_OR_LATER) {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
        if (status == PHAuthorizationStatusDenied) {
            // Handle Denied
            return NO;
        } else if (status == PHAuthorizationStatusNotDetermined) {
            
            return YES;
        } else if (status == PHAuthorizationStatusAuthorized) {
            return YES;
        }
        
    } else {
        ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
        if (status == ALAuthorizationStatusAuthorized) {
            return YES;
        } else if (status == ALAuthorizationStatusNotDetermined) {
            return YES;
        }
    }
    
    return NO;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.currentIndex = 0;
    self.view.backgroundColor = [UIColor blackColor];
    self.menuView.backgroundColor = [UIColor blackColor];
    self.groupList = [NSMutableArray arrayWithCapacity:10];
    self.firstTime = YES;
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    
    self.phAvailable = IOS8_OR_LATER;
    self.photoAccessAllowed = [self photoAccessIsAllowed];
    
    if (self.photoAccessAllowed) {
        self.albumView = [[[NSBundle mainBundle] loadNibNamed:@"HCHAlbumView" owner:self options:nil] objectAtIndex:0];
        WEAKSELF
        [self.albumView setCameraCallBackBlock:^{
            STRONGSELF
            if (strongSelf.currentIndex != 0) {
                [strongSelf switchToCameraRoll];
            }
            
        }];
        self.albumView.frame = CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
        self.albumView.viewController = self;
        self.imageCropViewForGuide = self.albumView.imageCropView;
        self.photoLibraryViewerContainer.backgroundColor = UIColor.blackColor;
        
        if (self.phAvailable) {
            [self loadNewGroup];
        } else {
            [self loadGroup];
        }
        [self.photoLibraryViewerContainer addSubview:self.albumView];
        // KV on alumb view height
        [self.albumView.imageCropViewConstraintTop addObserver:self forKeyPath:NSStringFromSelector(@selector(constant)) options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:NULL];
        
    } else {
        // Show empty view
        self.titleLabel.text = nil;
        self.doneBtn.hidden = YES;
        self.noContentView.hidden = NO;
        if (IOS8_OR_LATER == NO) {
            self.accessBtn.hidden = YES;
        }
        
    }
    
}

- (void)dealloc {
    [self.albumView.imageCropViewConstraintTop removeObserver:self forKeyPath:NSStringFromSelector(@selector(constant))];
    if (self.phAvailable) {
        [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
    }
}

- (void)popTableView:(BOOL)up {
    [self adjustArrow];
    [UIView animateWithDuration:0.3 animations:^{
        
        self.tableView.frame = CGRectMake(0, up?self.menuView.bounds.size.height:SCREEN_HEIGHT, SCREEN_WIDTH, SCREEN_HEIGHT-self.menuView.bounds.size.height);
        
    } completion:^(BOOL finished) {
        
    }];
}

- (UITableView *)tableView {
    if (_tableView == nil) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, SCREEN_HEIGHT, SCREEN_WIDTH, SCREEN_HEIGHT-self.menuView.bounds.size.height)];
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.backgroundColor = [UIColor blackColor];
        _tableView.separatorInset = UIEdgeInsetsZero;
        [self.view addSubview:_tableView];
    }
    
    return _tableView;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (self.firstTime && self.phAvailable) {
        self.firstTime = NO;
        [self.albumView setup];
        [self.albumView layoutIfNeeded];
        
    }
    self.albumView.frame  = CGRectMake(0, 0, self.photoLibraryViewerContainer.frame.size.width, self.photoLibraryViewerContainer.frame.size.height);
    
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    
    if (self.phAvailable == NO) {
        self.albumView.frame  = CGRectMake(0, 0, self.photoLibraryViewerContainer.frame.size.width, self.photoLibraryViewerContainer.frame.size.height);
        
        [self.albumView setup];
        [self.albumView layoutIfNeeded];
    }
    
    if (self.photoAccessAllowed) {
        //新引导教学
        //     if (![[Config currentConfig].version isEqualToString:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]])
        //     {
        //        NSMutableArray *targetViewsArray = [[NSMutableArray alloc] init];
        //        [targetViewsArray addObject:self.titleLabel];
        //        [targetViewsArray addObject:self.imageCropViewForGuide];
        //
        //        if ( ([targetViewsArray count] != 0)) {
        //
        //            HCHUserGuideManagerForUpdateApp *guideManager = [[HCHUserGuideManagerForUpdateApp alloc]init];
        //            self.guideManager = guideManager;
        //            [guideManager attachUserGuideViews:targetViewsArray withGuideType:guideTypeSelectingPhotoAlbum];
        //
        //        }else
        //        {
        //            DLog(@"no guideViewIndicators");
        //        }
        //     }
    }
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [self.albumView clear];
}

- (UIImageView *)arrow {
    if (_arrow == nil) {
        _arrow = [[UIImageView alloc] initWithFrame:CGRectMake(0, self.titleLabel.center.y-12, 24, 24)];
        _arrow.image = [UIImage imageNamed:@"arrow_down"];
        _arrow.hidden = YES;
        [self.menuView addSubview:_arrow];
    }
    
    return _arrow;
}

- (void)adjustArrow {
    
    self.arrow.hidden = NO;
    CGRect rect = self.arrow.frame;
    CGRect textRect = [self.titleLabel.text boundingRectWithSize:CGSizeMake(self.menuView.bounds.size.width, MAXFLOAT) options:NSStringDrawingTruncatesLastVisibleLine attributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:18]} context:NULL];
    rect.origin.x = textRect.size.width/2.0+SCREEN_WIDTH/2.0 + 6;
    self.arrow.frame = rect;
}

+ (ALAssetsLibrary *)defaultAssetsLibrary {
    
    static dispatch_once_t onceToken;
    static ALAssetsLibrary *library = nil;
    dispatch_once(&onceToken, ^{
        library = [[ALAssetsLibrary alloc] init];
    });
    
    return library;
}


#pragma mark - Utils

- (void)loadGroup {
    
    ALAssetsLibrary *lib = [[self class] defaultAssetsLibrary];
    
    self.albumView.library = lib;
    [lib enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        
        if (group) {
            ALAssetsFilter *onlyPhotosFilter = [ALAssetsFilter allPhotos];
            [group setAssetsFilter:onlyPhotosFilter];
            if ([[group valueForProperty:ALAssetsGroupPropertyType] integerValue] == ALAssetsGroupSavedPhotos) {
                [self.groupList insertObject:group atIndex:0];
                self.currentGroup = group;
                self.titleLabel.text = [group valueForProperty:ALAssetsGroupPropertyName];
                self.albumView.currentGroup = group;
                self.albumView.library = lib;
                if (self.firstTime == NO) {
                    [self.albumView setup];
                    self.firstTime = YES;
                }
                [self adjustArrow];
            } else {
                [self.groupList addObject:group];
            }
            
            // End of enumeration
        } else {
            [self.tableView reloadData];
            [self.albumView loadAssets];
        }
        
    } failureBlock:^(NSError *error) {
        
    }];
    
}

- (void)loadNewGroup {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (status == PHAuthorizationStatusAuthorized) {
                [self initAssetCollectionSubtypes];
                [self adjustArrow];
                
                [self.tableView reloadData];
                [self.albumView loadAssets];
            } else {
                // Show empty view
                self.albumView.hidden = YES;
                self.titleLabel.text = nil;
                self.doneBtn.hidden = YES;
                self.noContentView.hidden = NO;
                if (IOS8_OR_LATER == NO) {
                    self.accessBtn.hidden = YES;
                }
                
            }
            
        });
    }];
    
    
}


#pragma mark - Init properties

- (void)initAssetCollectionSubtypes {
    
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:10];
    
    // Camera roll
    PHCollection *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil].firstObject;
    if (smartAlbums == nil) {
        self.assetCollectionSubtypes = [NSArray arrayWithArray:arr];
        
        return;
    }
    self.titleLabel.text = smartAlbums.localizedTitle;
    if (smartAlbums) {
        [arr addObject:smartAlbums];
    }
    
    // Load camera roll images
    PHFetchOptions *options = [PHFetchOptions new];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"modificationDate" ascending:NO]];
    
    PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsInAssetCollection:(PHAssetCollection *)smartAlbums options:options];
    
    self.albumView.assetsFetchResults = assetsFetchResult;
    //    [self.albumView setup];
    
    // Panoramas
    PHCollection *panoramas = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumPanoramas options:nil].firstObject;
    if (panoramas) {
        [arr addObject:panoramas];
    }
    
    // RecentlyAdded
    PHCollection *recentlyAdded = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumRecentlyAdded options:nil].firstObject;
    if (recentlyAdded) {
        [arr addObject:recentlyAdded];
    }
    
    // Favorites
    PHCollection *favorites = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumFavorites options:nil].firstObject;
    if (favorites) {
        [arr addObject:favorites];
    }
    
    // Add iOS 9's new albums
    if ([[PHAsset new] respondsToSelector:@selector(sourceType)]) {
        
        // SelfPortraits
        PHCollection *selfPortraits = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumSelfPortraits options:nil].firstObject;
        if (selfPortraits) {
            [arr addObject:selfPortraits];
        }
        
        // Screenshots
        PHCollection *screenshots = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumScreenshots options:nil][0];
        if (screenshots) {
            [arr addObject:screenshots];
        }
        
    }
    
    // Custom Albums
    PHFetchResult *topLevelUserCollections = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
    for (PHFetchResult *fr in topLevelUserCollections) {
        if ([fr isKindOfClass:[PHCollectionList class]]) {
            PHFetchResult *c = [PHCollectionList fetchCollectionsInCollectionList:(PHCollectionList *)fr options:nil];
            if (c.firstObject) {
                [arr addObject:c.firstObject];
            }
        } else {
            //assetcollection
            [arr addObject:fr];
        }
    }
    self.assetCollectionSubtypes = [NSArray arrayWithArray:arr];
}



#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    if (self.phAvailable) {
        return self.assetCollectionSubtypes.count;
    }
    
    return self.groupList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"AlbumCellID";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[NSString stringWithFormat:@"%@%ld", cellID, (long)indexPath.row]];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
        cell.backgroundColor = [UIColor blackColor];
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];
        [cell addSubview:iv];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(70, 0, SCREEN_WIDTH-70-50, 60)];
        lbl.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
        lbl.textColor = [UIColor whiteColor];
        lbl.font = [UIFont boldSystemFontOfSize:16];
        
        UILabel *countLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 150, 44)];
        countLbl.font = [UIFont systemFontOfSize:15];
        countLbl.textColor = [UIColor whiteColor];
        countLbl.textAlignment = NSTextAlignmentRight;
        cell.accessoryView = countLbl;
        
        if (self.phAvailable) {
            PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
            fetchOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
            PHAssetCollection *collection = [self.assetCollectionSubtypes objectAtIndex:indexPath.row];
            PHFetchResult *fetchResult = [PHAsset fetchKeyAssetsInAssetCollection:collection options:fetchOptions];
            PHAsset *asset = [fetchResult firstObject];
            PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
            options.resizeMode = PHImageRequestOptionsResizeModeExact;
            
            CGFloat scale = [UIScreen mainScreen].scale;
            CGFloat dimension = 60.0f;
            CGSize size = CGSizeMake(dimension*scale, dimension*scale);
            
            [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:size contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage *result, NSDictionary *info) {
                iv.image = result;
            }];
            PHFetchResult *result = [PHAsset fetchAssetsInAssetCollection:collection options:fetchOptions];
            
            countLbl.text = [NSString stringWithFormat:@"%ld", result.count];
            lbl.text = collection.localizedTitle;
            
        } else {
            ALAssetsGroup *group = self.groupList[indexPath.row];
            iv.image = [UIImage imageWithCGImage:group.posterImage];
            lbl.text = [group valueForProperty:ALAssetsGroupPropertyName];
        }
        
        [cell addSubview:lbl];
        
        
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 59.5, SCREEN_WIDTH, 0.5)];
        line.backgroundColor = [UIColor lightGrayColor];
        [cell addSubview:line];
    }
    
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.phAvailable) {
        self.currentIndex = indexPath.row;
        PHAssetCollection *collection = [self.assetCollectionSubtypes objectAtIndex:indexPath.row];
        self.titleLabel.text = collection.localizedTitle;
        
        PHFetchOptions *options = [PHFetchOptions new];
        options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
        
        PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsInAssetCollection:(PHAssetCollection *)collection options:options];
        
        self.albumView.assetsFetchResults = assetsFetchResult;
        
    } else {
        ALAssetsGroup *group = self.groupList[indexPath.row];
        
        self.titleLabel.text = [group valueForProperty:ALAssetsGroupPropertyName];
        self.albumView.currentGroup = group;
    }
    
    [self adjustArrow];
    
    self.titleBtn.selected = NO;
    [UIView animateWithDuration:0.3 animations:^{
        
        self.arrow.transform = CGAffineTransformIdentity;
    }];
    
    [self popTableView:NO];
    [self.albumView loadAssets];
}


#pragma mark - Key-Value Observing of image view container;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    
    CGFloat top = [change[NSKeyValueChangeNewKey] floatValue];
    
    CGRect frame = self.menuView.frame;
    frame.origin.y = top-50;
    self.menuView.frame = frame;
}


#pragma mark - PHPhotoLibraryChangeObserver

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    // Call might come on any background queue. Re-dispatch to the main queue to handle it.
    dispatch_async(dispatch_get_main_queue(), ^{
        
        PHFetchResultChangeDetails *changeDetails = [changeInstance changeDetailsForFetchResult:self.albumView.assetsFetchResults];
        if (changeDetails) {
            PHFetchResult *result = [changeDetails fetchResultAfterChanges];
            self.albumView.assetsFetchResults = result;
            [self.albumView currentUpdate:changeDetails];
        }
        
    });
}


#pragma mark - Actions

- (void)switchToCameraRoll {
    self.currentIndex = 0;
    
    PHAssetCollection *collection = [self.assetCollectionSubtypes objectAtIndex:0];
    self.titleLabel.text = collection.localizedTitle;
    [self adjustArrow];
    
    PHFetchOptions *options = [PHFetchOptions new];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    
    PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsInAssetCollection:(PHAssetCollection *)collection options:options];
    
    self.albumView.assetsFetchResults = assetsFetchResult;
    [self.albumView loadAssets];
}

- (IBAction)titleBtnTapped:(UIButton *)sender {
    sender.selected = !sender.selected;
    [UIView animateWithDuration:0.3 animations:^{
        
        self.arrow.transform = sender.selected ? CGAffineTransformMakeRotation(M_PI) : CGAffineTransformIdentity;
    }];
    [self popTableView:sender.selected];
}

- (IBAction)doneBtnDidTap:(id)sender {
    
    NSDictionary *info = [self.albumView getCurrentCoordinate];
    if (info == nil) {
        return;
    }
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    
    if ([self.delegate respondsToSelector:@selector(hchPhotoPicker:didFinishWithImage:cropped:)]) {
        [self dismissViewControllerAnimated:NO completion:^{
            
            [self.delegate hchPhotoPicker:self
                       didFinishWithImage:self.albumView.selectedImage
                                  cropped:info[@"cropped"]];
        }];
    }
}

- (IBAction)cancelBtnDidTap:(id)sender {
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    if ([self.delegate respondsToSelector:@selector(hchPhotoPickerDidCancel:)]) {
        [self.delegate hchPhotoPickerDidCancel:self];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)accessBtnOnTap:(id)sender {
    
    BOOL canOpenSettings = (&UIApplicationOpenSettingsURLString != NULL);
    if (canOpenSettings) {
        NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        [[UIApplication sharedApplication] openURL:url];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self cancelBtnDidTap:nil];
            
        });
    }
}

@end
