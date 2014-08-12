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
#import "Constants.h"
#import <AudioToolbox/AudioToolbox.h>

@interface MusicTransferViewController ()

@property (strong, nonatomic) AFHTTPRequestOperationManager *fileHttpClient;
@property (strong, nonatomic) AFHTTPRequestOperationManager *jsonHttpClient;
@property (strong, nonatomic) NSString *myDocumentsDirectory;
@property (strong, nonatomic) NSArray *songs;
@property long totalCount;
@property int failCount;
@property int cancelledCount;
@property int unknownCount;
@property int noStatusCount;
@property int id3Failed;
@property int currentIndex;

@property long startTime;

@property BOOL verified;

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
    
    self.navigationItem.title = @"Music Transfer";
    
    [self clearFiles];
    _songs = [NSArray array];
    _verified = NO;
    
    _txtIp.text = kBaseUrl;
    [self textFieldShouldReturn:_txtIp];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    _myDocumentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
}

- (void)initHttpClients:(NSString *)baseUrl {
    _fileHttpClient = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:baseUrl]];
    _fileHttpClient.responseSerializer = [AFHTTPResponseSerializer serializer];
    [_fileHttpClient.operationQueue setMaxConcurrentOperationCount:20];
    
    _jsonHttpClient = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:baseUrl]];
    _jsonHttpClient.responseSerializer = [AFHTTPResponseSerializer serializer];
    _jsonHttpClient.requestSerializer = [AFJSONRequestSerializer serializer];
    [_jsonHttpClient.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [_jsonHttpClient.operationQueue setMaxConcurrentOperationCount:20];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(advanceIterator) name:@"Advance" object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)clearFiles {
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_myDocumentsDirectory error:nil];
    for (int count = 0; count < [directoryContent count]; count++) {
        [self deleteFileAtPath:[_myDocumentsDirectory stringByAppendingPathComponent:[directoryContent objectAtIndex:count]]];
    }
}

- (IBAction)chooseMusic:(id)sender {
    if (!_verified) {
        [[[UIAlertView alloc] initWithTitle:@"Invalid IP Address" message:@"Please insert a valid IP address of a computer running the Music Transfer desktop program" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
        return;
    }
    _btnChoose.enabled = NO;
    MPMediaPickerController *mediaPicker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeAnyAudio];
    mediaPicker.delegate = self;
    mediaPicker.allowsPickingMultipleItems = YES;
    [self presentViewController:mediaPicker animated:YES completion:nil];
}

-(void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
    [mediaPicker dismissViewControllerAnimated:YES completion:^{
        _songs = [mediaItemCollection items];
        _totalCount = _songs.count;
        
        _startTime = [[NSDate date] timeIntervalSince1970];
        
        _failCount = 0;
        _cancelledCount = 0;
        _unknownCount = 0;
        _noStatusCount = 0;
        _id3Failed = 0;
        
        _currentIndex = 0;
        [self refreshLabels];
        
        [UIView animateWithDuration:0.2 animations:^{
            [_btnChoose setTitle:@"Transferring" forState:UIControlStateNormal];
            _btnChoose.backgroundColor = [UIColor lightGrayColor];
        }];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"Advance" object:self];
    }];
}

- (void)refreshLabels {
    _lblStatus.text = [NSString stringWithFormat:@"Transferred %d of %ld songs", _currentIndex, _totalCount];
    
    _lblTotal.text = [NSString stringWithFormat:@"%li total items\n", _totalCount];
    _lblTotalFailed.text = [NSString stringWithFormat:@"%i with a failing status\n", (_failCount + _unknownCount + _cancelledCount + _noStatusCount)];
    _lblFailed.text = [NSString stringWithFormat:@"\t%i simply failed\n", _failCount];
    _lblUnknown.text = [NSString stringWithFormat:@"\t%i unknown\n", _unknownCount];
    _lblCancelled.text = [NSString stringWithFormat:@"\t%i cancelled\n", _cancelledCount];
    _lblNoStatus.text = [NSString stringWithFormat:@"\t%i with no status\n", _noStatusCount];
    _lblID3.text = [NSString stringWithFormat:@"\t%i ID3 tags not saved\n", _id3Failed];
}

