//
//  UPnPOperation.m
//  AARemotePlayer
//
//  Created by AAMac on 2017/4/20.
//  Copyright © 2017年 Gavin Tsang. All rights reserved.
//

#import "UPnPOperation.h"
#import <libupnp/upnptools.h>
#import "UPnPService.h"
#import "UPnPDevice.h"

NSString *const kUPnPOperationDictionaryMakerUPnPActionKey = @"action";
NSString *const kUPnPOperationDictionaryMakerUPnPParametersKey = @"parameters";
//NSString *const kUPnPOperationDictionaryMakerUPnPServiceKey = @"service";

static dispatch_queue_t upnp_operation_completion_queue() {
    static dispatch_queue_t _upnp_operation_completion_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _upnp_operation_completion_queue = dispatch_queue_create("com.AA.UPnP.UPnPOperation", DISPATCH_QUEUE_SERIAL);
    });
    
    return _upnp_operation_completion_queue;
}

static dispatch_group_t upnp_operation_completion_group() {
    static dispatch_group_t _upnp_operation_completion_group;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _upnp_operation_completion_group = dispatch_group_create();
    });
    
    return _upnp_operation_completion_group;
}

@interface UPnPOperation ()

@property (nonatomic, getter = isExecuting) BOOL executing;

@property (nonatomic, getter = isFinished)  BOOL finished;

@end

@implementation UPnPOperation
@synthesize executing = _executing;
@synthesize finished = _finished;

+ (void)actionRequestThreadEntryPoint:(id)__unused object {
    @autoreleasepool {
        [[NSThread currentThread] setName:@"com.AA.UPnP.UPnPOperation.ActionWorkers"];
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runLoop run];
    }
}

+ (NSThread *)actionRequestThread {
    static NSThread *_actionRequestThread = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _actionRequestThread = [[NSThread alloc] initWithTarget:self selector:@selector(actionRequestThreadEntryPoint:) object:nil];
        [_actionRequestThread start];
    });
    
    return _actionRequestThread;
}

- (instancetype)initWithCompletion:(UPnPOperationCompletion)completionBlock {
    self = [super init];
    
    if (self) {
        [self setCompletionBlockWithUPnPOperationCompletion:completionBlock];
        self.runLoopModes = [NSSet setWithObject:NSRunLoopCommonModes];
    }
    
    return self;
}

#pragma mark - public methods

- (void)setCompletionBlockWithUPnPOperationCompletion:(UPnPOperationCompletion)upnpCompletion {
    void (^completion)() = ^{
        upnpCompletion(self.actionResponse, self.error);
    };
    self.completionBlock = completion;
}

#pragma mark - NSOperation

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isConcurrent {
    return YES;
}

- (void)start {
    if ([self isCancelled]) {
        self.finished = YES;
        return;
    }
    
    [self performSelector:@selector(performAction) onThread:[[self class] actionRequestThread] withObject:nil waitUntilDone:NO modes:[self.runLoopModes allObjects]];
}

- (void)setCompletionBlock:(void (^)(void))block {
    if (!block) {
        [super setCompletionBlock:nil];
    } else {
        __weak __typeof(self)weakSelf = self;
        [super setCompletionBlock:^ {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
            dispatch_group_t group = strongSelf.completionGroup ?: upnp_operation_completion_group();
            dispatch_queue_t queue = strongSelf.completionQueue ?: upnp_operation_completion_queue();
#pragma clang diagnostic pop
            
            dispatch_group_async(group, queue, ^{
                block();
            });
            
            dispatch_group_notify(group, upnp_operation_completion_queue(), ^{
                [strongSelf setCompletionBlock:nil];
            });
        }];
    }
}

#pragma mark - private methods
static NSString *const kActionResponsePrefix = @"e:";
static NSString *const kActionResponseSuffix = @"Response";

