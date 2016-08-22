//
//  HCHPhotoPickerVC.h
//  matchbox
//
//  Created by Heng Gong on 3/22/16.
//  Copyright © 2016 matchbox. All rights reserved.
//

#import <UIKit/UIKit.h>


@class HCHPhotoPickerVC;

@protocol HCHPhotoPickerDelegate <NSObject>

- (void)hchPhotoPicker:(HCHPhotoPickerVC *)picker didFinishWithImage:(UIImage *)image cropped:(UIImage *)cropped;

- (void)hchPhotoPickerDidCancel:(HCHPhotoPickerVC *)picker;

@end

@interface HCHPhotoPickerVC : UIViewController

@property (nonatomic, weak) id <HCHPhotoPickerDelegate> delegate;


@end
