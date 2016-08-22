     //
//  HCHAlbumView.m
//  matchbox
//
//  Created by Heng Gong on 3/22/16.
//  Copyright © 2016 matchbox. All rights reserved.
//

#import "HGAlbumView.h"
#import "HGImageCropView.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import "HGGridCell.h"

#pragma mark - Apple Convinient Category

@implementation UICollectionView (AppleConvenience)

- (NSArray *)aapl_indexPathsForElementsInRect:(CGRect)rect {
    NSArray *allLayoutAttributes = [self.collectionViewLayout layoutAttributesForElementsInRect:rect];
    if (allLayoutAttributes.count == 0) { return nil; }
    NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:allLayoutAttributes.count];
    for (UICollectionViewLayoutAttributes *layoutAttributes in allLayoutAttributes) {
        NSIndexPath *indexPath = layoutAttributes.indexPath;
        [indexPaths addObject:indexPath];
    }
    return indexPaths;
}

@end

@implementation NSIndexSet (AppleConvenience)

- (NSArray *)aapl_indexPathsFromIndexesWithSection:(NSUInteger)section {
    NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:self.count];
    [self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [indexPaths addObject:[NSIndexPath indexPathForItem:idx inSection:section]];
    }];
    return indexPaths;
}

@end

#define SCREEN_WIDTH                       ([UIScreen mainScreen].bounds.size.width)
#define SCREEN_HEIGHT                      ([UIScreen mainScreen].bounds.size.height)
#define IOS8_OR_LATER	( [[[UIDevice currentDevice] systemVersion] compare:@"8.0"] != NSOrderedAscending )


typedef enum : NSUInteger {
    HCHDragDirectionScroll,
    HCHDragDirectionStop,
    HCHDragDirectionUp,
    HCHDragDirectionDown,
} HCHDragDirection;

const CGFloat imageCropViewOriginalConstraintTop = 50.0f;
const CGFloat imageCropViewMinimalVisibleHeight = 50.0f;

@interface HGAlbumView () <UICollectionViewDelegate, UICollectionViewDataSource, UIGestureRecognizerDelegate, HGGridCellDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, assign) CGFloat   size;

@property (weak, nonatomic) IBOutlet UICollectionView   *collectionView;


@property (weak, nonatomic) IBOutlet NSLayoutConstraint *collectionViewConstraintHeight;
@property (weak, nonatomic) IBOutlet UIView             *imageCropViewContainer;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *collectionViewConstraintBottom;

@property (nonatomic, assign) CGFloat imaginaryCollectionViewOffsetStartPosY;
@property (nonatomic, assign) CGFloat cropBottomY;
@property (nonatomic, assign) CGPoint dragStartPos;

@property (nonatomic, assign) HCHDragDirection      dragDirection;

@property (nonatomic, assign) NSUInteger            updateLimitIndex;

@property (nonatomic, assign) NSUInteger            selectedIndex;
@property (nonatomic, strong) NSMutableArray        *assets;

@property (nonatomic, assign) BOOL                  phAvailable;

@property (nonatomic, strong) PHCachingImageManager *imageManager;
@property (nonatomic, assign) CGRect                previousPreheatRect;

@property (nonatomic, strong) NSMutableArray        *preloadedCells;

@property (nonatomic, assign) BOOL      firstTime;

@property (nonatomic, assign) BOOL      startFromCollectionView;

@property (nonatomic, assign) CGFloat   maxOffsetY;

@property (nonatomic, strong) UIView    *cropShadow;

@property (nonatomic, strong) UIView    *shadow;

@property (nonatomic, assign) BOOL      dragUp;
@property (nonatomic, assign) BOOL      dragDown;
@property (nonatomic, assign) CGFloat   lastY;

@end


@implementation HGAlbumView

