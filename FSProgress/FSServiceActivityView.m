//
//  FSServiceActivityView.m
//  FSProgress
//
//  Created by Sebastian Buks on 09/07/14.
//  Copyright (c) 2014 Mobiento AB. All rights reserved.
//

#define kSERVICE_INDICATOR_HEIGHT 40.0f
#define kSERVICE_INDICATOR_HEIGHT_ERROR 80.0f
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
    
    CGRect origStatusFrame;
    CGRect origFrame;
    float padding;
    
    int activeObject;
    NSNumber *activeService;
    
    BOOL UIRunning, workerRunning;
    BOOL paused;
}

@property (nonatomic, strong) UIViewController *rootViewController;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UILabel *readMoreLabel;
@property (nonatomic, strong) NSDictionary *serviceNotificationMessageKeys;
@property (nonatomic, strong) UIImageView *serviceIcon;
@property (nonatomic, strong) UIView *progressBar;
@property (nonatomic, strong) NSTimer *hideTimer;
@property (nonatomic, strong) UIButton *closeButton;
@property (atomic, strong) FSOrderedDictionary *activeServiesQueue;
@property (nonatomic, strong) FSMutableArray *toBeDisplayed;
@property (nonatomic, strong) NSTimer *monitorTimer;

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
    static dispatch_once_t setRootOnce;
    dispatch_once(&setRootOnce, ^{
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
            [self setupErrorLabel:font];
            
            self.alpha = 0;
        }
        
        _monitorTimer = [NSTimer scheduledTimerWithTimeInterval:15.0
                                                           target:self
                                                         selector:@selector(monitor)
                                                         userInfo:nil
                                                          repeats:YES];
        
        [rootViewController.view addSubview:self];
    });
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
                                    width - iconMaxX - 2 * padding,
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


- (void)setupErrorLabel:(UIFont *)font
{
    _readMoreLabel = [[UILabel alloc] init];
    _readMoreLabel.alpha = 0;
    _readMoreLabel.font = [UIFont boldSystemFontOfSize:font.pointSize - 4.0f];
    _readMoreLabel.textColor = [UIColor whiteColor];
    _readMoreLabel.backgroundColor = [UIColor clearColor];
    _readMoreLabel.textAlignment = NSTextAlignmentLeft;
    _readMoreLabel.text = NSLocalizedStringFromTableInBundle(@"toast_moreInfo", @"global", [NSBundle mainBundle], @"More info text");
    [self addSubview:_readMoreLabel];
    
    _errorLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding,
                                                            _statusLabel.frame.origin.y + padding,
                                                            CGRectGetWidth(self.frame) - 4 * padding,
                                                            kSERVICE_INDICATOR_HEIGHT_ERROR)];
    _errorLabel.font = [UIFont systemFontOfSize:font.pointSize - 4.0f];
    _errorLabel.textColor = [UIColor whiteColor];
    _errorLabel.backgroundColor = [UIColor clearColor];
    _errorLabel.textAlignment = NSTextAlignmentLeft;
    _errorLabel.adjustsFontSizeToFitWidth = YES;
    _errorLabel.numberOfLines = 3;
    _errorLabel.minimumScaleFactor = 1;
    [self addSubview:_errorLabel];
    _errorLabel.hidden = YES;
    
    tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showErrorDescription)];
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
                DLog(@"NO SERVICES, ADDING TO NEW QUEUE: %@", data.aTitle);
            }
            // If serviceID already exists in queue and is at position 0
            else if ([(NSObject<FSData>*)[[[_activeServiesQueue objectForKey:[_activeServiesQueue keyAtIndex:0]] objectAtIndex:0] aServiceID] isEqual:data.aServiceID])
            {
                FSMutableArray *existing = [_activeServiesQueue objectForKey:data.aServiceID];
                [existing addObject:data];
                DLog(@"SERVICE EXISTS AND IS RUNNING: %@", data.aTitle);
            }
            // If it exists but is not the active service (not queued in position 0), replace existing data.
            else if ([_activeServiesQueue objectForKey:data.aServiceID] != nil && ![(NSObject<FSData>*)[[[_activeServiesQueue objectForKey:[_activeServiesQueue keyAtIndex:0]] objectAtIndex:0] aServiceID] isEqual:data.aServiceID])
            {
                FSMutableArray *existingNotActive = [_activeServiesQueue objectForKey:data.aServiceID];
                [existingNotActive replaceObjectAtIndex:0 withObject:data];
                DLog(@"SERVICE EXISTS BUT IS __NOT__ SHOWING: %@", data.aTitle);
            }
            // If serviceID is not present, add a new queue
            else if ([_activeServiesQueue objectForKey:data.aServiceID] == nil)
            {
                FSMutableArray *new = [[FSMutableArray alloc] initWithObjects:data, nil];
                [_activeServiesQueue setObject:new forKey:data.aServiceID];
                DLog(@"NEW SERVICE, ADDING NEW QUEUE: %@", data.aTitle);
            }
        }
    }
}


