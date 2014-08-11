//
//  MusicTransferViewController.m
//  MusicTransfer
//
//  Created by Josh Ault on 8/10/14.
//  Copyright (c) 2014 ault.io. All rights reserved.
//

#import "MusicTransferViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "AFNetworking.h"

@interface MusicTransferViewController ()

@end

@implementation MusicTransferViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)chooseMusic:(id)sender {
    MPMediaPickerController *soundPicker=[[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeAnyAudio];
    soundPicker.delegate=self;
    soundPicker.allowsPickingMultipleItems=YES;
    [self presentViewController:soundPicker animated:YES completion:nil];
}

-(void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
    [mediaPicker dismissViewControllerAnimated:YES completion:nil];
    NSArray *songs = [mediaItemCollection items];
    songs = @[[songs objectAtIndex:0]];
    
    AFHTTPRequestOperationManager *httpClient = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:@"https://10.23.16.107:8443"]];
    httpClient.responseSerializer = [AFHTTPResponseSerializer serializer];
    [httpClient.operationQueue setMaxConcurrentOperationCount:1];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString * myDocumentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    for (MPMediaItem *item in songs) {
        NSURL *url = [item valueForProperty:MPMediaItemPropertyAssetURL];
        NSLog(@"url: %@", url);
        AVURLAsset *songAsset = [AVURLAsset URLAssetWithURL:url options:nil];
        
        AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:songAsset presetName:AVAssetExportPresetPassthrough];
        
        exporter.outputFileType = @"public.audio";
        
        NSString *artist = [item valueForProperty: MPMediaItemPropertyArtist];
        NSString *title = [item valueForProperty: MPMediaItemPropertyTitle];
        NSString * fileName = [NSString stringWithFormat:@"%@ - %@.mp3", artist, title];
        
        NSString *exportFile = [myDocumentsDirectory stringByAppendingPathComponent:fileName];
        
        NSURL *exportURL = [NSURL fileURLWithPath:exportFile];
        exporter.outputURL = exportURL;
        
        // do the export
        // (completion handler block omitted)
        [exporter exportAsynchronouslyWithCompletionHandler:
         ^{
             long exportStatus = exporter.status;
             
             switch (exportStatus)
             {
                 case AVAssetExportSessionStatusFailed:
                 {
                     NSError *exportError = exporter.error;
                     NSLog (@"!!! AVAssetExportSessionStatusFailed: %@", exportError);
                     break;
                 }
                 case AVAssetExportSessionStatusCompleted:
                 {
                     NSLog (@"AVAssetExportSessionStatusCompleted");
                     
                     NSData *data = [NSData dataWithContentsOfFile:[myDocumentsDirectory stringByAppendingPathComponent:fileName]];
                     
                     NSLog(@"data %@", data);
                     
                     [self sendFileWithData:data];
                     [self deleteFileWithName:[myDocumentsDirectory stringByAppendingPathComponent:fileName]];
                     
                     break;
                 }
                 case AVAssetExportSessionStatusUnknown:
                 {
                     NSLog (@"!!! AVAssetExportSessionStatusUnknown");
                     break;
                 }
                 case AVAssetExportSessionStatusExporting:
                 {
                     NSLog (@"AVAssetExportSessionStatusExporting");
                     break;
                 }
                 case AVAssetExportSessionStatusCancelled:
                 {
                     NSLog (@"!!! AVAssetExportSessionStatusCancelled");
                     break;
                 }
                 case AVAssetExportSessionStatusWaiting:
                 {
                     NSLog (@"AVAssetExportSessionStatusWaiting");
                     break;
                 }
                 default:
                 {
                     NSLog (@"!!! didn't get export status");
                     break;
                 }
             }
         }];
    }
    NSLog(@"%lu items", (unsigned long)songs.count);
}

- (void)sendFileWithData:(NSData *)data {
    NSLog(@"sending file...");
}

- (void)deleteFileWithName:(NSString *)fileName {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:fileName error:&error];
    if (error) {
        NSLog(@"!!! !!! !!! error deleting file %@", fileName);
    }
}

@end