- (void)setup {
    self.dragDirection = HCHDragDirectionUp;
    self.imaginaryCollectionViewOffsetStartPosY = 0.0f;
    self.cropBottomY = 0.0f;
    self.dragStartPos = CGPointZero;
    self.imageCropViewContainer.backgroundColor = [UIColor blackColor];
    
    UIPanGestureRecognizer *pg = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
    pg.delegate = self;
    [self addGestureRecognizer:pg];
    
    UITapGestureRecognizer *tg = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cropViewTapped:)];
    [self.imageCropView addGestureRecognizer:tg];
    
    // Constraints
    self.imageCropViewConstraintTop.constant = imageCropViewOriginalConstraintTop;
    
    
    self.imageCropViewContainer.layer.shadowColor   = UIColor.blackColor.CGColor;
    self.imageCropViewContainer.layer.shadowRadius  = 30.0;
    self.imageCropViewContainer.layer.shadowOpacity = 0.9;
    self.imageCropViewContainer.layer.shadowOffset  = CGSizeZero;
    
    [self setupCollectionView];
    self.collectionViewConstraintBottom.constant = 500;
    self.collectionViewConstraintHeight.constant = self.frame.size.height - self.imageCropView.frame.size.height - imageCropViewOriginalConstraintTop +500;
    [self layoutIfNeeded];
    
    // Shadow in crop view
    [self.imageCropViewConstraintTop addObserver:self forKeyPath:@"constant" options:NSKeyValueObservingOptionNew context:NULL];
    self.maxOffsetY = (self.imageCropViewContainer.frame.size.height + imageCropViewOriginalConstraintTop)/0.5;
    [self.imageCropViewContainer addSubview:self.cropShadow];
}

- (UIView *)cropShadow {
    if (_cropShadow == nil) {
        CGRect rect = CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_WIDTH);
        _cropShadow = [[UIView alloc] initWithFrame:rect];
        _cropShadow.userInteractionEnabled = NO;
        _cropShadow.backgroundColor = [UIColor blackColor];
        _cropShadow.alpha = 0;
    }
    
    return _cropShadow;
}

- (void)clear {
    [self resetCachedAssets];
}

- (void)awakeFromNib {
    
    self.firstTime = YES;
    self.phAvailable = IOS8_OR_LATER;
    if (self.phAvailable) {

    }
    self.backgroundColor = [UIColor blackColor];
    self.imageCropViewContainer.backgroundColor = [UIColor blackColor];
    self.imageCropView.backgroundColor = [UIColor blackColor];
}

- (PHCachingImageManager *)imageManager {
    if (_imageManager == nil) {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
        if (status == PHAuthorizationStatusAuthorized) {
            _imageManager = [[PHCachingImageManager alloc] init];
        }
    }
    
    return _imageManager;
}

- (void)dealloc {
    [self.imageCropViewConstraintTop removeObserver:self forKeyPath:@"constant"];
    if (self.phAvailable) {
        //        [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
    }
}

- (void)setupCollectionView {
    [self.collectionView registerClass:[HGGridCell class] forCellWithReuseIdentifier:@"GridCell"];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.updateLimitIndex = 20;
    
    // Select the first image by default
    self.selectedIndex = 1;
    self.startFromCollectionView = NO;
    const CGFloat spacing = 2.0f;
    const NSUInteger column = 4;
    CGFloat size = (SCREEN_WIDTH-((column+1)*spacing))/column;
    self.size = size;
    UICollectionViewFlowLayout *layout  = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize                     = CGSizeMake(size, size);
    layout.sectionInset                 = UIEdgeInsetsMake(0, 2, 0, 2);
    
    layout.minimumInteritemSpacing      = spacing;
    layout.minimumLineSpacing           = spacing;
    self.collectionView.alwaysBounceVertical = YES;
    self.collectionView.collectionViewLayout = layout;
    self.assets = [NSMutableArray arrayWithCapacity:300];
    [self loadAssets];
}


#pragma mark - Gesture

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    
    if ([gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]] || [otherGestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
        return NO;
    }
    return YES;
}


