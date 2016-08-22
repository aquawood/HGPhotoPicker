//
//  ViewController.m
//  HGPhotoPickerDemo
//
//  Created by Gong Heng on 8/22/16.
//  Copyright © 2016 HG. All rights reserved.
//

#import "ViewController.h"
#import "HGPhotoPickerVC.h"


@interface ViewController () <HGPhotoPickerDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}
- (IBAction)showPicker:(id)sender {

    HGPhotoPickerVC *vc = [[HGPhotoPickerVC alloc] init];
    vc.delegate = self;
    [self presentViewController:vc animated:YES completion:^{
        
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Picker Delegate

- (void)hgPhotoPicker:(HGPhotoPickerVC *)picker didFinishWithImage:(UIImage *)image cropped:(UIImage *)cropped {
    self.imageView.image = cropped;
}

- (void)hgPhotoPickerDidCancel:(HGPhotoPickerVC *)picker {

}



@end
