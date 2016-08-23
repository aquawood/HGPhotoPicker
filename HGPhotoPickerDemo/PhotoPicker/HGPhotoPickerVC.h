//
//  HCHPhotoPickerVC.h
//  HG
//
//  Created by Heng Gong on 3/22/16.
//  Copyright © 2016 HG. All rights reserved.
//

#import <UIKit/UIKit.h>


@class HGPhotoPickerVC;

@protocol HGPhotoPickerDelegate <NSObject>

- (void)hgPhotoPicker:(HGPhotoPickerVC *)picker didFinishWithImage:(UIImage *)image cropped:(UIImage *)cropped;

- (void)hgPhotoPickerDidCancel:(HGPhotoPickerVC *)picker;

@end

@interface HGPhotoPickerVC : UIViewController

@property (nonatomic, weak) id <HGPhotoPickerDelegate> delegate;


@end
