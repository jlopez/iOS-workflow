//
//  WFStepMetadata.m
//  Workflow
//
//  Created by jlopez on 7/14/10.
//  Copyright 2010 JLA. All rights reserved.
//
#import "WFStepMetadata.h"

#import "WFSyncToken.h"
#import "WFAsyncToken.h"

@implementation WFStepMetadata

@synthesize name;
@synthesize statusSelector;
@synthesize runSelector;
@synthesize tokenClass;
@synthesize progressWeight;


+ (id)metadataForClass:(Class)cls name:(NSString *)stepName {
  return [[[self alloc] initForClass:cls name:stepName] autorelease];
}


- (id)initForClass:(Class)cls name:(NSString *)stepName {
  if (self = [super init]) {
    name = [stepName copy];
    statusSelector = NSSelectorFromString([NSString stringWithFormat:@"mayRun%@Step", name]);
    NSString *syncName = [NSString stringWithFormat:@"perform%@Step:", name];
    NSString *asyncName = [NSString stringWithFormat:@"perform%@StepAsynchronously:", name];
    SEL syncSelector = NSSelectorFromString(syncName);
    SEL asyncSelector = NSSelectorFromString(asyncName);
    BOOL hasSyncSelector = [cls instancesRespondToSelector:syncSelector];
    BOOL hasAsyncSelector = [cls instancesRespondToSelector:asyncSelector];
    NSAssert3(hasSyncSelector || hasAsyncSelector, @"Class %@ should implement one of %@ or %@", cls, syncName, asyncName);
    NSAssert3(!hasSyncSelector || !hasAsyncSelector, @"Class %@ should implement only one of %@ and %@", cls, syncName, asyncName);
    runSelector = hasSyncSelector ? syncSelector : asyncSelector;
    tokenClass = hasSyncSelector ? [WFSyncToken class] : [WFAsyncToken class];

    SEL weightSelector = NSSelectorFromString([NSString stringWithFormat:@"progressWeightFor%@Step", name]);
    NSAssert(![cls instancesRespondToSelector:weightSelector], @"[%@ %@] declared as instance method", cls, NSStringFromSelector(weightSelector));
    progressWeight = 1;
    if ([cls respondsToSelector:weightSelector]) {
      NSMethodSignature *signature = [cls methodSignatureForSelector:weightSelector];
      NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
      [invocation setTarget:cls];
      [invocation setSelector:weightSelector];
      [invocation invoke];
      [invocation getReturnValue:&progressWeight];
    }
  }
  return self;
}


- (void)normalizeWeightUsingFactor:(float)factor {
  progressWeight /= factor;
}


- (void)dealloc {
  [name release];
  [super dealloc];
}


@end
