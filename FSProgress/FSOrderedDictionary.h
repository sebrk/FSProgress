//
//  FSOrderedDictionary.h
//  FSProgress
//
//  Created by Sebastian Buks on 16/07/14.
//  Copyright (c) 2014 Mobiento AB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FSMutableArray.h"

/**
 * An ordered subclass of NSMutableDictionary, much like a HashMap structure but without the hashing
 */

@interface FSOrderedDictionary : NSMutableDictionary
{
	NSMutableDictionary *dictionary;
	FSMutableArray *array;
}

@property (nonatomic, strong) FSMutableArray *array;

- (void)insertObject:(id)anObject forKey:(id)aKey atIndex:(NSUInteger)anIndex;
- (id)keyAtIndex:(NSUInteger)anIndex;
- (id)popFirstObject;
- (NSEnumerator *)reverseKeyEnumerator;
- (void)removeAllObjects;

@end
