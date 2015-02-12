/*
 * cocos2d for iPhone: http://www.cocos2d-iphone.org
 *
 * Copyright (c) 2010 Ricardo Quesada
 * Copyright (c) 2011 Zynga Inc.
 * Copyright (c) 2013-2014 Cocos2D Authors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 *
 * File autogenerated with Xcode. Adapted for cocos2d needs.
 */

#import "CCResponderManager.h"
#import "CCNode.h"
#import "CCDirector_Private.h"
#import "CCDirectorMac.h"
#import "CCScene.h"
#import "CCTouch.h"

@implementation CCRunningResponder

@end

#pragma mark -

@implementation CCResponderManager
{
    __weak CCNode *_responderList[CCResponderManagerBufferSize];    // list of active responders
    int _responderListCount;                                        // number of active responders
    BOOL _dirty;                                                    // list of responders should be rebuild
    BOOL _currentEventProcessed;                                    // current event was processed
    BOOL _enabled;                                                  // responder manager enabled
    BOOL _exclusiveMode;                                            // manager only responds to current exclusive responder
    __weak CCDirector *_director;
    
    NSMutableArray *_runningResponderList;                          // list of running responders
}

#pragma mark - create and destroy

- (id)initWithDirector:(CCDirector *)director
{
    self = [super init];
    NSAssert(self, @"Unable to create class");
    
    // initalize
    _runningResponderList = [NSMutableArray array];
    _director = director;
    
    // reset touch handling
    [self removeAllResponders];
    _dirty = YES;
    _enabled = YES;
    _exclusiveMode = NO;
    
    // done
    return(self);
}


- (void)discardCurrentEvent
{
    _currentEventProcessed = NO;
}

#pragma mark - add and remove touch responders

- (void)buildResponderList
{
    // rebuild responder list
    [self removeAllResponders];
    
    NSAssert(_director, @"Missing current director. Probably not bound.");
    NSAssert(_director.runningScene, @"Missing current running scene.");
    
    [self buildResponderList:_director.runningScene];
    _dirty = NO;
}

- (void)buildResponderList:(CCNode *)node
{
    // dont add invisible nodes
    if (!node.visible) return;
    
    BOOL shouldAddNode = node.isUserInteractionEnabled;
    
    if (node.children.count)
    {
        // scan through children, and build responder list
        for (CCNode *child in node.children)
        {
            if (shouldAddNode && child.zOrder >= 0)
            {
                [self addResponder:node];
                shouldAddNode = NO;
            }
            [self buildResponderList:child];
        }
    }
    
    // if eligible, add the current node to the responder list
    if (shouldAddNode) [self addResponder:node];
}


- (void)addResponder:(CCNode *)responder
{
    _responderList[_responderListCount] = responder;
    _responderListCount ++;
    NSAssert(_responderListCount < CCResponderManagerBufferSize, @"Number of touchable nodes pr. scene can not exceed <%d>", CCResponderManagerBufferSize);
}

- (void)removeAllResponders
{    
    _responderListCount = 0;
}

- (void)cancelAllResponders
{
    while (_runningResponderList.count > 0)
    {
        [self cancelResponder:[_runningResponderList lastObject]];
    }
    _exclusiveMode = NO;
}

#pragma mark - dirty

- (void)markAsDirty
{
    _dirty = YES;
}

#pragma mark - enabled

- (void)setEnabled:(BOOL)enabled
{
    if (enabled == _enabled) return;
    _enabled = enabled;
    // cancel ongoing touches, if disabled
    if (!_enabled)
    {
        [self cancelAllResponders];
    }
}

#pragma mark - nodes at specific positions

- (CCNode *)nodeAtPoint:(CGPoint)pos
{
    if (_dirty) [self buildResponderList];

    // scan backwards through touch responders
    for (int index = _responderListCount - 1; index >= 0; index --)
    {
        CCNode *node = _responderList[index];
        
        // check for hit test
        if ([node hitTestWithWorldPos:pos])
        {
            return(node);
        }
    }
    // nothing found
    return(nil);
}