- (void)performAction {
    if (self.actionName.length == 0 || !self.service) {
        NSString *localizedDescription = NSLocalizedString(@"Wrong Parameters", @"Wrong Parameters");
        NSString *localizedFMT = NSLocalizedString(@"ActionName(%@) or Service(%p) doesn't make sense", @"ActionName(%@) or Service(%@) doesn't make sense");
        NSString *localizedFailureReason = [NSString stringWithFormat:localizedFMT, self.actionName, self.service];
        NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                   localizedDescription, NSLocalizedDescriptionKey,
                                   localizedFailureReason, NSLocalizedFailureReasonErrorKey,
                                   nil];
        self.error = [NSError errorWithDomain:@"UPnPOperation" code:0 userInfo:errorDict];
        
        self.finished = YES;
        return;
    }
    
    self.executing = YES;
    IXML_Document *actionNode = NULL;
    
    if (!self.service) {
        [self cancel];
        return;
    }
    
    __strong UPnPService *strongService = self.service;
    
    if (self.parameters.allKeys.count > 0) {
        for (NSString *key in self.parameters.allKeys) {
            NSString *value = self.parameters[key];
            
            if (UpnpAddToAction(&actionNode, self.actionName.UTF8String, strongService.serviceType.UTF8String, key.UTF8String, value.description.UTF8String) != UPNP_E_SUCCESS) {
#ifdef DEBUG
           NSLog(@"ERROR: %@: Trying to add action param", NSStringFromSelector(_cmd));
#endif
            }
        }
    } else {
        actionNode = UpnpMakeAction(self.actionName.UTF8String, strongService.serviceType.UTF8String,0, NULL);
    }
    
    IXML_Document *resultDoc = NULL;
    int retCode = UpnpSendAction(self.clientHandle, strongService.controlURL.absoluteString.UTF8String, strongService.serviceType.UTF8String, strongService.device.udn.UTF8String, actionNode, &resultDoc);
    
    NSMutableDictionary *resultDict = nil;
    
    if (retCode == UPNP_E_SUCCESS) {
        NSError *error = nil;
        
        NSString *actionName = nil;
        
        const char *nodeName = NULL;
        nodeName = ixmlNode_getNodeName(resultDoc->n.firstChild);
        
        if (nodeName != NULL) {
            resultDict = [NSMutableDictionary dictionary];
            
            NSString *nodeNameStr = [NSString stringWithUTF8String:nodeName];
            
            NSRange range = NSMakeRange(kActionResponsePrefix.length, nodeNameStr.length - kActionResponsePrefix.length - kActionResponseSuffix.length);
            actionName = [nodeNameStr substringWithRange:range];
            
            resultDict[kUPnPOperationDictionaryMakerUPnPActionKey] = actionName;
            
            IXML_NodeList *children = ixmlNode_getChildNodes(resultDoc->n.firstChild);
            unsigned long numOfChildren = ixmlNodeList_length(children);
            
            NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
            
            for (int i = 0; i < numOfChildren; i++) {
                IXML_Node *child = ixmlNodeList_item(children, i);
                
                if (child == NULL) {
                    continue;
                }
                
                const char *parameterName = ixmlNode_getNodeName(child);
                const char *parameterValue = NULL;
                
                IXML_Node *valueNode = child->firstChild;
                
                if (valueNode != NULL && ixmlNode_getNodeType(valueNode) == eTEXT_NODE) {
                    parameterValue = ixmlNode_getNodeValue(valueNode);
                }
                
                if (parameterName != NULL) {
                    NSString *key = [NSString stringWithUTF8String:parameterName];
                    id objValue = nil;
                    
                    if (parameterValue != NULL) {
                        objValue = [NSString stringWithUTF8String:parameterValue];
                    } else {
                        objValue = [NSNull null];
                    }
                    
                    parameters[key] = objValue;
                }
            }
            
            resultDict[kUPnPOperationDictionaryMakerUPnPParametersKey] = parameters;
        } else {
            NSString *localizedDescription = NSLocalizedString(@"Wrong format", @"Wrong format.");
            NSString *localizedFailureReason = NSLocalizedString(@"A nil nodeName.", @"A nil nodeName reason.");
            NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                       localizedDescription, NSLocalizedDescriptionKey,
                                       localizedFailureReason, NSLocalizedFailureReasonErrorKey,
                                       nil];
            error = [NSError errorWithDomain:@"UPnPOperation" code:0 userInfo:errorDict];
#ifdef DEBUG
           NSLog(@"%@:Error: Wrong format, empty nodeName", NSStringFromSelector(_cmd));
#endif
       }
        ixmlDocument_free(resultDoc);
        self.actionResponse = resultDict;
        self.executing = NO;
        self.finished = YES;
    } else {
        NSString *localizedDescription = NSLocalizedString(@"Action response error.", @"Action response error.");
        NSString *format = NSLocalizedString(@"Device response action occur an error:%s.", @"Device response action occur an error:%s.");
        NSString *localizedFailureReason = [NSString stringWithFormat:format, UpnpGetErrorMessage(retCode)];
        NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                   localizedDescription, NSLocalizedDescriptionKey,
                                   localizedFailureReason, NSLocalizedFailureReasonErrorKey,
                                   nil];
        self.error = [NSError errorWithDomain:@"UPnPOperation" code:retCode userInfo:errorDict];
        self.executing = NO;
        self.finished = YES;
    }
}

@end
