//
//  HCHGridCell.h
//  matchbox
//
//  Created by Heng Gong on 12/24/15.
//  Copyright © 2015 matchbox. All rights reserved.
//

#import <UIKit/UIKit.h>

@class HCHGridCell;

@protocol HCHGridCellDelegate <NSObject>

- (void)gridCell:(HCHGridCell *)cell didSelect:(BOOL)selected atIndex:(NSInteger)index;

@end

@interface HCHGridCell : UICollectionViewCell

@property (nonatomic, strong) UIButton  *selectedButton;

@property (nonatomic, strong) UIView    *selectedSquare;

@property (nonatomic, strong) UIImageView *imageView;

@property (nonatomic, assign) NSInteger index;

@property (nonatomic, weak) id<HCHGridCellDelegate> delegate;

@property (nonatomic, copy) NSString *representedAssetIdentifier;


//- (void)configWithImage:(UIImage *)image;
//
//- (void)configWithURLStr:(NSString *)str;

@end