- (void)advanceIterator {
    if (_currentIndex >= _totalCount) {
        [self finishedUploading];
        return;
    }
    
    [self refreshLabels];
    MPMediaItem *item = [_songs objectAtIndex:_currentIndex];
    _currentIndex++;
    
    NSURL *url = [item valueForProperty:MPMediaItemPropertyAssetURL];
    AVURLAsset *songAsset = [AVURLAsset URLAssetWithURL:url options:nil];
    
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:songAsset presetName:AVAssetExportPresetPassthrough];
    exporter.outputFileType = @"com.apple.quicktime-movie";
    
    id artist = [item valueForProperty: MPMediaItemPropertyArtist];
    id title = [item valueForProperty: MPMediaItemPropertyTitle];
    id album = [item valueForProperty: MPMediaItemPropertyAlbumTitle];
    id trackCount = [item valueForProperty: MPMediaItemPropertyAlbumTrackCount];
    id trackNumber = [item valueForProperty: MPMediaItemPropertyAlbumTrackNumber];
    id genre = [item valueForProperty: MPMediaItemPropertyGenre];
    id playCount = [item valueForProperty: MPMediaItemPropertyPlayCount];
    id rating = [item valueForProperty: MPMediaItemPropertyRating];
    
    NSString *fileName = [NSString stringWithFormat:@"%@ - %@", artist, title];
    NSString *fileNameWithEnding = [NSString stringWithFormat:@"%@.mov", fileName];
    
    NSString *exportFile = [_myDocumentsDirectory stringByAppendingPathComponent:fileNameWithEnding];
    
    exporter.outputURL = [NSURL fileURLWithPath:exportFile];
    
    [exporter exportAsynchronouslyWithCompletionHandler:^{
         switch (exporter.status) {
             case AVAssetExportSessionStatusFailed: {
                 NSError *exportError = exporter.error;
                 NSLog(@"!!! AVAssetExportSessionStatusFailed: %@", exportError);
                 _failCount++;
                 [self refreshLabels];
                 break;
             }
             case AVAssetExportSessionStatusCompleted: {
                 NSString *movPath = [_myDocumentsDirectory stringByAppendingPathComponent:fileNameWithEnding];
                 NSString *mp3Path = [_myDocumentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp3",fileName]];
                 
                 NSError *error = nil;
                 [[NSFileManager defaultManager] moveItemAtPath:movPath toPath:mp3Path error:&error];
                 if (error) {
                     NSLog(@"error moving: %@", error);
                 }
                 NSData *data = [NSData dataWithContentsOfFile:mp3Path];
                 
                 [self sendFileWithData:data fileName:fileName artist:artist title:title album:album trackCount:trackCount trackNumber:trackNumber genre:genre playCount:playCount rating:rating];
                 [self deleteFileAtPath:mp3Path];
                 
                 break;
             }
             case AVAssetExportSessionStatusUnknown: {
                 NSLog(@"!!! AVAssetExportSessionStatusUnknown");
                 _unknownCount++;
                 [self refreshLabels];
                 break;
             }
             case AVAssetExportSessionStatusExporting: {
                 NSLog(@"AVAssetExportSessionStatusExporting");
                 break;
             }
             case AVAssetExportSessionStatusCancelled: {
                 NSLog(@"!!! AVAssetExportSessionStatusCancelled");
                 _cancelledCount++;
                 [self refreshLabels];
                 break;
             }
             case AVAssetExportSessionStatusWaiting: {
                 NSLog(@"AVAssetExportSessionStatusWaiting");
                 break;
             }
             default: {
                 NSLog(@"!!! didn't get export status (a.k.a. #WTF)");
                 _noStatusCount++;
                 [self refreshLabels];
                 break;
             }
         }
     }];
}

- (void)setTagsWithName:(NSString *)fileName artist:(id)artist title:(id)title album:(id)album trackCount:(id)trackCount trackNumber:(id)trackNumber genre:(id)genre playCount:(id)playCount rating:(id)rating {
    artist = artist == nil ? @"" : artist;
    title = title == nil ? @"" : title;
    album = album == nil ? @"" : album;
    trackCount = trackCount == nil ? @"" : trackCount;
    trackNumber = trackNumber == nil ? @"" : trackNumber;
    genre = genre == nil ? @"" : genre;
    playCount = playCount == nil ? @"" : playCount;
    rating = rating == nil ? @"" : rating;
    
    NSDictionary *params = @{@"artist":artist, @"title":title, @"album":album, @"trackCount":trackCount, @"trackNumber":trackNumber, @"genre":genre, @"playCount":playCount, @"rating":rating, @"fileName":fileName};
    
    [_jsonHttpClient POST:@"/files/tags" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"Advance" object:self];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"failed to set tags");
        _id3Failed++;
        [self refreshLabels];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"Advance" object:self];
    }];
}

- (void)sendFileWithData:(NSData *)data fileName:(NSString *)fileName artist:(id)artist title:(id)title album:(id)album trackCount:(id)trackCount trackNumber:(id)trackNumber genre:(id)genre playCount:(id)playCount rating:(id)rating {
    [_fileHttpClient POST:@"/files" parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        [formData appendPartWithFileData:data name:@"file" fileName:[NSString stringWithFormat:@"%@.mp3", fileName] mimeType:@"audio/mp3"];
    } success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSString *returnedName = [[NSJSONSerialization JSONObjectWithData:responseObject options:0 error:nil] valueForKey:@"fileName"];
        
        [self setTagsWithName:returnedName artist:artist title:title album:album trackCount:trackCount trackNumber:trackNumber genre:genre playCount:playCount rating:rating];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"failed to upload: %@", error);
        _failCount++;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"Advance" object:self];
    }];
}

- (void)deleteFileAtPath:(NSString *)path {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    if (error) {
        NSLog(@"!!! error deleting file at %@ - %@", path, error);
    }
}

- (void)finishedUploading {
    [self refreshLabels];
    
    long endTime = [[NSDate date] timeIntervalSince1970];
    long totalSeconds = endTime - _startTime;
    int minutes = (int)totalSeconds/60;
    int seconds = (int)(totalSeconds - (minutes * 60));
    
    _lblStatus.text = @"Finished";
    _lblTime.text = [NSString stringWithFormat:@"Total time: %i m %i s\n", minutes, seconds];
    
    [UIView animateWithDuration:0.2 animations:^{
        _btnChoose.enabled = YES;
        [_btnChoose setTitle:@"Choose" forState:UIControlStateNormal];
        [_btnChoose setBackgroundColor:[UIColor colorWithRed:42.0/255.0f green:130.0/255.0f blue:217.0/255.0f alpha:1.0f]];
    }];
}

- (void)verifyBaseUrl {
    [self initHttpClients:_txtIp.text];
    [_jsonHttpClient GET:@"/check" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *response = [NSJSONSerialization JSONObjectWithData:responseObject options:0 error:nil];
        if ([[response valueForKey:@"service"] isEqualToString:@"MusicTransfer"]) {
            _verified = YES;
        } else {
            _verified = NO;
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        _verified = NO;
    }];
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    _verified = NO;
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self verifyBaseUrl];
    return YES;
}

@end