#pragma mark - FSMutableArayDelegate methods

- (void)object:(id)object wasAddedToArray:(FSMutableArray *)array
{
    if ( [_activeServiesQueue count] == 1 && !workerRunning) {
        [self startWorker];
    }
    
    DLog(@"UI RUNNING: %@", UIRunning ? @"YES" : @"NO");
    
    if ([array isEqual:_toBeDisplayed] && !UIRunning && !paused)
    {
        [self updateUI];
    }
    
    if (![_monitorTimer isValid])
    {
        [_monitorTimer fire];
    }
}


#pragma mark - Worker thread

- (void)startWorker
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        DLog(@"STARTING WORKER: %@", [NSThread currentThread]);
        
        FSMutableArray *currentService;
        NSObject<FSData> *currentData;
        
        while (currentData.aCurrentStep <= currentData.aMaxSteps && [_activeServiesQueue objectForKey:[_activeServiesQueue keyAtIndex:0]] != nil)
        {
            workerRunning = YES;
            
            sleep(1);
            
            currentService = [_activeServiesQueue objectForKey:[_activeServiesQueue keyAtIndex:0]];
            currentData = [currentService objectAtIndex:activeObject];
            
            @synchronized (_toBeDisplayed)
            {
                if (currentData != nil)
                {
                    [_toBeDisplayed addObject:currentData];
                    DLog(@"ADDING TO DISPLAY QUEUE: %@", currentData.aTitle);
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
        workerRunning = NO;
        DLog(@"DEAD WORKER: %@", [NSThread currentThread]);
    });
}


#pragma mark - UI update methods

