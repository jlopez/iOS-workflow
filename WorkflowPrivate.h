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
@property (nonatomic, retain) NSArray *errors;
@property (nonatomic, readonly) void (^completionBlock)();

+ (void)disassociateToken:(WFToken *)token;

- (id)initWithStep:(WFStep *)step;
- (void)execute;

@end