- (NSArray *)nodesAtPoint:(CGPoint)pos
{
    if (_dirty) [self buildResponderList];

    NSMutableArray *result = [NSMutableArray array];
    // scan backwards through touch responders
    for (int index = _responderListCount - 1; index >= 0; index --)
    {
        CCNode *node = _responderList[index];
        
        // check for hit test
        if ([node hitTestWithWorldPos:pos])
        {
            [result addObject:node];
        }
    }
    // if nothing was found, an empty array will be returned
    return(result);
}

#pragma mark - iOS touch handling -

//#if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)
#if __CC_PLATFORM_IOS || __CC_PLATFORM_ANDROID
- (void)touchesBegan:(NSSet *)touches withEvent:(CCTouchEvent *)event
{
    if (!_enabled) return;
    if (_exclusiveMode) return;

    // End editing any text fields
#if __CC_PLATFORM_IOS
    [_director.view endEditing:YES];
#endif
    BOOL responderCanAcceptTouch;
    
    if (_dirty) [self buildResponderList];
    
    // go through all touches
    for (CCTouch *touch in touches)
    {
        CGPoint worldTouchLocation = [_director convertToGL:[touch locationInView:(CC_VIEW<CCView>*)_director.view]];
        
        // scan backwards through touch responders
        for (int index = _responderListCount - 1; index >= 0; index --)
        {
            CCNode *node = _responderList[index];
            
            // check for hit test
            if ([node clippedHitTestWithWorldPos:worldTouchLocation])
            {
                // check if node has exclusive touch
                if (node.isExclusiveTouch)
                {
                    [self cancelAllResponders];
                    _exclusiveMode = YES;
                }
                
                // if not a multi touch node, check if node already is being touched
                responderCanAcceptTouch = YES;
                if (!node.isMultipleTouchEnabled)
                {
                    // scan current touch objects, and break if object already has a touch
                    for (CCRunningResponder *responderEntry in _runningResponderList)
                    {
                        if (responderEntry.target == node)
                        {
                            responderCanAcceptTouch = NO;
                            break;
                        }
                    }
                }
                if (!responderCanAcceptTouch) break;
                
                // begin the touch
                _currentEventProcessed = YES;
                if ([node respondsToSelector:@selector(touchBegan:withEvent:)])
                    [node touchBegan:touch withEvent:event];
 
                // if touch was processed, add it and break
                if (_currentEventProcessed)
                {
                    [self addResponder:node withTouch:touch andEvent:event];
                    break;
                }
            }
        }
    }
}


- (void)touchesMoved:(NSSet *)touches withEvent:(CCTouchEvent *)event
{
    if (!_enabled) return;
    if (_dirty) [self buildResponderList];

    // go through all touches
    for (CCTouch *touch in touches)
    {
        // get touch object
        CCRunningResponder *touchEntry = [self responderForTouch:touch];
        
        // if a touch object was found
        if (touchEntry)
        {
            CCNode *node = (CCNode *)touchEntry.target;
            
            // check if it locks touches
            if (node.claimsUserInteraction)
            {
                // move the touch
                if ([node respondsToSelector:@selector(touchMoved:withEvent:)])
                    [node touchMoved:touch withEvent:event];
            }
            else
            {
                // as node does not lock touch, check if it was moved outside
                if (![node clippedHitTestWithWorldPos:[_director convertToGL:[touch locationInView:_director.view]]])
                {
                    // cancel the touch
                    if ([node respondsToSelector:@selector(touchCancelled:withEvent:)])
                        [node touchCancelled:touch withEvent:event];
                    // remove from list
                    [_runningResponderList removeObject:touchEntry];

                    // always end exclusive mode
                    _exclusiveMode = NO;
                }
                else
                {
                    // move the touch
                    if ([node respondsToSelector:@selector(touchMoved:withEvent:)])
                        [node touchMoved:touch withEvent:event];
                }
            }
        }
        else
        {
            if (!_exclusiveMode)
            {
                // scan backwards through touch responders
                for (int index = _responderListCount - 1; index >= 0; index --)
                {
                    CCNode *node = _responderList[index];
                    
                    // if the touch responder does not lock touch, it will receive a touchBegan if a touch is moved inside
                    if (!node.claimsUserInteraction  && [node clippedHitTestWithWorldPos:[_director convertToGL:[touch locationInView:_director.view ]]])
                    {
                        // check if node has exclusive touch
                        if (node.isExclusiveTouch)
                        {
                            [self cancelAllResponders];
                            _exclusiveMode = YES;
                        }

                        // begin the touch
                        _currentEventProcessed = YES;
                        if ([node respondsToSelector:@selector(touchBegan:withEvent:)])
                            [node touchBegan:touch withEvent:event];
                        
                        // if touch was accepted, add it and break
                        if (_currentEventProcessed)
                        {
                            [self addResponder:node withTouch:touch andEvent:event];
                            break;
                        }
                    }
                }
            }
        }
    }
}


