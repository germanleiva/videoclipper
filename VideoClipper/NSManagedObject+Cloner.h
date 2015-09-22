//
//  NSManagedObject+Cloner.h
//  VideoClipper
//
//  Created by German Leiva on 22/09/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface NSManagedObject (Cloner)

- (NSManagedObject *)clone;
- (NSManagedObject *)cloneInContext:(NSManagedObjectContext *)differentContext;

@end