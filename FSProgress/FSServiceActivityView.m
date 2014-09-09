//
//  FSServiceActivityView.m
//  FSProgress
//
//  Created by Sebastian Buks on 09/07/14.
//  Copyright (c) 2014 Mobiento AB. All rights reserved.
//

#define kSERVICE_INDICATOR_HEIGHT 40.0f
#define kSERVICE_INDICATOR_HEIGHT_FAILURE 80.0f
#define kSERVICE_DISPLAY_TIME 5.0f
#define kPROGRESS_BAR_HEIGHT 3.0f

#import <AudioToolbox/AudioToolbox.h> 
#import "FSServiceActivityView.h"
#import "FSOrderedDictionary.h"
#import "FSData.h"

@interface FSServiceActivityView () <FSMutableArrayDelegate>
{
    UITapGestureRecognizer *tapGesture;
    UIImageView *progressBarView;
    UILabel *readMoreLabel;
    
    CGRect origStatusFrame;
    CGRect origFrame;
    float padding;
    
    int activeObject;
    NSNumber *activeService;
    
    BOOL isRunning;
    BOOL paused;
}

@property (nonatomic, strong) UIViewController *rootViewController;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *failureLabel;
@property (nonatomic, strong) NSDictionary *serviceNotificationMessageKeys;
@property (nonatomic, strong) UIImageView *serviceIcon;
@property (nonatomic, strong) UIView *progressBar;
@property (nonatomic, strong) NSTimer *hideTimer;
@property (nonatomic, strong) UIButton *closeButton;
@property (atomic, strong) FSOrderedDictionary *activeServiesQueue;
@property (nonatomic, strong) FSMutableArray *toBeDisplayed;

@end
    
@implementation FSServiceActivityView

#pragma mark - Init methods

+ (id)sharedInstance
{
    static FSServiceActivityView *serviceActivityIndicatorView = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        serviceActivityIndicatorView = [[self alloc] init];
    });
    
    return serviceActivityIndicatorView;
}

- (void)setRootViewController:(UIViewController *)rootViewController andFont:(UIFont *)font
{    
    _rootViewController = rootViewController;
    _activeServiesQueue = [[FSOrderedDictionary alloc] init];
    _toBeDisplayed = [[FSMutableArray alloc] init];
    [_activeServiesQueue.array setDelegate:self];
    [_toBeDisplayed setDelegate:self];
    
    origFrame = CGRectMake(0, [UIScreen mainScreen].bounds.size.height - kSERVICE_INDICATOR_HEIGHT, [UIScreen mainScreen].bounds.size.width, kSERVICE_INDICATOR_HEIGHT);
        
    self.frame = origFrame;
    
    if (self)
    {
        self.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
        self.clipsToBounds = NO;
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.9f];
     
        padding = 10;

        [self setupProgressBar];
        [self setupStatusLabel:font];
        [self setupFailureLabel:font];
        
        self.alpha = 0;
    }
    
    [rootViewController.view addSubview:self];
}

#pragma mark - UI setup methods

- (void)setupStatusLabel:(UIFont *)font
{
    _statusLabel = [[UILabel alloc] init];
    if (font == nil)
        font = [UIFont systemFontOfSize:14];
    
    _statusLabel.font = font;
    _statusLabel.textColor = [UIColor whiteColor];
    _statusLabel.backgroundColor = [UIColor clearColor];
    _statusLabel.textAlignment = NSTextAlignmentLeft;
    _statusLabel.userInteractionEnabled = YES;

    float height = CGRectGetHeight(self.frame);
    float width = CGRectGetWidth(self.frame);
    _serviceIcon = [[UIImageView alloc] initWithFrame:CGRectMake(padding,
                                                                 padding,
                                                                 padding * 2,
                                                                 padding * 2)];
    _serviceIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:_serviceIcon];
    
    float iconMaxX = CGRectGetMaxX(_serviceIcon.frame);
    _statusLabel.frame = CGRectMake(iconMaxX + padding,
                                    0,
                                    width - iconMaxX - padding - padding,
                                    kSERVICE_INDICATOR_HEIGHT);
    
    origStatusFrame = _statusLabel.frame;
    
    [self addSubview:_statusLabel];
    
    _closeButton = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetWidth(self.frame) - height,
                                                              0,
                                                              height,
                                                              height)];
    
    [_closeButton setImage:[UIImage imageNamed:@"closebutton-white"] forState:UIControlStateNormal];
    [_closeButton addTarget:self action:@selector(tappedCloseButton) forControlEvents:UIControlEventTouchUpInside];
    _closeButton.hidden = YES;
        
    [self addSubview:_closeButton];
}

