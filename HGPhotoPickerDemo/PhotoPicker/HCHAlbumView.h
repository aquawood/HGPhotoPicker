//
//  HCHAlbumView.h
//  matchbox
//
//  Created by Heng Gong on 3/22/16.
//  Copyright © 2016 matchbox. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HCHImageCropView.h"

@class ALAssetsLibrary, ALAssetsGroup, PHFetchResult, PHFetchResultChangeDetails;

@interface HCHAlbumView : UIView


@property (nonatomic, copy) void (^cameraCallBackBlock)();

@property (weak, nonatomic) IBOutlet HCHImageCropView   *imageCropView;

@property (nonatomic, strong) ALAssetsGroup     *currentGroup;
@property (nonatomic, strong) ALAssetsLibrary   *library;
@property (nonatomic, weak) UIViewController    *viewController;
@property (nonatomic, strong) UIImage           *selectedImage;
//@property (nonatomic, strong) UIView                    *imageCropViewContainer;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *imageCropViewConstraintTop;


@property (nonatomic, strong) PHFetchResult     *assetsFetchResults;

- (void)setup;
- (void)loadAssets;
- (void)currentUpdate:(PHFetchResultChangeDetails *)changeDetails;

- (NSDictionary *)getCurrentCoordinate;

- (void)clear;

@end
