//
//  FSMutableArray.h
//  FSProgress
//
//  Created by Sebastian Buks on 17/07/14.
//  Copyright (c) 2014 Mobiento AB. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * A composite class behaving as an NSMutableArray, that allows an object to be informed whenever
 * a modification is made to it.
 */
@class FSMutableArray;

@protocol FSMutableArrayDelegate <NSObject>
@optional

// Informs the delegate that an object was added to the array
- (void)object:(id)object wasAddedToArray:(FSMutableArray *)array;

// Informs the delegate that an object was removed from the array
- (void)objectWasRemovedFromArray:(FSMutableArray *)array;

// Informs the delegate that the array was modified - either by adding, removing or replacing an object
- (void)arrayWasMutated:(FSMutableArray*)array;

// Inform the delegate that the array is empty
- (void)arrayIsEmpty:(FSMutableArray *)array;

@end

@interface FSMutableArray : NSMutableArray

// The object acting as the FCMutableArray delegate
@property (weak, nonatomic) id<FSMutableArrayDelegate> delegate;

/**
 * Returns an FSMutableArray
 * @param delegate The object acting as the FSMutableArray delegate
 */
- (FSMutableArray*)initWithDelegate:(id<FSMutableArrayDelegate>)delegate;

/**
 * Returns an FSMutableArray
 * @param delegate The object acting as the FSMutableArray delegate
 */
- (void)setDelegate:(id<FSMutableArrayDelegate>)delegate;

- (void)addObject:(id)anObject;
- (void)removeObject:(id)anObject;
- (void)insertObject:(id)anObject atIndex:(NSUInteger)index;
- (void)removeObjectAtIndex:(NSUInteger)index;
- (void)removeLastObject;
- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject;
- (id)objectAtIndex:(NSUInteger)index;
- (NSUInteger)count;
- (id)initWithArray:(NSArray *)array;

@end