- (void)touchesEnded:(NSSet *)touches withEvent:(CCTouchEvent *)event
{
    if (!_enabled) return;
    if (_dirty) [self buildResponderList];
    
    // go through all touches
    for (CCTouch *touch in touches)
    {
        // get touch object
        CCRunningResponder *touchEntry = [self responderForTouch:touch];
        
        if (touchEntry)
        {
            CCNode *node = (CCNode *)touchEntry.target;
            
            // end the touch
            if ([node respondsToSelector:@selector(touchEnded:withEvent:)])
                [node touchEnded:touch withEvent:event];
            // remove from list
            [_runningResponderList removeObject:touchEntry];
            
            // always end exclusive mode
            _exclusiveMode = NO;
        }
    }
}


- (void)touchesCancelled:(NSSet *)touches withEvent:(CCTouchEvent *)event
{
    if (!_enabled) return;
    if (_dirty) [self buildResponderList];

    // go through all touches
    for (CCTouch *touch in touches)
    {
        // get touch object
        CCRunningResponder *touchEntry = [self responderForTouch:touch];
        
        if (touchEntry)
        {
            [self cancelResponder:touchEntry];

            // always end exclusive mode
            _exclusiveMode = NO;
        }
    }
}

#pragma mark - iOS helper functions

// finds a responder object for a touch
- (CCRunningResponder *)responderForTouch:(CCTouch *)touch
{
    for (CCRunningResponder *touchEntry in _runningResponderList)
    {
        if (touchEntry.touch == touch)
            return touchEntry;
    }
    return(nil);
}

// adds a responder object ( running responder ) to the responder object list
- (void)addResponder:(CCNode *)node withTouch:(CCTouch *)touch andEvent:(CCTouchEvent *)event
{
    CCRunningResponder *touchEntry;
    
    // create a new touch object
    touchEntry = [[CCRunningResponder alloc] init];
    touchEntry.target = node;
    touchEntry.touch = touch;
    touchEntry.event = event;
    [_runningResponderList addObject:touchEntry];
}

// cancels a running responder

- (void)cancelResponder:(CCRunningResponder *)responder
{
    CCNode *node = (CCNode *)responder.target;
    
    // cancel the touch
    if ([node respondsToSelector:@selector(touchCancelled:withEvent:)])
        [node touchCancelled:responder.touch withEvent:responder.event];
    // remove from list
    [_runningResponderList removeObject:responder];
}


#elif __CC_PLATFORM_MAC

#pragma mark - Mac mouse handling -

- (void)mouseDown:(NSEvent *)theEvent button:(CCMouseButton)button
{
    if (!_enabled) return;
    if (_dirty) [self buildResponderList];
    
    [self executeOnEachResponder:^(CCNode *node){
        [node mouseDown:theEvent button:button];
        if (_currentEventProcessed) {
            [self addResponder:node withButton:button];
        }
    } withEvent:theEvent];
    
}

- (void)mouseDragged:(NSEvent *)theEvent button:(CCMouseButton)button
{
    if (!_enabled) return;
    if (_dirty) [self buildResponderList];
    
    CCRunningResponder *responder = [self responderForButton:button];
    
    if (responder) {
        // This drag event is already associated with a specific target.
        CCNode *node = (CCNode *)responder.target;
        
        // Items that claim user interaction receive events even if they occur outside of the bounds of the object.
        if (node.claimsUserInteraction || [node clippedHitTestWithWorldPos:[_director convertEventToGL:theEvent]]) {
            [CCDirector pushCurrentDirector:_director];
            if ([node respondsToSelector:@selector(mouseDragged:button:)]) [node mouseDragged:theEvent button:button];
            [CCDirector popCurrentDirector];
        } else {
            [_runningResponderList removeObject:responder];
        }        
    } else {
        [self executeOnEachResponder:^(CCNode *node){
            [node mouseDragged:theEvent button:button];
            if (_currentEventProcessed) {
                [self addResponder:node withButton:button];
            }
        } withEvent:theEvent];
    }
}