- (void)panned:(UIPanGestureRecognizer *)sender {
    self.collectionView.scrollEnabled = YES;
    self.collectionViewConstraintBottom.constant = 0;
    
    if (sender.state == UIGestureRecognizerStateBegan) {
        
        UIView *view    = sender.view;
        CGPoint loc     = [sender locationInView:view];
        UIView *subview = [view hitTest:loc withEvent:nil];
        self.dragStartPos = [sender locationInView:self];
        
        self.dragUp = NO;
        self.dragDown = NO;
        self.lastY = [sender locationInView:self].y;
        //
        if (subview == self.imageCropView && self.imageCropViewConstraintTop.constant == imageCropViewOriginalConstraintTop) {
            if (loc.y<self.imageCropViewContainer.bounds.size.height-50) {
                self.collectionView.scrollEnabled = NO;
                
                return;
            } else {
                [self.imageCropView changeScrollable:NO];
                self.dragDirection = HCHDragDirectionScroll;
            }
        }
        
        if (CGRectContainsPoint(CGRectOffset(self.collectionView.frame, 0, -imageCropViewOriginalConstraintTop) , self.dragStartPos)) {
            self.startFromCollectionView = YES;
        } else {
            self.startFromCollectionView = NO;
        }
        
        
        self.cropBottomY = self.imageCropViewContainer.frame.origin.y + self.imageCropViewContainer.frame.size.height;
        
        // Move
        if (self.dragDirection == HCHDragDirectionStop) {
            
            self.dragDirection = (self.imageCropViewConstraintTop.constant == imageCropViewOriginalConstraintTop) ? HCHDragDirectionUp : HCHDragDirectionDown;
        }
        
        // Scroll event of CollectionView is preferred.
        if ((self.dragDirection == HCHDragDirectionUp && self.dragStartPos.y < self.cropBottomY) ||
            (self.dragDirection == HCHDragDirectionDown && self.dragStartPos.y > self.cropBottomY)) {
            
            self.dragDirection = HCHDragDirectionStop;
            [self.imageCropView changeScrollable:NO];
            
        } else {
            
            [self.imageCropView changeScrollable:YES];
        }
        
    } else if (sender.state == UIGestureRecognizerStateChanged) {
        
        CGPoint currentPos = [sender locationInView:self];
        
        if (currentPos.y < self.lastY) {
            self.dragUp = YES;
        } else if (currentPos.y > self.lastY) {
            self.dragDown = YES;
        }
        self.lastY = currentPos.y;
        
        if (self.dragDirection == HCHDragDirectionUp && currentPos.y < self.cropBottomY) {
            
            self.imageCropViewConstraintTop.constant = MAX(imageCropViewMinimalVisibleHeight - self.imageCropViewContainer.frame.size.height, currentPos.y - self.imageCropViewContainer.frame.size.height);
            
            self.collectionViewConstraintHeight.constant = MIN(self.frame.size.height - imageCropViewMinimalVisibleHeight, self.frame.size.height - self.imageCropViewConstraintTop.constant - self.imageCropViewContainer.frame.size.height);
            if (self.startFromCollectionView) {
                
                self.collectionView.scrollEnabled = NO;
            }
            
        } else if (self.dragDirection == HCHDragDirectionDown && currentPos.y > self.cropBottomY) {
            
            self.imageCropViewConstraintTop.constant = MIN(imageCropViewOriginalConstraintTop, currentPos.y - self.imageCropViewContainer.frame.size.height);
            
            self.collectionViewConstraintHeight.constant = MAX(self.frame.size.height - imageCropViewOriginalConstraintTop - self.imageCropViewContainer.frame.size.height, self.frame.size.height - self.imageCropViewConstraintTop.constant - self.imageCropViewContainer.frame.size.height);
            
        } else if (self.dragDirection == HCHDragDirectionStop && self.collectionView.contentOffset.y < 0) {
            
            self.dragDirection = HCHDragDirectionScroll;
            self.imaginaryCollectionViewOffsetStartPosY = currentPos.y;
            
        } else if (self.dragDirection == HCHDragDirectionScroll) {
            
            self.imageCropViewConstraintTop.constant = MIN(50, imageCropViewMinimalVisibleHeight - self.imageCropViewContainer.frame.size.height + currentPos.y - self.imaginaryCollectionViewOffsetStartPosY);
            
            self.collectionViewConstraintHeight.constant = MAX(self.frame.size.height - imageCropViewOriginalConstraintTop - self.imageCropViewContainer.frame.size.height, self.frame.size.height - self.imageCropViewConstraintTop.constant - self.imageCropViewContainer.frame.size.height);
            if (self.startFromCollectionView) {
                self.collectionView.scrollEnabled = NO;
                
            }
            
        }
        
    } else {
        
        if (sender.state == UIGestureRecognizerStateEnded && self.imageCropViewConstraintTop.constant == imageCropViewMinimalVisibleHeight - self.imageCropViewContainer.frame.size.height) {
            [self.imageCropView changeScrollable:NO];
            
        }
        
        self.imaginaryCollectionViewOffsetStartPosY = 0.0;
        
        if (sender.state == UIGestureRecognizerStateEnded && self.dragDirection == HCHDragDirectionStop) {
            
            if (self.imageCropViewConstraintTop.constant == imageCropViewMinimalVisibleHeight - self.imageCropViewContainer.frame.size.height) {
                [self.imageCropView changeScrollable:NO];
            } else {
                
                [self.imageCropView changeScrollable:YES];
            }
            return;
        }
        
        CGPoint currentPos = [sender locationInView:self];
        
        if (self.dragDown && self.dragUp) {
            if (currentPos.y < (self.imageCropView.bounds.size.height+imageCropViewOriginalConstraintTop)/2.0) {
                
                [self popUp];
            } else {
                
                [self popDown];
            }
        } else {
            if (self.dragUp) {
                [self popUp];
            } else {
                [self popDown];
            }
        }
    }
}

