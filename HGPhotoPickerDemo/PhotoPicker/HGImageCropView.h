//
//  HCHImageCropVIew.h
//  matchbox
//
//  Created by Heng Gong on 3/22/16.
//  Copyright © 2016 matchbox. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HGImageCropView : UIScrollView

@property (nonatomic, strong) UIImage   *image;
@property (nonatomic, assign) CGSize    imageSize;

- (void)changeScrollable:(BOOL)isScrollable;

- (NSDictionary *)currentCoordinate;

@end
