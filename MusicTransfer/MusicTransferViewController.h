//
//  MusicTransferViewController.h
//  MusicTransfer
//
//  Created by Josh Ault on 8/10/14.
//  Copyright (c) 2014 ault.io. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
@interface MusicTransferViewController : UIViewController<MPMediaPickerControllerDelegate, UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UIButton *btnChoose;
- (IBAction)chooseMusic:(id)sender;
@property (weak, nonatomic) IBOutlet UILabel *lblStatus;
@property (weak, nonatomic) IBOutlet UILabel *lblTime;
@property (weak, nonatomic) IBOutlet UILabel *lblTotal;
@property (weak, nonatomic) IBOutlet UILabel *lblTotalFailed;
@property (weak, nonatomic) IBOutlet UILabel *lblFailed;
@property (weak, nonatomic) IBOutlet UILabel *lblUnknown;
@property (weak, nonatomic) IBOutlet UILabel *lblCancelled;
@property (weak, nonatomic) IBOutlet UILabel *lblNoStatus;
@property (weak, nonatomic) IBOutlet UILabel *lblID3;
@property (weak, nonatomic) IBOutlet UITextField *txtIp;

@end