- (void)popUp {
    // Pop up
    [self.imageCropView changeScrollable:NO];
    
    self.imageCropViewConstraintTop.constant = imageCropViewMinimalVisibleHeight - self.imageCropViewContainer.frame.size.height;
    
    self.collectionViewConstraintHeight.constant = self.frame.size.height - imageCropViewMinimalVisibleHeight;
    
    [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        
        [self layoutIfNeeded];
        
    } completion:^(BOOL finished) {
        
        
    }];
    self.dragDirection = HCHDragDirectionDown;
}

- (void)popDown {
    // Pop down
    [self.imageCropView changeScrollable:YES];
    
    self.imageCropViewConstraintTop.constant = imageCropViewOriginalConstraintTop;
    self.collectionViewConstraintHeight.constant = self.frame.size.height - imageCropViewOriginalConstraintTop - self.imageCropViewContainer.frame.size.height;
    
    [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        
        [self layoutIfNeeded];
        
    } completion:^(BOOL finished) {
        
        
    }];
    
    
    self.dragDirection = HCHDragDirectionStop;
    
}


#pragma mark - Image Picker

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    UIImageWriteToSavedPhotosAlbum(image, nil, NULL, NULL);
    if (self.phAvailable) {
        
        // Change to camera roll
        if (self.cameraCallBackBlock) {
            self.cameraCallBackBlock();
        }
        
    } else {
        [self.assets insertObject:image atIndex:0];
        [self loadCropView];
        [self.collectionView reloadData];
    }
    self.selectedImage = image;
    self.selectedIndex = 1;
    
    [self.viewController dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - HCHGridCell Delegate

- (void)gridCell:(HGGridCell *)cell didSelect:(BOOL)selected atIndex:(NSInteger)index {
    
    if (self.selectedIndex != NSNotFound) {
        HGGridCell *cell = (HGGridCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
        cell.selectedButton.selected = NO;
        [cell setNeedsDisplay];
    }
    
    self.selectedIndex = selected ? index : NSNotFound;
    [self.collectionView reloadData];
}


#pragma mark - Collection View

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    
    if (self.phAvailable) {
        
        return self.assetsFetchResults.count+1;
    }
    
    if (_assets.count == 0) {
        return 0;
    }
    return self.assets.count + 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    HGGridCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"GridCell" forIndexPath:indexPath];
    cell.selectedSquare.hidden = YES;
    if (indexPath.row == 0) {
        cell.imageView.image = nil;
        cell.imageView.image = [UIImage imageNamed:@"icon_camera"];
        cell.imageView.contentMode = UIViewContentModeCenter;
        cell.selectedSquare.hidden = YES;
    } else {
        cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
        cell.selectedSquare.hidden = YES;
        
        if (self.phAvailable) {
            
            PHAsset *asset = self.assetsFetchResults[indexPath.item-1];
            cell.representedAssetIdentifier = asset.localIdentifier;
            // Request an image for the asset from the PHCachingImageManager.
            [self.imageManager requestImageForAsset:asset
                                         targetSize:CGSizeMake(self.size, self.size)
                                        contentMode:PHImageContentModeAspectFill
                                            options:nil
                                      resultHandler:^(UIImage *result, NSDictionary *info) {
                                          // Set the cell's thumbnail image if it's still showing the same asset.
                                          if ([cell.representedAssetIdentifier isEqualToString:asset.localIdentifier]) {
                                              cell.imageView.image = result;
                                              
                                          }
                                      }];
            
        } else {
            ALAsset *asset = self.assets[indexPath.row-1];
            if ([asset isKindOfClass:[UIImage class]]) {
                cell.imageView.image = (UIImage *)asset;
            } else {
                cell.imageView.image = [UIImage imageWithCGImage:asset.aspectRatioThumbnail];
            }
        }
        
        cell.delegate = self;
        cell.index = indexPath.row;
        
        cell.selectedSquare.hidden = indexPath.row != self.selectedIndex;
    }
    
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        [self cameraCellDidTap:nil];
        return;
    }
    
    if (self.selectedIndex != indexPath.row) {
        NSUInteger idx = self.selectedIndex;
        self.selectedIndex = indexPath.row;
        if (self.phAvailable) {
            [self loadCropView];
            
            HGGridCell *cell = (HGGridCell *)[collectionView cellForItemAtIndexPath:indexPath];
            cell.selectedSquare.hidden = NO;
            
            HGGridCell *cell1 = (HGGridCell *)[collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:idx inSection:0]];
            cell1.selectedSquare.hidden = YES;
            
        } else {
            ALAsset *asset = self.assets[indexPath.row-1];
            if ([asset isKindOfClass:[UIImage class]]) {
                self.selectedImage = (UIImage *)asset;
            } else {
                
                self.selectedImage = [UIImage imageWithCGImage:asset.defaultRepresentation.fullScreenImage];
            }
            [self loadCropView];
            [self.collectionView reloadData];
        }
        
    }
    
    // Should drop down
    if (self.imageCropViewConstraintTop.constant < imageCropViewOriginalConstraintTop) {
        [self.imageCropView changeScrollable:YES];
        [self killScroll];
        
        CGPoint contentOffset = self.collectionView.contentOffset;
        UICollectionViewLayoutAttributes *attributes = [self.collectionView layoutAttributesForItemAtIndexPath:indexPath];
        CGRect rect = attributes.frame;
        CGFloat offsetY = rect.origin.y - contentOffset.y;
        if (offsetY < 0) {
            contentOffset.y+=offsetY;
            [self.collectionView setContentOffset:contentOffset];
            
        } else if (offsetY-self.imageCropView.frame.size.height < 0) {
            NSUInteger row = indexPath.item/4;
            contentOffset.y = (CGFloat)row*(self.size+2.0f);
            //            [self.collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionTop animated:NO];
            [self.collectionView setContentOffset:contentOffset];
            
        } else if (offsetY+self.size > self.collectionViewConstraintHeight.constant) {
            NSUInteger row = indexPath.item/4+1;
            contentOffset.y = (CGFloat)row*(self.size+2.0f)-(self.frame.size.height - self.imageCropViewContainer.frame.size.height - imageCropViewOriginalConstraintTop);
            [self.collectionView setContentOffset:contentOffset];
            
        } else {
            contentOffset.y+=(self.imageCropViewContainer.frame.size.height);
            [self.collectionView setContentOffset:contentOffset];
            
        }
        
        
        [UIView animateWithDuration:0.16 delay:0. options:UIViewAnimationOptionShowHideTransitionViews animations:^{
            self.imageCropViewConstraintTop.constant = imageCropViewOriginalConstraintTop;
            
            [self layoutIfNeeded];
            
        } completion:nil];
        
        [UIView animateWithDuration:0.1 delay:0. options:UIViewAnimationOptionCurveLinear animations:^{
            
            self.collectionViewConstraintHeight.constant = self.frame.size.height - self.imageCropViewContainer.frame.size.height - imageCropViewOriginalConstraintTop;
            
        } completion:^(BOOL finished) {
            
            
        }];
        
        self.dragDirection = HCHDragDirectionStop;
        
        // scroll to show the whole grid
    } else {
        UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
        if (cell.frame.origin.y-self.collectionView.contentOffset.y<0) {
            [self.collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionTop animated:YES];
        } else if (cell.frame.origin.y+cell.frame.size.height-self.collectionView.contentOffset.y>self.collectionView.bounds.size.height) {
            [self.collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionBottom animated:YES];
            
        }
        
    }
    
}