- (void)setupProgressBar
{
    progressBarView = [[UIImageView alloc] initWithFrame:CGRectMake(0,
                                                                    -kPROGRESS_BAR_HEIGHT,
                                                                    [UIScreen mainScreen].bounds.size.width,
                                                                    kPROGRESS_BAR_HEIGHT)];
    
    NSMutableArray *animationImages = [[NSMutableArray alloc] initWithCapacity:16];
    
    for (int x = 1; x <= 16; x++)
    {
        [animationImages addObject:[UIImage imageNamed:[NSString stringWithFormat:@"%@%d", @"progress_drawable_", x]]];
    }
    
    progressBarView.animationImages = animationImages;
    [progressBarView startAnimating];
    
    _progressBar = [[UIView alloc] initWithFrame:CGRectMake(0,
                                                            0,
                                                            [UIScreen mainScreen].bounds.size.width,
                                                            kPROGRESS_BAR_HEIGHT)];
    
    _progressBar.backgroundColor = [UIColor blackColor];
    
    [progressBarView addSubview:_progressBar];
    [self addSubview:progressBarView];
}

- (void)setupFailureLabel:(UIFont *)font
{
    readMoreLabel = [[UILabel alloc] initWithFrame:CGRectMake(_statusLabel.frame.origin.x,
                                                              _statusLabel.frame.origin.y + padding,
                                                              CGRectGetWidth(self.frame) - 2 * padding,
                                                              kSERVICE_INDICATOR_HEIGHT)];
    readMoreLabel.alpha = 0;
    readMoreLabel.font = [UIFont boldSystemFontOfSize:font.pointSize - 4.0f];
    readMoreLabel.textColor = [UIColor whiteColor];
    readMoreLabel.backgroundColor = [UIColor clearColor];
    readMoreLabel.textAlignment = NSTextAlignmentLeft;
    readMoreLabel.text = @"More info available";
    [self addSubview:readMoreLabel];
    
    _failureLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding,
                                                              _statusLabel.frame.origin.y + padding,
                                                              CGRectGetWidth(self.frame) - 4 * padding,
                                                              kSERVICE_INDICATOR_HEIGHT_FAILURE)];
    _failureLabel.font = [UIFont systemFontOfSize:font.pointSize - 4.0f];
    _failureLabel.textColor = [UIColor whiteColor];
    _failureLabel.backgroundColor = [UIColor clearColor];
    _failureLabel.textAlignment = NSTextAlignmentLeft;
    _failureLabel.adjustsFontSizeToFitWidth = YES;
    _failureLabel.numberOfLines = 3;
    _failureLabel.minimumScaleFactor = 1;
    [self addSubview:_failureLabel];
    _failureLabel.hidden = YES;
    
    tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showFailureDescription)];
}

#pragma mark - Parser

- (void)queueData:(id)updateData
{
    if ([updateData conformsToProtocol:@protocol(FSData)])
    {
        NSObject<FSData> *data = updateData;

        if (data.aTitle != nil && data.aServiceID && data.aCurrentStep <= data.aMaxSteps)
        {
            // If there are no active services add it to the queue at position 0
            if ([_activeServiesQueue count] == 0)
            {
                FSMutableArray *new = [[FSMutableArray alloc] initWithObjects:data, nil];
                [_activeServiesQueue setObject:new forKey:data.aServiceID];
            }
            // If serviceID already exists in queue and is at position 0
            else if ([(NSObject<FSData>*)[[[_activeServiesQueue objectForKey:[_activeServiesQueue keyAtIndex:0]] objectAtIndex:0] aServiceID] isEqual:data.aServiceID])
            {
                FSMutableArray *existing = [_activeServiesQueue objectForKey:data.aServiceID];
                [existing addObject:data];
            }
            // If it exists but is not the active service (not queued in position 0), replace existing data.
            else if ([_activeServiesQueue objectForKey:data.aServiceID] != nil && ![(NSObject<FSData>*)[[[_activeServiesQueue objectForKey:[_activeServiesQueue keyAtIndex:0]] objectAtIndex:0] aServiceID] isEqual:data.aServiceID])
            {
                FSMutableArray *existingNotActive = [_activeServiesQueue objectForKey:data.aServiceID];
                [existingNotActive replaceObjectAtIndex:0 withObject:data];
            }
            // If serviceID is not present, add a new queue
            else if ([_activeServiesQueue objectForKey:data.aServiceID] == nil)
            {
                FSMutableArray *new = [[FSMutableArray alloc] initWithObjects:data, nil];
                [_activeServiesQueue setObject:new forKey:data.aServiceID];
            }
        }
    }
}

#pragma mark - FSMutableArayDelegate methods

