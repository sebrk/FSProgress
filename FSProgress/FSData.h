//
//  FSData.h
//  FSProgress
//
//  Created by Sebastian Buks on 09/07/14.
//  Copyright (c) 2014 Mobiento AB. All rights reserved.
//

/**
* FSData is the protocol which input data to the FSServiceActivity is required to implement.
*/

#import <Foundation/Foundation.h>

@protocol FSData <NSObject>

@required
@property (nonatomic, assign) int aCurrentStep;
@property (nonatomic, strong) NSNumber *aServiceID;
@property (nonatomic, strong) NSString *aTitle;
@property (nonatomic, assign) int aMaxSteps;
@property (nonatomic, strong) NSString *aDescription;
@property (nonatomic, strong) NSString *anImageString;
@property (nonatomic, assign) BOOL isFailure;
@property (nonatomic, assign) BOOL useHaptic;
@property (nonatomic, assign) BOOL useSound;

@optional
- (id)initWithID:(NSNumber *)serviceID andTitle:(NSString *)title currentStep:(int)currentStep andMaxSteps:(int)maxSteps andDescription:(NSString *)description andIcon:(NSString *)imageString;

- (NSString *)description;

@end