- (void)killScroll {
    CGPoint offset = self.collectionView.contentOffset;
    offset.x -= 1.0;
    offset.y -= 1.0;
    [self.collectionView setContentOffset:offset animated:NO];
    offset.x += 1.0;
    offset.y += 1.0;
    [self.collectionView setContentOffset:offset animated:NO];
}

- (void)loadCropView:(ALAsset *)asset {
    UIImage *image = [UIImage imageWithCGImage:asset.defaultRepresentation.fullScreenImage];
    self.selectedImage = image;
    [self loadCropView];
}


#pragma mark - Load Images

- (void)currentUpdate:(PHFetchResultChangeDetails *)changeDetails {
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
        [self.collectionView reloadData];
        [self loadCropViewAsync:NO];
        
        return;
    }
    
    if (changeDetails.hasIncrementalChanges == NO || changeDetails.hasMoves) {
        [self.collectionView reloadData];
        [self resetCachedAssets];
    } else {
        
        [self.collectionView performBatchUpdates:^{
            NSIndexSet *removedIndexes = changeDetails.removedIndexes;
            if (removedIndexes.count) {
                [self.collectionView deleteItemsAtIndexPaths:[removedIndexes aapl_indexPathsFromIndexesWithSection:0]];
            }
            
            NSIndexSet *insertedIndexes = changeDetails.insertedIndexes;
            if (insertedIndexes.count) {
                [self.collectionView insertItemsAtIndexPaths:[insertedIndexes aapl_indexPathsFromIndexesWithSection:0]];
            }
            
            NSIndexSet *changedIndexes = changeDetails.changedIndexes;
            if (changedIndexes.count) {
                [self.collectionView reloadItemsAtIndexPaths:[changedIndexes aapl_indexPathsFromIndexesWithSection:0]];
            }
            
            
        } completion:^(BOOL finished) {

        }];
    }
    [self loadCropViewAsync:NO];
    
}