- (void)updateUI
{
    UIRunning = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        DLog(@"ACTIVATE UI: %@", [NSThread currentThread]);
        
        while ([_toBeDisplayed count] != 0 && !paused)
        {
            NSObject<FSData> *data = [_toBeDisplayed objectAtIndex:0];
            
            @synchronized (_toBeDisplayed) {
                if ([_toBeDisplayed objectAtIndex:0] != nil)
                    [_toBeDisplayed removeObjectAtIndex:0];
            }
            
            if (!paused)
            {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    DLog(@"SHOWING NEW TITLE: %@ ON THREAD: %@", data.aTitle, [NSThread currentThread]);
                    
                    if (![self isVisible])
                    {
                        [UIView animateWithDuration:0.2f
                                         animations:^{self.alpha = 1.0f;}
                                         completion:nil];
                    }
                    
                    [self updateStatusFrame:data];
                    
                    if (data.useHaptic)
                    {
                        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                    }
                    if (data.useSound)
                    {
                        AudioServicesPlaySystemSound(1109);
                    }

                    [self updateAndAnimateTitle:data.aTitle];
                    
                    // SUCCESS
                    if ([self isVisible] && data && !data.isError)
                    {
                        [_statusLabel removeGestureRecognizer:tapGesture];
                    
                        if (data.aCurrentStep == data.aMaxSteps)
                        {
                            _closeButton.hidden = NO;
                        }
                        else
                        {
                            _closeButton.hidden = YES;
                        }
                        
                        [self updateProgressBarWithStep:data.aCurrentStep andMaxSteps:data.aMaxSteps];
                    }
                    // IS ERROR
                    else if (data.isError)
                    {
                        paused = YES;
                        
                        _closeButton.hidden = NO;
                        
                        [self updateProgressBarWithStep:0 andMaxSteps:0];
                        
                        _errorLabel.text = data.anErrorDescription;
                        
                        CGRect frame = _statusLabel.frame;
                        frame.origin.y = frame.origin.y - 5;
                        
                        [UIView animateWithDuration:0.2f
                                         animations:^{
                                             _statusLabel.frame = frame;
                                             self.backgroundColor = [UIColor colorWithRed:0.57f green:0.15f blue:0.15f alpha:0.95f];}
                                         completion:^(BOOL finished){
                                             if (data.anErrorDescription != nil || data.anErrorDescription.length != 0)
                                             {
                                                 [_statusLabel addGestureRecognizer:tapGesture];
                                             }
                                             
                                             _readMoreLabel.frame = CGRectMake(_statusLabel.frame.origin.x,
                                                                              _statusLabel.frame.origin.y + 1.5 * padding,
                                                                              CGRectGetWidth(self.frame) - 2 * padding,
                                                                              kSERVICE_INDICATOR_HEIGHT);
                                             
                                             [UIView animateWithDuration:0.2f
                                                                   delay:0.f
                                                                 options:UIViewAnimationOptionCurveEaseIn
                                                              animations:^{
                                                                  _readMoreLabel.alpha = 1.0f;}
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
        UIRunning = NO;
    });
}


- (void)updateProgressBarWithStep:(int)step andMaxSteps:(int)maxStep
{
    if (step == 0 && maxStep == 0)
    {
        progressBarView.hidden = YES;
        _progressBar.frame = CGRectMake([UIScreen mainScreen].bounds.size.width, 0, [UIScreen mainScreen].bounds.size.width, kPROGRESS_BAR_HEIGHT);
    }
    else
    {
        progressBarView.hidden = NO;
        
        // Reset the progressBar
        if (_progressBar.frame.origin.x == [UIScreen mainScreen].bounds.size.width && step != maxStep)
        {
            _progressBar.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, kPROGRESS_BAR_HEIGHT);
        }
        
        CGRect newFrame;
        
        double newStep = 1 - ((float)step / (float)maxStep);
        int calculatedWidth = (int)([UIScreen mainScreen].bounds.size.width * newStep);
        
        CGRect oldFrame = _progressBar.frame;
        newFrame = CGRectMake([UIScreen mainScreen].bounds.size.width - calculatedWidth
                              , oldFrame.origin.y,
                              [UIScreen mainScreen].bounds.size.width,
                              3);
        
        [UIView animateWithDuration:0.75f
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             _progressBar.frame = newFrame;
                         } completion:^(BOOL finished){
                             if (step == maxStep && maxStep != 0)
                             {
                                 _progressBar.frame = CGRectMake([UIScreen mainScreen].bounds.size.width, 0, [UIScreen mainScreen].bounds.size.width, kPROGRESS_BAR_HEIGHT);
                             }
                         }];
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

- (void)showErrorDescription
{
    CGRect errorFrame = CGRectMake(0,
                                   [UIScreen mainScreen].bounds.size.height - kSERVICE_INDICATOR_HEIGHT_ERROR,
                                   [UIScreen mainScreen].bounds.size.width,
                                   kSERVICE_INDICATOR_HEIGHT_ERROR);
    
    [UIView animateWithDuration:0.2f
                     animations:^{
                         _readMoreLabel.alpha = 0;
                         self.frame = errorFrame;
                         _errorLabel.hidden = NO;}
                     completion:nil];
}


#pragma mark - Helper methods

- (void)updateStatusFrame:(NSObject<FSData> *)data
{
    //SUCCESS
    if (!data.isError)
    {
        if (data.anImageString == nil || data.anImageString.length == 0)
        {
            _serviceIcon.hidden = YES;
            CGRect frame = origStatusFrame;
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
        }
    }
    
    //FAILURE
    if (data.isError)
    {
        if (data.anImageString == nil || data.anImageString.length == 0)
        {
            _serviceIcon.hidden = YES;
            CGRect frame = origStatusFrame;
            frame.origin.x = padding;
            frame.origin.y = -padding/5;
            _statusLabel.frame = frame;
        }
        else
        {
            _serviceIcon.hidden = NO;
            CGRect frame = origStatusFrame;
            frame.origin.y = -padding/5;
            _statusLabel.frame = frame;
            if (![_serviceIcon.image isEqual:[UIImage imageNamed:data.anImageString]])
            {
                [self updateAndAnimateIcon:data.anImageString];
            }
        }
    }
}


- (BOOL)isVisible
{
    return self.alpha == 1 ? YES : NO;
}


- (void)tappedCloseButton
{
    dispatch_suspend(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    [self removeFS];
    paused = NO;
    [self updateUI];
}


- (void)removeFS
{
    if ([self isVisible])
    {
        DLog(@"REMOVING FROM VIEW");
        [UIView animateWithDuration:0.2f
                         animations:^{self.alpha = 0.0f;}
                         completion:^(BOOL finished){
                             self.frame = origFrame;
                             _statusLabel.text = @"";
                             self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.9f];
                             paused = NO;
                             _readMoreLabel.alpha = 0;
                         }];
    }
}


- (void)monitor
{
    if (!UIRunning)
    {
        [self updateUI];
    }
}


- (void)removeFromView
{
    [self tappedCloseButton];
    
    @synchronized (_activeServiesQueue)
    {
        [_activeServiesQueue removeAllObjects];
        [_toBeDisplayed removeAllObjects];
        DLog(@"CLEARED ALL QUEUES, REMOVING FROM VIEW");
    }
}

- (void)stopService
{
    @synchronized (_activeServiesQueue)
    {
        [_activeServiesQueue removeAllObjects];
        [_toBeDisplayed removeAllObjects];
        DLog(@"CLEARED ALL QUEUES, REMOVING FROM VIEW");
    }
    
    [_monitorTimer invalidate];
}

@end