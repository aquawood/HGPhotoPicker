//
//  HCHAlbumView.h
//  HG
//
//  Created by Heng Gong on 3/22/16.
//  Copyright © 2016 HG. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HGImageCropView.h"

@class ALAssetsLibrary, ALAssetsGroup, PHFetchResult, PHFetchResultChangeDetails;

@interface HGAlbumView : UIView


@property (nonatomic, copy) void (^cameraCallBackBlock)();

@property (weak, nonatomic) IBOutlet HGImageCropView   *imageCropView;

@property (nonatomic, strong) ALAssetsGroup     *currentGroup;
@property (nonatomic, strong) ALAssetsLibrary   *library;
@property (nonatomic, weak) UIViewController    *viewController;
@property (nonatomic, strong) UIImage           *selectedImage;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *imageCropViewConstraintTop;


@property (nonatomic, strong) PHFetchResult     *assetsFetchResults;

- (void)setup;
- (void)loadAssets;
- (void)currentUpdate:(PHFetchResultChangeDetails *)changeDetails;

- (NSDictionary *)getCurrentCoordinate;

- (void)clear;

@end
