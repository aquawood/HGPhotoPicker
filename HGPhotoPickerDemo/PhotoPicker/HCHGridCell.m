//
//  HCHGridCell.m
//  matchbox
//
//  Created by Heng Gong on 12/24/15.
//  Copyright © 2015 matchbox. All rights reserved.
//

#import "HCHGridCell.h"


@implementation HCHGridCell

- (instancetype)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
        
        // Image
        _imageView = [UIImageView new];
        _imageView.frame = self.bounds;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;

        _imageView.autoresizesSubviews = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        [self addSubview:_imageView];

        // Selection button
        _selectedButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _selectedButton.contentMode = UIViewContentModeCenter;
        _selectedButton.adjustsImageWhenHighlighted = NO;
        UIImage *off = [UIImage imageNamed:@"icon_select_picture.png"];
        UIImage *on = [UIImage imageNamed:@"icon_selected.png"];
        
        [_selectedButton setImage:off forState:UIControlStateNormal];
        [_selectedButton setImage:on forState:UIControlStateSelected];
        [_selectedButton addTarget:self action:@selector(selectionButtonPressed) forControlEvents:UIControlEventTouchDown];
        _selectedButton.hidden = YES;
        _selectedButton.frame = CGRectMake(0, 0, 44, 44);
        _selectedButton.imageEdgeInsets = UIEdgeInsetsMake(2, 20, 20, 2);
        [self addSubview:_selectedButton];
        _imageView.frame = self.bounds;
        _selectedButton.frame = CGRectMake(self.bounds.size.width - _selectedButton.frame.size.width - 0,
                                           0, _selectedButton.frame.size.width, _selectedButton.frame.size.height);
        _selectedSquare = [[UIView alloc] initWithFrame:CGRectInset(self.bounds, 0, 0)];
        _selectedSquare.layer.borderWidth = 2.0f;
        _selectedSquare.layer.borderColor = [UIColor greenColor].CGColor;
        _selectedSquare.hidden = YES;
        _selectedSquare.backgroundColor = [UIColor clearColor];
        [self addSubview:_selectedSquare];
    }
    
    return self;
}

- (void)prepareForReuse {
    self.selectedSquare.hidden = YES;
}

//- (void)layoutSubviews {
//    [super layoutSubviews];
//
//}


#pragma mark - Actions

- (void)selectionButtonPressed {
    self.selectedButton.selected = !self.selectedButton.selected;
    [self.delegate gridCell:self didSelect:self.selectedButton.selected atIndex:self.index];
}



@end











