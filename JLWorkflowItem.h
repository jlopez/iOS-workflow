//
//  JLWorkflowItem.h
//  Workflow
//
//  Created by jlopez on 7/13/10.
//  Copyright 2010 JLA. All rights reserved.
//

@class JLWorkflowToken;
@class JLWorkflowSyncToken;
@class JLWorkflowAsyncToken;
@class JLWorkflowStepMetadata;
@class JLWorkflowStep;

enum {
  JLWorkflowStepStatusUnmetDependency = 0,
  JLWorkflowStepStatusCanRun,
  JLWorkflowStepStatusCompleted
};
typedef NSUInteger JLWorkflowStepStatus;

@interface JLWorkflowItem : NSObject<NSCoding> {
@private
  NSArray *metadata;
  NSArray *steps;
  BOOL enabled;
}

@property (nonatomic, readonly) float overallProgress;
@property (nonatomic, readonly) int totalSteps; // Dynamically generated based on subclass impl
@property (nonatomic, readonly) BOOL enabled; // YES if item will schedule missing steps when poked
@property (nonatomic, readonly) BOOL running; // YES if any step is currently executing
@property (nonatomic, readonly) BOOL completed; // YES if all steps were completed successfully
@property (nonatomic, readonly) BOOL failed; // YES if any step has an error
@property (nonatomic, readonly) NSArray *errors; // Array with all step errors

- (void)start;   // If running || completed || error, does nothing
- (void)stop;    // If !running || completed, does nothing
- (void)reset;   // Must !running. Clears step errors.

// Internal API
// Called on subclass

// Step status
// - (JLWorkflowStepStatus)statusFor<NAME>Step;

// Synchronous execution of step N
// Will be invoked on background thread.
// May report progress by calling reportStepProgress:
// Each step must modify instance variables upon step completion.
// If a step requires multiple batches of variables to be updated,
// the step should be broken up into multiple steps.
// Instance variables should only be modified if isStopping returns NO
// Return array of errors
// - (NSArray *)perform<N>Step:(JLWorkflowSyncToken *)token;

// Asynchronous execution of step N
// Should complete quickly, but may be invoked on background thread.
// May report progress by calling reportStepProgress:
// Upon step completion, instance variables should be modified if isStopping returns NO
// The handler should then be invoked.
// - (void)perform<N>StepAsynchronously:(JLWorkflowAsyncToken *)token;

// Optional - Specify progress weights
// - (float)progressWeightFor<N>Step;

// May be called on superclass
// Requests step dependencies to be rechecked
// If item is not running this does nothing
- (void)poke;

// Suggestions for subclasses: may be implemented by subclasses
// - (void)reset;   // Will reset to step 0, running = NO, completed = NO

@end

@interface JLWorkflowToken : NSObject {
@protected
  JLWorkflowStep *step;
  NSArray *errors;
}

@property (nonatomic, readonly, getter = isValid) BOOL valid;
@property (nonatomic, assign) float progress;

+ (id)associatedTokenForObject:(id)obj;

- (void)associateWithObject:(id)obj;

// private
@property (nonatomic, readonly) JLWorkflowStep *step;
@property (nonatomic, retain) NSArray *errors;

- (id)initWithStep:(JLWorkflowStep *)step;
- (void)execute;

@end

@interface JLWorkflowSyncToken : JLWorkflowToken {
}

@end

@interface JLWorkflowAsyncToken : JLWorkflowToken {
@private
  BOOL completed;
}

- (void)completeAsynchronousStep;
- (void)completeAsynchronousStepWithError:(NSError *)errors;
- (void)completeAsynchronousStepWithErrors:(NSArray *)errors;

@end

@interface JLWorkflowStepMetadata : NSObject {
  NSString *name;
  SEL statusSelector;
  SEL syncSelector;
  SEL asyncSelector;
  float progressWeight;
}

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) SEL statusSelector;
@property (nonatomic, readonly) SEL syncSelector;
@property (nonatomic, readonly) SEL asyncSelector;
@property (nonatomic, readonly) float progressWeight;

// Private
+ (id)metadataForClass:(Class)cls name:(NSString *)stepName;
- (id)initForClass:(Class)cls name:(NSString *)stepName;
- (void)normalizeWeightUsingFactor:(float)factor;

@end

@interface JLWorkflowStep : NSObject {
@private
  JLWorkflowItem *item;
  JLWorkflowStepMetadata *metadata;
  NSInvocation *statusInvocation;
  JLWorkflowToken *runningToken;
  float progress;
  NSArray *errors;
}

@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, assign) float progress;
@property (nonatomic, readonly) float weightedProgress;
@property (nonatomic, retain) NSArray *errors;
@property (nonatomic, readonly, getter=isFailed) BOOL failed;

+ (id)stepForItem:(JLWorkflowItem *)item metadata:(JLWorkflowStepMetadata *)metadata;

- (id)initForItem:(JLWorkflowItem *)item metadata:(JLWorkflowStepMetadata *)metadata;
- (void)reset;
- (void)cancel;
- (void)performInBackground;

- (BOOL)isTokenValid:(JLWorkflowToken *)token;

- (JLWorkflowStepStatus)status;
- (NSArray *)performSyncStepWithToken:(JLWorkflowSyncToken *)token;
- (void)performAsyncStepWithToken:(JLWorkflowAsyncToken *)token;
- (void)notifyTokenCompletion:(JLWorkflowToken *)token;

@end

@interface JLWorkflowAsyncThread : NSThread {
@private
  BOOL running;
}
@end