- (void)object:(id)object wasAddedToArray:(FSMutableArray *)array
{
    if ([_activeServiesQueue count] == 1) {
        [self startWorker];
        DLog(@"Starting worker");
    }
    
    if ([array isEqual:_toBeDisplayed] && !isRunning && !paused)
    {
        DLog(@"Starting UI %@", isRunning ? @"YES" : @"NO");
        [self updateUI];
    }
}


#pragma mark - Worker thread

- (void)startWorker
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        FSMutableArray *currentService;
        NSObject<FSData> *currentData;
        
        while (currentData.aCurrentStep <= currentData.aMaxSteps && [_activeServiesQueue objectForKey:[_activeServiesQueue keyAtIndex:0]] != nil)
        {
            sleep(1);
            
            currentService = [_activeServiesQueue objectForKey:[_activeServiesQueue keyAtIndex:0]];
            currentData = [currentService objectAtIndex:activeObject];
            
            @synchronized (self.toBeDisplayed)
            {
                if (currentData != nil)
                {
                    [self.toBeDisplayed addObject:currentData];
                    DLog(@"ADDING: %@", currentData.aTitle);
                }
            }
            
            if (currentData.aCurrentStep < currentData.aMaxSteps)
                activeObject++;
            
            else if (currentData && currentData.aCurrentStep == currentData.aMaxSteps)
            {
                [_activeServiesQueue removeObjectForKey:currentData.aServiceID];
                activeObject = 0;
            }
        }
         DLog(@"DEAD WORKER: %@", [NSThread currentThread]);
    });
}

#pragma mark - UI update methods

- (void)updateUI
{
    isRunning = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        while ([self.toBeDisplayed count] != 0 && !paused)
        {
            NSObject<FSData> *data = [self.toBeDisplayed objectAtIndex:0];
            
            @synchronized (self.toBeDisplayed) {
                if ([self.toBeDisplayed objectAtIndex:0] != nil)
                    [self.toBeDisplayed removeObjectAtIndex:0];
            }
            
            if (!paused)
            {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    DLog(@"New title: %@", data.aTitle);
                    
                    if (![self isVisible])
                    {
                        [UIView animateWithDuration:0.2f
                                         animations:^{self.alpha = 1.0f;}
                                         completion:nil];
                    }
                    
                    // SUCCESS
                    if ([self isVisible] && data && !data.isFailure)
                    {
                        if (data.anImageString == nil || data.anImageString.length == 0)
                        {
                            _serviceIcon.hidden = YES;
                            CGRect frame = _statusLabel.frame;
                            frame.origin.x = padding;
                            _statusLabel.frame = frame;
                            
                        }
                        else
                        {
                            _serviceIcon.hidden = NO;
                            if (![_serviceIcon.image isEqual:[UIImage imageNamed:data.anImageString]])
                            {
                                [self updateAndAnimateIcon:data.anImageString];
                            }
                            
                            _statusLabel.frame = origStatusFrame;
                            [_statusLabel removeGestureRecognizer:tapGesture];
                        }
                        
                        if (data.aCurrentStep == data.aMaxSteps)
                        {
                            _closeButton.hidden = NO;
                        }
                        else
                        {
                            _closeButton.hidden = YES;
                        }

                        if (data.useHaptic)
                        {
                            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                        }
                        if (data.useSound)
                        {
                            AudioServicesPlaySystemSound(1109);
                        }
                        
                        [self updateProgressBarWithStep:data.aCurrentStep andMaxSteps:data.aMaxSteps];
                        [self updateAndAnimateTitle:data.aTitle];
                    }
                    // IS FAILURE
                    else if (data.isFailure)
                    {
                        paused = YES;
                     
                        if (data.anImageString == nil || data.anImageString.length == 0)
                        {
                            _serviceIcon.hidden = YES;
                            CGRect frame = _statusLabel.frame;
                            frame.origin.x = padding;
                            _statusLabel.frame = frame;
                        }
                        else
                        {
                            _statusLabel.frame = origStatusFrame;
                            _serviceIcon.hidden = NO;
                            [self updateAndAnimateIcon:data.anImageString];
                        }
                        
                        _closeButton.hidden = NO;
                        
                        if (data.useHaptic)
                        {
                            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                        }
                        if (data.useSound)
                        {
                            AudioServicesPlaySystemSound(1109);
                        }
                        
                        [self updateProgressBarWithStep:0 andMaxSteps:0];
                        [self updateAndAnimateTitle:data.aTitle];
                        
                        _failureLabel.text = data.aDescription;

                        CGRect frame = _statusLabel.frame;
                        frame.origin.y = frame.origin.y - 5;
                        
                        [UIView animateWithDuration:0.2f
                                         animations:^{
                                            _statusLabel.frame = frame;
                                             self.backgroundColor = [UIColor colorWithRed:0.57f green:0.15f blue:0.15f alpha:0.95f];}
                                         completion:^(BOOL finished){
                                             [_statusLabel addGestureRecognizer:tapGesture];
                                             [UIView animateWithDuration:0.2f
                                                                   delay:0.f
                                                                 options:UIViewAnimationOptionCurveEaseIn
                                                              animations:^{
                                                 readMoreLabel.alpha = 1.0f;}
                                                              completion:nil];
                        }];
                    }
                });
            }
            sleep(kSERVICE_DISPLAY_TIME);
        }
        
        if ([_activeServiesQueue count] == 0 && !paused)
        {
            [self performSelectorOnMainThread:@selector(removeFS) withObject:nil waitUntilDone:NO];
        }
        
        DLog(@"DEAD UI: %@", [NSThread currentThread]);
        isRunning = NO;
    });
}

