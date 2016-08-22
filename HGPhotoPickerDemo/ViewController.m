//
//  ViewController.m
//  HGPhotoPickerDemo
//
//  Created by Gong Heng on 8/22/16.
//  Copyright © 2016 HG. All rights reserved.
//

#import "ViewController.h"
#import "HCHPhotoPickerVC.h"


@interface ViewController () <HCHPhotoPickerDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}
- (IBAction)showPicker:(id)sender {

    HCHPhotoPickerVC *vc = [[HCHPhotoPickerVC alloc] init];
    vc.delegate = self;
    [self presentViewController:vc animated:YES completion:^{
        
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Picker Delegate

- (void)hchPhotoPicker:(HCHPhotoPickerVC *)picker didFinishWithImage:(UIImage *)image cropped:(UIImage *)cropped {
    self.imageView.image = cropped;
}

- (void)hchPhotoPickerDidCancel:(HCHPhotoPickerVC *)picker {

}



@end
