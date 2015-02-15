#import "TestBase.h"

#import "CCStateMachine.h"
#import "CCStateMachineBuilder.h"

static int MainSceneContext = 0;

@interface CCStateMachineTest : TestBase

//

@end

@implementation CCStateMachineTest
{
    CCTime (^_updateBlock)(void);
    CCTime _testLoopTimer;
    BOOL _runTestLoop;
    
    CCNode * _observedNode;
    NSString *_observedKeyPath;
}

- (void)setupStateMachineBasicTest
{
    CCLabelTTF *label = [CCLabelTTF labelWithString:@"Stateful Node" fontName:@"Marker felt" fontSize:24.0];
    [label setPositionType:CCPositionTypeNormalized];
    [label setPosition:ccp(0.5f, 0.5f)];
    [[self contentNode] addChild:label];
    
    CCLabelTTF *stateLabel = [CCLabelTTF labelWithString:@"State Display" fontName:@"HelveticaNeue-Light" fontSize:18.0];
    [stateLabel setPositionType:CCPositionTypeMake(CCPositionUnitPoints, CCPositionUnitPoints, CCPositionReferenceCornerTopRight)];
    [stateLabel setAnchorPoint:ccp(1.0f, 1.0f)];
    [stateLabel setPosition:ccp(10.0f, 10.0f)];
    [[self contentNode] addChild:stateLabel];
    
    CCStateMachineBuilder *builder = [CCStateMachineBuilder stateMachineBuilderWithStates:@[ @"start", @"high", @"low" ]];
    CGPoint pos = [label position];
    CGPoint high = ccp(pos.x, pos.y * 1.1f);
    CGPoint low = ccp(pos.x, pos.y * 0.9f);
    
    // Set up our State Machine's transitions
    [builder addTransitionFromState:@"start" toState:@"high" onEvent:@"toggle"];
    [builder addTransitionFromState:@"high" toState:@"low" onEvent:@"toggle"];
    [builder addTransitionFromState:@"low" toState:@"high" onEvent:@"toggle"];
    
    // Bind some CCNodes to some values so they get updated when a state is entered
    [builder bind:label toState:@"high" withKeyPath:@"position" toValue:[NSValue valueWithCGPoint:high]];
    [builder bind:label toState:@"low" withKeyPath:@"position" toValue:[NSValue valueWithCGPoint:low]];
    [builder bind:stateLabel toState:@"low" withKeyPath:@"string" toValue:@"LOW"];
    [builder bind:stateLabel toState:@"high" withKeyPath:@"string" toValue:@"HIGH"];
    
    [builder bind:label toState:@"high" withKeyPath:@"color" toValue:[CCColor blueColor]];
    [builder bind:label toState:@"low" withKeyPath:@"color" toValue:[CCColor redColor]];
    
    CCStateMachine *machine = [builder generateStateMachineWithName:@"Cocos State Machine"];
    [machine run];
    
    [label addObserver:self forKeyPath:@"position" options:NSKeyValueObservingOptionNew context:&MainSceneContext];
    _observedNode = label;
    _observedKeyPath = @"position";
    
    const CCTime delay = 2.0;
    _runTestLoop = YES;
    _updateBlock = ^(void) {
        [machine trigger:@"toggle"];
        return delay;
    };
}

- (void)update:(CCTime)delta
{
    if (_runTestLoop)
    {
        _testLoopTimer -= delta;
        if (_testLoopTimer < 0.0f)
        {
            CCTime delay = _updateBlock();
            _testLoopTimer = delay;
        }
    }
}

- (void)pressedNext:(id)sender
{
    // Remove the observer before the state machine and label is deallocated.
    [_observedNode removeObserver:self forKeyPath:_observedKeyPath];
    _observedKeyPath = nil;
    _observedNode = nil;
    
    // Stop running the block and release it.  Note this will release the state machine
    // and label which are captured by the updateBlock.
    _runTestLoop = NO;
    _updateBlock = nil;
    [super pressedNext:sender];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != &MainSceneContext)
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    NSLog(@"%@ of %@ changed to %@", keyPath, object, [change objectForKey:NSKeyValueChangeNewKey]);
}

@end
