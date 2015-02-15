//
//  StateMachineTests.m
//  StateMachineTests
//
//  Created by Sarah Smith on 29/01/2015.
//  Copyright (c) 2015 Apportable. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "CCStateMachineBuilder.h"
#import "CCStateMachine.h"
#import "CCStateTransition.h"
#import "CCStateBinding.h"

@interface MockLabel : NSObject

@property (nonatomic, assign) CGPoint position;
@property (nonatomic, strong) NSString *string;

@end

@implementation MockLabel

//

@end

@interface StateMachineTests : XCTestCase

@end

@implementation StateMachineTests
{
    MockLabel *_label;
    MockLabel *_stateLabel;
}

- (void)setUp
{
    [super setUp];
    
    _label = [[MockLabel alloc] init];
    _stateLabel = [[MockLabel alloc] init];
}

- (void)tearDown
{
    [super tearDown];
    
    _label = nil;
    _stateLabel = nil;
}

- (void)testCCStateMachine
{
    CCStateMachineBuilder *builder = [CCStateMachineBuilder stateMachineBuilderWithStates:@[ @"begin", @"attack", @"idle", @"flee", @"chase" ]];
    XCTAssertNotNil(builder, @"Factory construction successful");
    
    [builder setStartState:@"begin"];
    
    // Set up our State Machine's transitions
    [builder addTransitionFromState:@"begin" toState:@"idle" onEvent:@"enter"];
    [builder addTransitionFromState:@"idle" toState:@"chase" onEvent:@"enemyVisible"];
    [builder addTransitionFromState:@"chase" toState:@"attack" onEvent:@"enemyInRange"];
    [builder addTransitionFromState:@"chase" toState:@"flee" onEvent:@"hitPointsLow"];
    [builder addTransitionFromState:@"flee" toState:@"idle" onEvent:@"enemyNotVisible"];
    
    CCStateMachine *machine = [builder generateStateMachineWithName:@"Character State Machine"];
    XCTAssertNotNil(machine, @"Factory method successful");
    
    XCTAssertEqualObjects([machine machineName], @"Character State Machine", @"Machine name correctly initialised");
    XCTAssertEqual([[machine lastError] code], StateMachineNoError);
    XCTAssertEqualObjects([machine startState], @"begin");
    XCTAssertNil([machine currentState], @"Before run machine has no current state");
    
    [machine run];
    XCTAssertEqual([[machine lastError] code], StateMachineNoError);
    XCTAssertEqualObjects([machine currentState], @"begin");
    
    [machine pause];
    XCTAssertEqual([[machine lastError] code], StateMachineNoError);
    XCTAssertEqualObjects([machine currentState], @"begin");
    
    BOOL result = [machine trigger:@"enter"];
    XCTAssertFalse(result, @"Attempt to trigger event when paused unsuccessful");
    XCTAssertEqual([[machine lastError] code], EventWhilePaused);
}

- (void)testStateTransitions
{
    // This is an example of a performance test case.
    CCStateMachineBuilder *builder = [CCStateMachineBuilder stateMachineBuilderWithStates:@[ @"start", @"high", @"low" ]];
    CGPoint pos = [_label position];
    CGPoint high = CGPointMake(pos.x, pos.y+10);
    CGPoint low = CGPointMake(pos.x, pos.y-10);
    BOOL result = YES;
    
    // Set up our State Machine's transitions
    [builder addTransitionFromState:@"start" toState:@"high" onEvent:@"toggle"];
    [builder addTransitionFromState:@"high" toState:@"low" onEvent:@"toggle"];
    [builder addTransitionFromState:@"low" toState:@"high" onEvent:@"toggle"];
    
    // Bind some CCNodes to some values so they get updated when a state is entered
    [builder bind:_label toState:@"high" withKeyPath:@"position" toValue:[NSValue valueWithCGPoint:high]];
    [builder bind:_label toState:@"low" withKeyPath:@"position" toValue:[NSValue valueWithCGPoint:low]];
    [builder bind:_stateLabel toState:@"low" withKeyPath:@"string" toValue:@"LOW"];
    [builder bind:_stateLabel toState:@"high" withKeyPath:@"string" toValue:@"HIGH"];
    
    CCStateMachine *machine = [builder generateStateMachineWithName:@"Cocos State Machine"];
    
    [machine run];
    XCTAssertEqual([machine currentState], @"start", @"Should be start on initial state");
    
    [machine trigger:@"toggle"];
    XCTAssertEqualObjects([machine currentState], @"high", @"Toggle from start -> high");
    XCTAssertEqual(_label.position.x, high.x);
    XCTAssertEqual(_label.position.y, high.y);
    XCTAssertEqualObjects(_stateLabel.string, @"HIGH");
    
    [machine trigger:@"toggle"];
    XCTAssertEqualObjects([machine currentState], @"low", @"Toggle from high -> low");
    XCTAssertEqual(_label.position.x, low.x);
    XCTAssertEqual(_label.position.y, low.y);
    XCTAssertEqualObjects(_stateLabel.string, @"LOW");
    
    result = [machine trigger:@"boggle"];
    XCTAssertEqual([[machine lastError] code], UnknownEventName);
}

@end
