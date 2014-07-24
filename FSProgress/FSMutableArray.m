//
//  FSMutableArray.m
//  FSProgress
//
//  Created by Sebastian Buks on 17/07/14.
//  Copyright (c) 2014 Mobiento AB. All rights reserved.
//

#import "FSMutableArray.h"

@interface FSMutableArray () {
    __weak id <FSMutableArrayDelegate> _delegate;
    NSMutableArray *_mutableArray;
}

@property (strong, nonatomic) NSMutableArray *mutableArray;

@end

@implementation FSMutableArray


- (FSMutableArray*)initWithDelegate:(id<FSMutableArrayDelegate>)delegate
{
	self = [super init];
    if(self)
    {
        _delegate = delegate;
     	_mutableArray = [[NSMutableArray alloc] initWithCapacity:0];
    }
    return self;
}

- (void)setDelegate:(id<FSMutableArrayDelegate>)delegate
{
    _delegate = delegate;
}

- (id)init{
	return [self initWithCapacity:0];
}

- (id)initWithCapacity:(NSUInteger)capacity
{
	self = [super init];
	if (self != nil)
	{
		_mutableArray = [[NSMutableArray alloc] initWithCapacity:capacity];
	}
	return self;
}

- (id)initWithArray:(NSArray *)array
{
	self = [super init];
	if (self != nil)
    {
		_mutableArray = [array mutableCopy];
	}
	return self;
}

- (void)informDelegateOfAdditionOfObject:(id)object
{
    if(self.delegate && [self.mutableArray count] == 1)
    {
		if([self.delegate respondsToSelector:@selector(object:wasAddedToArray:)])
        {
			[self.delegate object:object wasAddedToArray:self];
		}
		if([self.delegate respondsToSelector:@selector(arrayWasMutated:)])
        {
			[self.delegate arrayWasMutated:self];
		}
    }
}

- (void)informDelegateOfDeletion
{
    if(self.delegate)
    {
		if([self.delegate respondsToSelector:@selector(objectWasRemovedFromArray:)])
        {
			[self.delegate objectWasRemovedFromArray:self];
		}
		if([self.delegate respondsToSelector:@selector(arrayWasMutated:)])
        {
			[self.delegate arrayWasMutated:self];
		}
    }
}

- (void)addObject:(id)anObject
{
    [self.mutableArray addObject:anObject];
    [self informDelegateOfAdditionOfObject:anObject];
}

- (void)insertObject:(id)anObject atIndex:(NSUInteger)index
{
    if(index > self.mutableArray.count)
    {
        [self.mutableArray addObject:anObject];
    }
    else
    {
        [self.mutableArray insertObject:anObject atIndex:index];
    }
    [self informDelegateOfAdditionOfObject:anObject];
}

- (void)removeObject:(id)anObject
{
    [self.mutableArray removeObject:anObject];
    [self informDelegateOfDeletion];
}

- (void)removeObjectAtIndex:(NSUInteger)index
{
    [self.mutableArray removeObjectAtIndex:index];
    [self informDelegateOfDeletion];
}

- (void)removeLastObject
{
    [self.mutableArray removeLastObject];
    [self informDelegateOfDeletion];
}

- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject
{
    [self.mutableArray replaceObjectAtIndex:index withObject:anObject];
    [self informDelegateOfDeletion];
    [self informDelegateOfAdditionOfObject:anObject];
}

- (void)arrayIsEmpty:(FSMutableArray *)array
{
    if(self.delegate)
    {
		if([self.delegate respondsToSelector:@selector(arrayIsEmpty:)])
        {
			[self.delegate arrayIsEmpty:self];
		}
    }
}

- (id)objectAtIndex:(NSUInteger)index
{
	if(self.mutableArray.count > index)
    {
		return [self.mutableArray objectAtIndex:index];
	}
	return nil;
}

- (NSUInteger)count
{
    return self.mutableArray.count;
}

@end
