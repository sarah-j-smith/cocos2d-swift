//
//  CCStateMachine.h
//  StateMachineDemo
//
//  Created by Sarah Smith on 28/01/2015.
//  Copyright (c) 2015 Apportable. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const CCStateMachineErrorDomain;

@class CCStateMachineBuilder;

typedef enum : NSUInteger {
    StateMachineNoError,
    UnknownStateName,
    UnknownEventName,
    IllegalTransition,
    ObjectBoundDeleted,
    EventWhilePaused
} StateMachineErrors;

@interface CCStateMachine : NSObject

@property (nonatomic, strong) NSString *currentState;
@property (nonatomic, strong) NSString *machineName;
@property (nonatomic, readonly) NSError *lastError;
@property (nonatomic, readonly) NSString *startState;

/** Creates and returns a State Machine with the given states. */
+ (CCStateMachine *)stateMachineWithBuilder:(CCStateMachineBuilder *)builder;

/** Initialises a State Machine with the given states.  Designated initializer. */
- (instancetype)initWithBuilder:(CCStateMachineBuilder *)builder;

/** Trigger the given transition on the State Machine.  Returns true if the transition was successful, false otherwise.  If there was an error, the lastError property will be set. */
- (BOOL)trigger:(NSString *)eventName;

/** Activate the state machine.  It will enter its start state. */
- (void)run;

/** Pause the state machine.  It will not respond to events, including timers. */
- (void)pause;

@end
