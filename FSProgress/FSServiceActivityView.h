//
//  FSServiceActivityView.h
//  FSProgress
//
//  Created by Sebastian Buks on 09/07/14.
//  Copyright (c) 2014 Mobiento AB. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FSData.h"

/**
 * FSServiceActivityView singelton represents the feedback service and its view. It receives and updates information in background threads.
 * It is responsible for both logic and drawing of said element as long as the input conforms to FSData protocol. If not, it silently dismisses the input data.
 * The programmer who integrates this module is responsible for dismissing/removing the view either by passing currentStep = maxSteps, or manually by invoking removeFromView.
 */

@interface FSServiceActivityView : UIView

// Initiates and returns a singleton FSServiceActivityView
+ (id)sharedInstance;

// Sets the root UIViewController font and placement of the view
- (void)setRootViewController:(UIViewController *)rootViewController andFont:(UIFont *)font;

// Receives new data to be parsed, queued and displayed by the FSServiceActivity
- (void)queueData:(id<FSData>)data;

// Hides the view and clears the current queue.
- (void)removeFromView;

@end
