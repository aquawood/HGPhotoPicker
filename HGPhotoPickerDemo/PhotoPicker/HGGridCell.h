//
//  HCHGridCell.h
//  matchbox
//
//  Created by Heng Gong on 12/24/15.
//  Copyright © 2015 matchbox. All rights reserved.
//

#import <UIKit/UIKit.h>

@class HGGridCell;

@protocol HGGridCellDelegate <NSObject>

- (void)gridCell:(HGGridCell *)cell didSelect:(BOOL)selected atIndex:(NSInteger)index;

@end

@interface HGGridCell : UICollectionViewCell

@property (nonatomic, strong) UIButton  *selectedButton;

@property (nonatomic, strong) UIView    *selectedSquare;

@property (nonatomic, strong) UIImageView *imageView;

@property (nonatomic, assign) NSInteger index;

@property (nonatomic, weak) id<HGGridCellDelegate> delegate;

@property (nonatomic, copy) NSString *representedAssetIdentifier;


//- (void)configWithImage:(UIImage *)image;
//
//- (void)configWithURLStr:(NSString *)str;

@end