- (void)loadAssets {
    self.selectedIndex = 1;
    if (self.assets.count) {
        [self.assets removeAllObjects];
    }
    
    if (self.phAvailable == NO) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // Process assets
            void (^assetEnumerator)(ALAsset *, NSUInteger, BOOL *) = ^(ALAsset *asset, NSUInteger index, BOOL *stop) {
                if (asset) {
                    
                    [self.assets addObject:asset];
                    if (self.assets.count == self.currentGroup.numberOfAssets) {
                        [self.collectionView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
                    }
                    if (self.assets.count == 1) {
                        
                        [self performSelectorOnMainThread:@selector(loadCropView:) withObject:asset waitUntilDone:YES];
                    }
                    
                    if (self.assets.count == self.updateLimitIndex) {
                        [self.collectionView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
                    }
                    
                } else {
                    [self.collectionView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
                }
            };
            
            if (self.currentGroup) {
                [self.currentGroup enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:assetEnumerator];
            } else {
                
            }
            
        });
        
    } else {
        [self loadCropView];
        self.imageCropViewConstraintTop.constant = imageCropViewOriginalConstraintTop;
        self.collectionViewConstraintHeight.constant = self.frame.size.height - imageCropViewOriginalConstraintTop - self.imageCropViewContainer.frame.size.height;
        [self setNeedsLayout];
        
        [self.collectionView reloadData];
    }
    
}

