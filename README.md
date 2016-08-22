# HGPhotoPicker

This is an image viewer and cropper for iOS 7 and above. 
It is compatable with iOS 7 using AssetsLibrary framework and later using Photos framework.

Usage:
Copy PhotoPicker folder to your project
Caller has to be conformed to HGPhotoPickerDelegate protocol

    // Present photo picker 
    HGPhotoPickerVC *vc = [[HGPhotoPickerVC alloc] init];
    vc.delegate = self;
    [self presentViewController:vc animated:YES completion:NULL];
    

In the callbacks:

    This method gets called after image cropped
    // image is the original image from the album
    // cropped is the cropped image
    - (void)hgPhotoPicker:(HGPhotoPickerVC *)picker didFinishWithImage:(UIImage *)image cropped:(UIImage *)cropped {
    
    }
    
    Called when user cancels
    - (void)hgPhotoPickerDidCancel:(HGPhotoPickerVC *)picker {
    
    }




  
