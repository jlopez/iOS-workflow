//
//  WFObject.h
//  Workflow
//
//  Created by jlopez on 7/13/10.
//  Copyright 2010 JLA. All rights reserved.
//

@interface WFObject : NSObject<NSCoding> {
@private
  NSArray *metadata;
  NSArray *steps;
  BOOL enabled;
}

@property (nonatomic, readonly) float overallProgress;
@property (nonatomic, readonly) int totalSteps; // Dynamically generated based on subclass impl
@property (nonatomic, readonly, getter=isEnabled) BOOL enabled; // YES if item will schedule missing steps when poked
@property (nonatomic, readonly, getter=isRunning) BOOL running; // YES if any step is currently executing
@property (nonatomic, readonly, getter=isCompleted) BOOL completed; // YES if all steps were completed successfully
@property (nonatomic, readonly, getter=isFailed) BOOL failed; // YES if any step has an error
@property (nonatomic, readonly) NSArray *errors; // Array with all step errors

- (void)start;   // If running || completed || error, does nothing
- (void)stop;    // If !running || completed, does nothing
- (void)reset;   // Must !running. Clears step errors.

// Internal API
// Called on subclass

// Are all dependencies met for step NAME?
// - (BOOL)mayRun<NAME>Step;

// Synchronous execution of step N
// Will be invoked on background thread.
// May report progress by calling reportStepProgress:
// Each step must modify instance variables upon step completion.
// If a step requires multiple batches of variables to be updated,
// the step should be broken up into multiple steps.
// Instance variables should only be modified if isStopping returns NO
// Return array of errors
// - (void)perform<N>Step:(JLWorkflowToken *)token;

// Asynchronous execution of step N
// Should complete quickly, but may be invoked on background thread.
// May report progress by calling reportStepProgress:
// Upon step completion, instance variables should be modified if isStopping returns NO
// The handler should then be invoked.
// - (void)perform<N>StepAsynchronously:(JLWorkflowToken *)token;

// Optional - Specify progress weights
// - (float)progressWeightFor<N>Step;

// May be called on superclass
// Requests step dependencies to be rechecked
// If item is not running this does nothing
- (void)poke;

// Suggestions for subclasses: may be implemented by subclasses
// - (void)reset;   // Will reset to step 0, running = NO, completed = NO

@end