- (void)loadCropView {
    [self loadCropViewAsync:YES];
}

- (void)loadCropViewAsync:(BOOL)async {
    
    CGFloat p = self.contentScaleFactor;
    if (self.phAvailable) {
        if (self.assetsFetchResults.count == 0) {
            self.imageCropView.image = nil;
            self.selectedImage = nil;
            return;
        }
        PHAsset *asset = self.assetsFetchResults[self.selectedIndex-1];
        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        //        options.resizeMode = PHImageRequestOptionsResizeModeExact;
        options.synchronous = !async;
        // Request an image for the asset from the PHCachingImageManager.
        [self.imageManager requestImageForAsset:asset
                                     targetSize:CGSizeMake(asset.pixelWidth, asset.pixelHeight)
                                    contentMode:PHImageContentModeAspectFill
                                        options:options
                                  resultHandler:^(UIImage *result, NSDictionary *info) {
                                      
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          
                                          self.selectedImage = result;
                                          self.imageCropView.imageSize = CGSizeMake(asset.pixelWidth/p, asset.pixelHeight/p);
                                          self.imageCropView.image = self.selectedImage;
                                          if (self.firstTime) {
                                              self.imageCropViewConstraintTop.constant = imageCropViewOriginalConstraintTop;
                                              self.collectionViewConstraintHeight.constant = self.frame.size.height - imageCropViewOriginalConstraintTop - self.imageCropViewContainer.frame.size.height;
                                              self.firstTime = NO;
                                          }
                                      });
                                      
                                  }];
        
        
    } else {
        self.imageCropView.imageSize = CGSizeMake(self.selectedImage.size.width, self.selectedImage.size.height);
        self.imageCropView.image = self.selectedImage;
    }
    
}


#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.phAvailable) {
        // Update cached assets for the new visible area.
        [self updateCachedAssets];
    }
}

#pragma mark - Asset Caching

- (void)resetCachedAssets {
    [self.imageManager stopCachingImagesForAllAssets];
    self.previousPreheatRect = CGRectZero;
}

- (void)updateCachedAssets {
    
    // The preheat window is twice the height of the visible rect.
    CGRect preheatRect = self.collectionView.bounds;
    preheatRect = CGRectInset(preheatRect, 0.0f, -0.5f * CGRectGetHeight(preheatRect));
    
    /*
     Check if the collection view is showing an area that is significantly
     different to the last preheated area.
     */
    CGFloat delta = ABS(CGRectGetMidY(preheatRect) - CGRectGetMidY(self.previousPreheatRect));
    if (delta > CGRectGetHeight(self.collectionView.bounds) / 3.0f) {
        
        // Compute the assets to start caching and to stop caching.
        NSMutableArray *addedIndexPaths = [NSMutableArray array];
        NSMutableArray *removedIndexPaths = [NSMutableArray array];
        
        [self computeDifferenceBetweenRect:self.previousPreheatRect andRect:preheatRect removedHandler:^(CGRect removedRect) {
            NSArray *indexPaths = [self.collectionView aapl_indexPathsForElementsInRect:removedRect];
            [removedIndexPaths addObjectsFromArray:indexPaths];
        } addedHandler:^(CGRect addedRect) {
            NSArray *indexPaths = [self.collectionView aapl_indexPathsForElementsInRect:addedRect];
            [addedIndexPaths addObjectsFromArray:indexPaths];
        }];
        
        NSArray *assetsToStartCaching = [self assetsAtIndexPaths:addedIndexPaths];
        NSArray *assetsToStopCaching = [self assetsAtIndexPaths:removedIndexPaths];
        
        // Update the assets the PHCachingImageManager is caching.
        [self.imageManager startCachingImagesForAssets:assetsToStartCaching
                                            targetSize:CGSizeMake(self.size, self.size)
                                           contentMode:PHImageContentModeAspectFill
                                               options:nil];
        [self.imageManager stopCachingImagesForAssets:assetsToStopCaching
                                           targetSize:CGSizeMake(self.size, self.size)
                                          contentMode:PHImageContentModeAspectFill
                                              options:nil];
        
        // Store the preheat rect to compare against in the future.
        self.previousPreheatRect = preheatRect;
    }
}

