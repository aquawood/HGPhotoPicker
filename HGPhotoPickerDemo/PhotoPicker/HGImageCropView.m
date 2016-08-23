//
//  HCHImageCropVIew.m
//  HG
//
//  Created by Heng Gong on 3/22/16.
//  Copyright © 2016 HG. All rights reserved.
//

#import "HGImageCropView.h"

@interface HGImageCropView () <UIScrollViewDelegate>

@property (nonatomic, strong) UIImageView   *imageView;

@end

@implementation HGImageCropView

- (void)setup {
    self.imageView = [[UIImageView alloc] init];
    [self addSubview:self.imageView];
    
    self.backgroundColor = [UIColor blackColor];
    self.clipsToBounds   = YES;
    self.imageView.alpha = 0.0;
    
    self.imageView.frame = CGRectZero;
    
    self.maximumZoomScale = 2.0;
    self.minimumZoomScale = 1;
    self.showsHorizontalScrollIndicator = NO;
    self.showsVerticalScrollIndicator   = NO;
    self.bouncesZoom = YES;
    self.bounces = YES;
    
    self.delegate = self;
}

- (void)awakeFromNib {
    [self setup];
}

- (void)setImage:(UIImage *)image {
    if (image == nil) {
        _image = nil;
        self.imageView.image = nil;
        return;
    }
    const CGFloat limit = 16/9.0f;
    _image = image;
    CGSize imageSize = self.imageSize;

    // Width > Height
    if (imageSize.width > imageSize.height) {
        
        CGFloat ratio = imageSize.width / imageSize.height;
        
        // less than 16:9
        if (imageSize.width/imageSize.height <= limit) {
            self.imageView.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.width / ratio);
            self.imageView.center = self.center;
            
        // greater than 16:9
        } else {
            CGFloat height = self.frame.size.width/limit;
            CGFloat width = height*ratio;
            self.imageView.frame = CGRectMake(0, (self.frame.size.height-height)/2.0, width, height);
            self.contentOffset = CGPointMake((width-CGRectGetWidth(self.bounds))/2.0, 0);
        }
        
    } else {
        
        // Width <= Height
        CGFloat ratio = self.frame.size.width / imageSize.width;
        self.imageView.frame = CGRectMake(0, 0, self.frame.size.width, imageSize.height * ratio);
        self.contentOffset = CGPointMake(self.imageView.center.x - self.center.x, self.imageView.center.y - self.center.y);
    }

    
    self.contentSize = CGSizeMake(self.imageView.frame.size.width + 1, self.imageView.frame.size.height + 1);
    
    self.imageView.image = image;
    self.imageView.alpha = 1;
    
    self.zoomScale = 1.0;
    [self setNeedsLayout];
}


- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    CGSize boundsSize = scrollView.bounds.size;
    CGRect contentsFrame = self.imageView.frame;
    
    if (scrollView.zoomScale > 1) {
        if (contentsFrame.size.width < boundsSize.width) {
            
            contentsFrame.origin.x = (boundsSize.width - contentsFrame.size.width) / 2.0;
            
            // test
            CGFloat ratio = contentsFrame.size.height/contentsFrame.size.width;
            contentsFrame.size.width = boundsSize.width;
            contentsFrame.size.height = boundsSize.width*ratio;
            self.zoomScale = 1.0;
            contentsFrame.origin.x = 0.0;
            
        } else {
            //        contentsFrame.origin.x = 0.0;
        }
        
        if (contentsFrame.size.height < boundsSize.height) {
            
            contentsFrame.origin.y = (boundsSize.height - contentsFrame.size.height) / 2.0;
            if ((boundsSize.width/contentsFrame.size.height)>(16/9.0f)) {
                CGFloat ratio = contentsFrame.size.height/contentsFrame.size.width;
                contentsFrame.size.height = boundsSize.width/(16/9.0f);
                contentsFrame.size.width = contentsFrame.size.height/ratio;
                self.zoomScale = 1.0;
                contentsFrame.origin.x = 0.0;
            }
        } else {
            
            contentsFrame.origin.y = 0.0;
        }
        
        
        self.imageView.frame = contentsFrame;
    }
    
    

}


- (void)changeScrollable:(BOOL)isScrollable {
    self.scrollEnabled = isScrollable;
}

- (UIImage *)currentCrop {
    
    UIImage *crop = [UIImage new];
    CGSize size = self.frame.size;
    CGFloat y = -self.contentOffset.y;
    if (self.imageView.bounds.size.height < self.bounds.size.height) {
        size.height = self.imageView.bounds.size.height;
        y = -(self.bounds.size.height - self.imageView.bounds.size.height)/2.0f;
    }
    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, -self.contentOffset.x, y);
    [self.layer renderInContext:context];
    crop = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return crop;
}

- (NSDictionary *)currentCoordinate {
    
    CGRect visibleRect = [self convertRect:self.bounds toView:self.imageView];
    
    CGFloat ratio = self.imageSize.width/self.imageSize.height;
    UIImage *croppedImage = [self currentCrop];
    if (croppedImage == nil) {
        return nil;
    }
    CGFloat is = self.contentScaleFactor;
    CGFloat zs = self.zoomScale;
    CGFloat heightRatio = self.imageView.image.size.height / self.imageView.image.size.height;

    const CGFloat limit = 16/9.0f;
    CGFloat widthRatio = 0;
    
    if (ratio <= limit) {
        widthRatio =  self.imageView.image.size.width / self.frame.size.width;
        
    } else {
        widthRatio = self.imageView.image.size.width / (self.contentSize.width-1);
    }

    CGFloat w = visibleRect.size.width *is*widthRatio;
    CGFloat h = visibleRect.size.height *is*widthRatio;
    
    CGFloat x = (self.imageView.frame.origin.x + self.contentOffset.x)*is*widthRatio/zs;
    CGFloat y = (self.imageView.frame.origin.y + self.contentOffset.y)*is*widthRatio/zs;
    if (ratio > limit) {
        y = (visibleRect.origin.y + self.contentOffset.y)*is*heightRatio/zs;

        x = (self.contentOffset.x + self.imageView.frame.origin.x)*is*widthRatio;
        w = self.bounds.size.width *is*widthRatio;
        if (y < 0) {
            y = 0;
            h = self.image.size.height*is;
        } else {
            CGFloat luckyNumber = 10;
            y = (visibleRect.origin.y + self.contentOffset.y+luckyNumber)*is*heightRatio;
            h = self.bounds.size.height*is*widthRatio;
        }
    
    }

    if (self.image.size.width < self.bounds.size.width && self.image.size.height < self.bounds.size.height) {
        
        x = (self.contentOffset.x)*is*widthRatio/zs;
        y = (self.contentOffset.y)*is*widthRatio/zs;
        w = self.bounds.size.width *is *widthRatio *self.image.scale/zs;
        h = self.bounds.size.height *is *widthRatio *self.image.scale/zs;
    }
    
    if (self.imageView.bounds.size.height < self.bounds.size.height) {
        y = 0;
        h = self.image.size.height*self.image.scale;
    }
    
    x = fmax(0, x);
    y = fmax(0, y);
    w = fmin(self.image.size.width*self.image.scale, w);
    h = fmin(self.image.size.height*self.image.scale, h);
    
    
    
    return @{@"cropped": croppedImage,
             @"coord": [NSString stringWithFormat:@"%f,%f",x,y],
             @"width": @(w),
             @"height": @(h)};
}


@end