- (void)updateProgressBarWithStep:(int)step andMaxSteps:(int)maxStep
{
    if (step == 0 && maxStep == 0)
    {
        progressBarView.hidden = YES;
    }
    else
    {
        if (step == 1)
        {
            _progressBar.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, kPROGRESS_BAR_HEIGHT);
        }
        
        progressBarView.hidden = NO;
        
        double newStep = 1 - ((float)step / (float)maxStep);
        int calculatedWidth = (int)([UIScreen mainScreen].bounds.size.width * newStep);
        
        CGRect oldFrame = _progressBar.frame;
        CGRect newFrame = CGRectMake([UIScreen mainScreen].bounds.size.width - calculatedWidth
                                     , oldFrame.origin.y,
                                     [UIScreen mainScreen].bounds.size.width,
                                     3);
        
        [UIView animateWithDuration:0.75f
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             _progressBar.frame = newFrame;
                         } completion:nil];
    }
}

- (void)updateAndAnimateTitle:(NSString *)titleString
{
    [UIView animateWithDuration:0.2f
                          delay:0.f
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        [_statusLabel setAlpha:0.f];}
                     completion:^(BOOL finished){
        _statusLabel.text = titleString;
                         [UIView animateWithDuration:0.2f
                                               delay:0.f
                                             options:UIViewAnimationOptionCurveEaseInOut
                                          animations:^{
                          [_statusLabel setAlpha:1.f];}
                                          completion:nil];
    }];
}

- (void)updateAndAnimateIcon:(NSString *)iconString
{
    [UIView animateWithDuration:0.2f
                          delay:0.f
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         [_serviceIcon setAlpha:0.f];}
                     completion:^(BOOL finished){
                         _serviceIcon.image = [UIImage imageNamed:iconString];
                         [UIView animateWithDuration:0.2f
                                               delay:0.f
                                             options:UIViewAnimationOptionCurveEaseInOut
                                          animations:^{
                                              [_serviceIcon setAlpha:1.f];
                                          } completion:nil];
    }];
}

#pragma mark - Button actions

- (void)tappedCloseButton
{
    readMoreLabel.alpha = 0;
    //[_activeServiesQueue removeAllObjects];
    dispatch_suspend(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    //dispatch_suspend(dispatch_get_main_queue());
    [self removeFS];
}

- (void)showFailureDescription
{
    DLog(@"PAUSED: %@", paused ? @"YES" : @"NO");

    CGRect failureFrame = CGRectMake(0,
                                     [UIScreen mainScreen].bounds.size.height - kSERVICE_INDICATOR_HEIGHT_FAILURE,
                                     [UIScreen mainScreen].bounds.size.width,
                                     kSERVICE_INDICATOR_HEIGHT_FAILURE);

    [UIView animateWithDuration:0.2f
                     animations:^{
                         readMoreLabel.alpha = 0;
                         _statusLabel.frame = origStatusFrame;
                         self.frame = failureFrame;
                         _failureLabel.hidden = NO;}
                     completion:nil];
}

#pragma mark - Helper methods

- (BOOL)isVisible
{
    return self.alpha == 1 ? YES : NO;
}

- (void)removeFS
{
    DLog(@"Removing FS from view");
    if ([self isVisible])
    {
        [UIView animateWithDuration:0.2f
                         animations:^{self.alpha = 0.0f;}
                         completion:^(BOOL finished){
                             self.frame = origFrame;
                             _statusLabel.text = @"";
                             _statusLabel.frame = origStatusFrame;
                             self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.9f];
                             paused = NO;
                         }];
    }
}

- (void)removeFromView
{
    [self tappedCloseButton];
}

@end