- (void)computeDifferenceBetweenRect:(CGRect)oldRect andRect:(CGRect)newRect removedHandler:(void (^)(CGRect removedRect))removedHandler addedHandler:(void (^)(CGRect addedRect))addedHandler {
    if (CGRectIntersectsRect(newRect, oldRect)) {
        CGFloat oldMaxY = CGRectGetMaxY(oldRect);
        CGFloat oldMinY = CGRectGetMinY(oldRect);
        CGFloat newMaxY = CGRectGetMaxY(newRect);
        CGFloat newMinY = CGRectGetMinY(newRect);
        
        if (newMaxY > oldMaxY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, oldMaxY, newRect.size.width, (newMaxY - oldMaxY));
            addedHandler(rectToAdd);
        }
        
        if (oldMinY > newMinY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, newMinY, newRect.size.width, (oldMinY - newMinY));
            addedHandler(rectToAdd);
        }
        
        if (newMaxY < oldMaxY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, newMaxY, newRect.size.width, (oldMaxY - newMaxY));
            removedHandler(rectToRemove);
        }
        
        if (oldMinY < newMinY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, oldMinY, newRect.size.width, (newMinY - oldMinY));
            removedHandler(rectToRemove);
        }
    } else {
        addedHandler(newRect);
        removedHandler(oldRect);
    }
}

- (NSArray *)assetsAtIndexPaths:(NSArray *)indexPaths {
    if (indexPaths.count == 0) { return nil; }
    
    NSMutableArray *assets = [NSMutableArray arrayWithCapacity:indexPaths.count];
    for (NSIndexPath *indexPath in indexPaths) {
        if (indexPath.item != 0) {
            PHAsset *asset = self.assetsFetchResults[indexPath.item-1];
            [assets addObject:asset];
        }
        
    }
    
    return assets;
}


#pragma mark - Actions

- (void)cameraCellDidTap:(id)sender {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.delegate = self;
    [self.viewController presentViewController:picker animated:YES completion:nil];
    
    NSIndexPath *ip = [NSIndexPath indexPathForItem:self.selectedIndex inSection:0];
    HGGridCell *cell = (HGGridCell *)[self.collectionView cellForItemAtIndexPath:ip];
    cell.selectedSquare.hidden = YES;
}

- (void)cropViewTapped:(UITapGestureRecognizer *)tg {
    
    self.dragDirection = HCHDragDirectionStop;
    [self.imageCropView changeScrollable:YES];
    
    if (self.imageCropViewConstraintTop.constant != imageCropViewMinimalVisibleHeight - self.imageCropViewContainer.frame.size.height) {
        return;
    }
    
    // Pop down the crop view from top
    // Get back to the original position
    [UIView animateWithDuration:0.2 delay:0. options:UIViewAnimationOptionCurveEaseInOut animations:^{
        
        self.imageCropViewConstraintTop.constant = imageCropViewOriginalConstraintTop;
        [self layoutIfNeeded];
        
    } completion:^(BOOL finished) {

        CGPoint contentOffset = self.collectionView.contentOffset;
        contentOffset.y+=(self.imageCropViewContainer.frame.size.height);
        [self.collectionView setContentOffset:contentOffset];
        self.collectionViewConstraintHeight.constant = self.frame.size.height - self.imageCropViewContainer.frame.size.height - imageCropViewOriginalConstraintTop;

        
    }];
    
    self.dragDirection = HCHDragDirectionStop;
}

- (NSDictionary *)getCurrentCoordinate {
    if (self.imageCropView.zooming || self.imageCropView.isDragging) {
        return nil;
    }
    return [self.imageCropView currentCoordinate];
}


#pragma mark - KV

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    
    CGFloat top = [change[NSKeyValueChangeNewKey] floatValue];
    top = -top;
    top+=imageCropViewOriginalConstraintTop;
    CGFloat p = top/self.maxOffsetY;
    self.cropShadow.alpha = p;
}



@end
