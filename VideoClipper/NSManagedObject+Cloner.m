//
//  NSManagedObject+Cloner.m
//  VideoClipper
//
//  Created by German Leiva on 22/09/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

#import "NSManagedObject+Cloner.h"

@implementation NSManagedObject (Cloner)

// modify this variable to go deeper into relationships
#define kMaxDepth          4

- (NSManagedObject *)cloneInContext:(NSManagedObjectContext *)differentContext {
	return [self cloneWithCopyCache:[NSMutableDictionary dictionary]
					excludeEntities:@[]
					   currentDepth:0
						  inContext:differentContext];
}

- (NSManagedObject *)clone {
	return [self cloneWithCopyCache:[NSMutableDictionary dictionary]
					excludeEntities:@[]
					   currentDepth:0
						  inContext:self.managedObjectContext];
}

- (NSManagedObject *)cloneWithCopyCache:(NSDictionary *)copyCache {
	return [self cloneWithCopyCache: [NSMutableDictionary dictionaryWithDictionary:copyCache]
					excludeEntities:@[]
					   currentDepth:0
						  inContext:self.managedObjectContext];
}

// Returns a deep-copy of this object
- (NSManagedObject *)cloneWithCopyCache:(NSMutableDictionary *)alreadyCopiedObjects
						excludeEntities:(NSArray *)namesOfEntitiesToExclude
						   currentDepth:(NSInteger)depth
							  inContext:(NSManagedObjectContext *)moc
{
	if ([namesOfEntitiesToExclude containsObject:self.entity.name]) {
		//        NSLog(@"< back");
		return nil;
	}
	
	//    NSLog(@"\t\t\t---In %@---", self.entity.name);
	
	if (depth > kMaxDepth) {
		return nil;
	}
	
	NSEntityDescription *entity = self.entity;
	
	__block id selfCopy = nil;
	
	/**
	 Return the object if it is already in the cache; if we don't return it at this point, we will go into a cycle
	 */
	NSManagedObject *cloned = [alreadyCopiedObjects objectForKey:self.objectID];
	if (cloned != nil) {
		return cloned;
	} else {
		selfCopy = [[[self class] alloc] initWithEntity:entity insertIntoManagedObjectContext:moc];
		[alreadyCopiedObjects setObject:selfCopy forKey:self.objectID];
	}
	
	// attributes
	[self.entity.attributesByName.allKeys enumerateObjectsUsingBlock:
	 ^(NSString *attrKey, NSUInteger idx, BOOL *stop)
	 {
		 id valueForKey = [[self valueForKey:attrKey] copy];
		 [selfCopy setValue:valueForKey forKey:attrKey];
	 }];
	
	// relationships
	[self.entity.relationshipsByName.allKeys enumerateObjectsUsingBlock:
	 ^(NSString *relationshipName, NSUInteger idx, BOOL *stop)
	 {
		 NSRelationshipDescription *rel = [self.entity.relationshipsByName
										   objectForKey:relationshipName];
		 
		 if ([rel isToMany]) {
			 NSInteger nextDepth = depth + 1;
			 
			 //            NSLog(@"1-*:\t\t%@\t\t|\tdepth:%ld", rel.name, (long)_depth);
			 
			 // either ordered or unordered set
			 id allObjectsForToManyKey = [self valueForKey:relationshipName];
			 
			 id copyOfAllObjectsForToManyKey = nil;
			 if ([allObjectsForToManyKey isKindOfClass:[NSSet class]]) {
				 copyOfAllObjectsForToManyKey = [[NSMutableSet alloc] init];
			 } else if ([allObjectsForToManyKey isKindOfClass:[NSOrderedSet class]]) {
				 copyOfAllObjectsForToManyKey = [[NSMutableOrderedSet alloc] init];
			 }
			 
			 // one to many relationship - go through each object within
			 for (NSManagedObject *objectInSet in allObjectsForToManyKey) {
				 NSManagedObject *objectInSetCopy =
				 [objectInSet cloneWithCopyCache:alreadyCopiedObjects
								 excludeEntities:namesOfEntitiesToExclude
									currentDepth:nextDepth
									   inContext:moc];
				 
				 // objectInSetCopy could be nil if we've reached maximum depth
				 if (objectInSetCopy &&
					 [copyOfAllObjectsForToManyKey
					  respondsToSelector:@selector(addObject:)])
				 {
					 [copyOfAllObjectsForToManyKey performSelector:@selector(addObject:)
														withObject:objectInSetCopy];
				 }
			 }
			 
			 [selfCopy setValue:copyOfAllObjectsForToManyKey forKey:relationshipName];
		 } else {
			 NSInteger nextDepth = depth + 1;
			 
			 //            NSLog(@"1-1:\t\t%@\t\t|\tdepth: %ld", rel.name, (long)_depth);
			 
			 NSManagedObject *objectForRelationship = [self valueForKey:relationshipName];
			 NSManagedObject *copyOfObjectForRelationship =
			 [objectForRelationship cloneWithCopyCache:alreadyCopiedObjects
									   excludeEntities:namesOfEntitiesToExclude
										  currentDepth:nextDepth
											 inContext:moc];
			 
			 [selfCopy setValue:copyOfObjectForRelationship forKey:relationshipName];
		 }
	 }];
	
	return selfCopy;
}

@end