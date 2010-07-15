//
//  WorkflowPrivate.h
//  Workflow
//
//  Created by jlopez on 7/14/10.
//  Copyright 2010 JLA. All rights reserved.
//

#import "WFToken.h"

#define debug(x) NSLog x

@class WFStep;

@interface WFToken (WFPrivate)

@property (nonatomic, readonly) WFStep *step;
@property (nonatomic, readonly, retain) NSArray *errors;
@property (nonatomic, readonly, getter=isCompleted) BOOL completed;

+ (void)disassociateToken:(WFToken *)token;

- (id)initWithStep:(WFStep *)step;
- (void)execute;
- (void)runCompletionBlock;

// Must be implemented by subclasses
- (void)scheduleExecution:(void (^)(void))block;
- (void)processExecutionResult:(NSNumber *)executionResult;

@end
