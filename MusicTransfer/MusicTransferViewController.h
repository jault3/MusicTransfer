//
//  MusicTransferViewController.h
//  MusicTransfer
//
//  Created by Josh Ault on 8/10/14.
//  Copyright (c) 2014 ault.io. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
@interface MusicTransferViewController : UIViewController<MPMediaPickerControllerDelegate>
@property (weak, nonatomic) IBOutlet UIButton *btnChoose;
- (IBAction)chooseMusic:(id)sender;
@property (weak, nonatomic) IBOutlet UILabel *lblStatus;

@end