- (void)mouseUp:(NSEvent *)theEvent button:(CCMouseButton)button
{
    if (_dirty) [self buildResponderList];
    
    CCRunningResponder *responder = [self responderForButton:button];
    if (responder)
    {
        CCNode *node = (CCNode *)responder.target;
        
        [CCDirector pushCurrentDirector:_director];
        if ([node respondsToSelector:@selector(mouseUp:button:)]) [node mouseUp:theEvent button:button];
        [CCDirector popCurrentDirector];
        
        [_runningResponderList removeObject:responder];
    }
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    if (!_enabled) return;
    if (_dirty) [self buildResponderList];

    // if otherMouse is active, scrollWheel goes to that node
    // otherwise, scrollWheel goes to the node under the cursor
    CCRunningResponder *responder = [self responderForButton:CCMouseButtonOther];
    
    if (responder)
    {
        CCNode *node = (CCNode *)responder.target;
        
        _currentEventProcessed = YES;
        [CCDirector pushCurrentDirector:_director];
        if ([node respondsToSelector:@selector(scrollWheel:)]) [node scrollWheel:theEvent];
        [CCDirector popCurrentDirector];
        
        // if mouse was accepted, return
        if (_currentEventProcessed) return;
    }
    
    [self executeOnEachResponder:^(CCNode *node){
        [node scrollWheel:theEvent];
    } withEvent:theEvent];
    
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    if (!_enabled) return;
    if (_dirty) [self buildResponderList];
    
    [self executeOnEachResponder:^(CCNode *node){
        [node mouseMoved:theEvent];
    } withEvent:theEvent];
}

- (void) executeOnEachResponder:(void(^)(CCNode *))block withEvent:(NSEvent *)theEvent
{
    [CCDirector pushCurrentDirector:_director];
    
    // scan through responders, and find first one
    for (int index = _responderListCount - 1; index >= 0; index --)
    {
        CCNode *node = _responderList[index];
        
        // check for hit test
        if ([node clippedHitTestWithWorldPos:[_director convertEventToGL:theEvent]])
        {
            _currentEventProcessed = YES;
            block(node);
            
            // if mouse was accepted, break
            if (_currentEventProcessed) break;
        }
    }
    [CCDirector popCurrentDirector];
}

#pragma mark - Mac keyboard handling -

- (void)keyDown:(NSEvent *)theEvent
{
    if (!_enabled) return;

    if (_dirty) [self buildResponderList];
    [CCDirector pushCurrentDirector:_director];

    for (int index = _responderListCount - 1; index >= 0; index --)
    {
        CCNode *node = _responderList[index];
        [node keyDown:theEvent];
    }
    [CCDirector popCurrentDirector];
    
}

- (void)keyUp:(NSEvent *)theEvent
{
    if (!_enabled) return;

    if (_dirty) [self buildResponderList];
    [CCDirector pushCurrentDirector:_director];

    for (int index = _responderListCount - 1; index >= 0; index --)
    {
        CCNode *node = _responderList[index];
        [node keyUp:theEvent];
    }
    [CCDirector popCurrentDirector];
    
}


#pragma mark - Mac helper functions
// finds a responder object for an event

- (CCRunningResponder *)responderForButton:(CCMouseButton)button
{
    for (CCRunningResponder *touchEntry in _runningResponderList)
    {
        if (touchEntry.button == button) return(touchEntry);
    }
    return(nil);
}

// adds a responder object ( running responder ) to the responder object list
- (void)addResponder:(CCNode *)node withButton:(CCMouseButton)button
{
    CCRunningResponder *touchEntry;
    
    // create a new touch object
    touchEntry = [[CCRunningResponder alloc] init];
    touchEntry.target = node;
    touchEntry.button = button;
    [_runningResponderList addObject:touchEntry];
}

- (void)cancelResponder:(CCRunningResponder *)responder
{
    [_runningResponderList removeObject:responder];
}

#endif

@end
