//
//  UPnPManager.m
//  AARemotePlayer
//
//  Created by AAMac on 2017/4/19.
//  Copyright © 2017年 Gavin Tsang. All rights reserved.
//

#import "UPnPManager.h"
#import "UPnPDevice.h"
#import "UPnPService.h"
#import "UPnPOperation.h"
#import <libupnp/upnp.h>
#import <libupnp/upnptools.h>
#import <netinet6/in6.h>
#import <netinet/in.h>

#define UPNP_MEDIARENDER @"urn:schemas-upnp-org:device:MediaRenderer:1"
//#define UPNP_RENDER_CONTROL @"urn:schemas-upnp-org:service:RenderingControl:1"

@interface UPnPService (UPnPManager)

@property (nonatomic, strong) NSString *subscriptionID;
@property (nonatomic, assign) NSTimeInterval subscriptionTimeout;
@property (atomic, assign) UPnPServiceSubscriptionState subscriptionState;

@end

@interface UPnPManager ()

@property (atomic, assign, readonly) UpnpClient_Handle clientHandle;

@property(strong, nonatomic) NSString * dir;

@property (nonatomic, strong) dispatch_queue_t service_subscription_queue;

@property (nonatomic, assign) NSTimeInterval subscriptionTimeout;

@property(strong, nonatomic) NSRecursiveLock * lock;

@property(strong, nonatomic) NSMutableArray * devices;

@property (nonatomic, strong) NSMutableSet *connectedDevices;

@end

static dispatch_queue_t upnp_manager_offandon_queue() {
    static dispatch_queue_t _upnp_manager_offandon_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _upnp_manager_offandon_queue = dispatch_queue_create("com.AA.UPnP.UPnPManger.OffAndOn", DISPATCH_QUEUE_CONCURRENT);
    });
    
    return _upnp_manager_offandon_queue;
}

@implementation UPnPManager

@synthesize address = _address;

+ (instancetype)shareManager {
    static UPnPManager * shareOne;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareOne = [[UPnPManager alloc] init];
    });
    return shareOne;
}

static const NSTimeInterval kDefaultSubscriptionTimeout = 2.0f;
- (instancetype)init {
    if (self = [super init]) {
        self.lock = [[NSRecursiveLock alloc] init];
        self.devices = [NSMutableArray array];
        self.onService = NO;
        _clientHandle = -1;
        _subscriptionTimeout = kDefaultSubscriptionTimeout;
        _service_subscription_queue = dispatch_queue_create("cn.com.AA.Remote.UPnP.Subscription", NULL);
    }
    return self;
}

- (NSMutableSet *)connectedDevices {
    if (!_connectedDevices) {
        _connectedDevices = [NSMutableSet set];
    }
    
    return _connectedDevices;
}

- (NSString *)address {
    return _address;
}

#pragma mark - Device Callbacks

int UPnP_Device_Callback(Upnp_EventType EventType, void *Event, void *Cookie) {
    return 0;
}

#pragma mark - Client Callbacks

int UPnP_Client_Noop_Callback(Upnp_EventType eventType, void *event, void *cookie) {
    return 0;
}

int UPnP_Client_Callback(Upnp_EventType eventType, void *event, void *cookie) {
    UPnPManager * manager = [UPnPManager shareManager];
    switch (eventType) {
#pragma mark Control callbacks
        case UPNP_CONTROL_ACTION_REQUEST:
#ifdef DEBUG
            NSLog(@"UPNP_CONTROL_ACTION_REQUEST");
#endif
            break;
        case UPNP_CONTROL_ACTION_COMPLETE:
#ifdef DEBUG
            NSLog(@"UPNP_CONTROL_ACTION_COMPLETE");
#endif
            break;
        case UPNP_CONTROL_GET_VAR_REQUEST:
#ifdef DEBUG
            NSLog(@"UPNP_CONTROL_GET_VAR_REQUEST");
#endif
            break;
        case UPNP_CONTROL_GET_VAR_COMPLETE:
#ifdef DEBUG
            NSLog(@"UPNP_CONTROL_GET_VAR_COMPLETE");
#endif
            break;
#pragma mark Discory callbacks
        case UPNP_DISCOVERY_ADVERTISEMENT_ALIVE:
        case UPNP_DISCOVERY_SEARCH_RESULT: {
            struct Upnp_Discovery *d_event = (struct Upnp_Discovery *)event;
            if (d_event->ErrCode != UPNP_E_SUCCESS) {
#ifdef DEBUG
                NSLog(@"UPNP_DISCOVERY_SEARCH_RESULT :%d",d_event->ErrCode);
#endif
            } else {
                [manager addNewEvent:d_event];
            }
        }
            break;
        case UPNP_DISCOVERY_ADVERTISEMENT_BYEBYE: {
            struct Upnp_Discovery *d_event = (struct Upnp_Discovery *)event;
            
            if (d_event->ErrCode != UPNP_E_SUCCESS) {
#ifdef DEBUG
                NSLog(@"UPNP_DISCOVERY_ADVERTISEMENT_BYEBYE :%d",d_event->ErrCode);
#endif
            } else {
                [manager removeOldEvent:d_event];
            }
        }
            break;
        case UPNP_DISCOVERY_SEARCH_TIMEOUT:
#ifdef DEBUG
            NSLog(@"UPNP_DISCOVERY_SEARCH_TIMEOUT");
#endif
            break;
#pragma mark Eventing callbacks
        case UPNP_EVENT_SUBSCRIPTION_REQUEST:
#ifdef DEBUG
            NSLog(@"UPNP_EVENT_SUBSCRIPTION_REQUEST");
#endif
            break;
        case UPNP_EVENT_RECEIVED:
            [manager parseUPnPEvent:event];
            break;
        case UPNP_EVENT_RENEWAL_COMPLETE:
#ifdef DEBUG
            NSLog(@"UPNP_EVENT_RENEWAL_COMPLETE");
#endif
            break;
        case UPNP_EVENT_SUBSCRIBE_COMPLETE: {
#ifdef DEBUG
            NSLog(@"UPNP_EVENT_SUBSCRIBE_COMPLETE");
#endif
        }
            break;
        case UPNP_EVENT_UNSUBSCRIBE_COMPLETE: {
#ifdef DEBUG
            NSLog(@"UPNP_EVENT_UNSUBSCRIBE_COMPLETE");
#endif
        }
            break;
        case UPNP_EVENT_AUTORENEWAL_FAILED: {
            struct Upnp_Event_Subscribe *es_event = (struct Upnp_Event_Subscribe *)event;
            if (es_event->ErrCode == UPNP_E_SOCKET_CONNECT) {
#ifdef DEBUG
                NSLog(@"UPNP_EVENT_AUTORENEWAL_FAILED,%d",es_event->ErrCode);
#endif
            }
        }
            break;
        case UPNP_EVENT_SUBSCRIPTION_EXPIRED:
#ifdef DEBUG
            NSLog(@"UPNP_EVENT_SUBSCRIPTION_EXPIRED");
#endif
            break;
        default:
            break;
    }
    
    return 0;
}

#pragma mark - callbacks event handle methods

- (void)addNewEvent:(struct Upnp_Discovery *)event {
    NSString * deviceType = [NSString stringWithUTF8String:event->DeviceType];
    if (!([deviceType isEqualToString:UPNP_MEDIARENDER])) {
        return;
    }
    NSString * deviceId = [NSString stringWithUTF8String:event->DeviceId];
    NSURL *url = [NSURL URLWithString:[NSString stringWithUTF8String:event->Location]];
    //        struct sockaddr_in6 * addr = (struct sockaddr_in6 *)&event->DestAddr;
    //        char gIF_IPV6[INET6_ADDRSTRLEN] = { '\0' };
    //        inet_ntop(AF_INET6,
    //                  &addr->sin6_addr,
    //                  gIF_IPV6, sizeof(gIF_IPV6));
    struct sockaddr_in * add = (struct sockaddr_in *)&event->DestAddr;
    char gIF_IPV4[INET_ADDRSTRLEN] = { '\0' };
    inet_ntop(AF_INET,
              &add->sin_addr,
              gIF_IPV4, sizeof(gIF_IPV4));
    NSString * ipAddress = [NSString stringWithUTF8String:gIF_IPV4];
    if ([self.lock tryLock]) {
        BOOL contain = NO;
        for (UPnPDevice * device in self.devices) {
            if ([device.udn isEqualToString:deviceId]) {
                [device updateDeviceFromDescriptionURL:url andDate:[NSDate date] andExpiration:event->Expires];
                contain = YES;
                break;
            }
        }
        if (!contain) {
            UPnPDevice * newDevice = [[UPnPDevice alloc] initWithUniversalDeviceNumber:deviceId];
            newDevice.descriptionURL = url;
            newDevice.lastActivityDate = [NSDate date];
            newDevice.expiration = event->Expires;
            newDevice.ipAddress = ipAddress;
            [self addDevice:newDevice];
        }
        [self.lock unlock];
    }
}

- (void)removeOldEvent:(struct Upnp_Discovery *)event {
    NSString * deviceType = [NSString stringWithUTF8String:event->DeviceType];
    if (!([deviceType isEqualToString:UPNP_MEDIARENDER])) {
        return;
    }
    if ([self.lock tryLock]) {
        UPnPDevice * removeD = nil;
        NSString * deviceId = [NSString stringWithUTF8String:event->DeviceId];
        for (UPnPDevice * device in self.devices) {
            if ([device.udn isEqualToString:deviceId]) {
                removeD = device;
            }
        }
        if (removeD) {
            [self removeDevice:removeD];
        }
        [self.lock unlock];
    }
}

- (void)parseUPnPEvent:(struct Upnp_Event *)event {
    if (event == NULL || strlen(event->Sid) == 0) {
        return;
    }
    
    NSString *subscriptionID = [NSString stringWithUTF8String:event->Sid];
    UPnPService *service = [self serviceOfSubscriptionID:subscriptionID];
    
    if (service) {
        NSDictionary *propertyDictionary = [self propertyDictionaryFromChangedVariables:event->ChangedVariables];
        
        [service parseEventWithProperties:propertyDictionary];
    } else {
        UpnpUnSubscribeAsync(self.clientHandle, event->Sid, UPnP_Client_Noop_Callback, NULL);
    }
}

#pragma mark - public methods

- (void)setupRootDir:(NSString *)dir {
    _dir = dir;
}

- (void)upnpManagerOnline:(BOOL)async {
    void (^block)() = ^{
        @synchronized (self) {
            int retCode = UpnpInit2("en0", 0);
            if (retCode == UPNP_E_SUCCESS || retCode == UPNP_E_FINISH) {
                UpnpSetMaxContentLength(0);
                if ([self registerClient]) {
                    retCode = UpnpSearchAsync(self.clientHandle, 5, [UPNP_MEDIARENDER cStringUsingEncoding:NSASCIIStringEncoding], NULL);
                    if (retCode == UPNP_E_SUCCESS) {
#ifdef DEBUG
                        NSLog(@"UpnpSearchAsync Success");
#endif
                    }else{
#ifdef DEBUG
                        NSLog(@"UpnpSearchAsync Failed:[ERROR:%d]:%s", retCode, UpnpGetErrorMessage(retCode));
#endif
                    }
                    self.onService = YES;
#ifdef DEBUG
                    NSLog(@"On Service");
#endif
                }
                if ([self upnpManagerSetupServer]) {
                    self.localServiceEnable = YES;
#ifdef DEBUG
                    NSLog(@"Setup The Web Server Success");
#endif
                }else{
                    self.localServiceEnable = NO;
#ifdef DEBUG
                    NSLog(@"Setup The Web Server Failed:[ERROR:%d]:%s", retCode, UpnpGetErrorMessage(retCode));
#endif
                }
            } else {
#ifdef DEBUG
                NSLog(@"UPnP SDK Initialization Failed:[ERROR:%d]:%s", retCode, UpnpGetErrorMessage(retCode));
#endif
            }
        }
    };
    if (async) {
        dispatch_async(upnp_manager_offandon_queue(), block);
    }else{
        block();
    }
}

- (void)upnpManagerOffline:(BOOL)async {
    void (^block)() = ^{
        @synchronized(self) {
            if ([self unregisterClient]) {
                self.onService = NO;
#ifdef DEBUG
                NSLog(@"Off Service");
#endif
                if (UpnpFinish() == UPNP_E_SUCCESS) {
#ifdef DEBUG
                    NSLog(@"UpnpFinish");
#endif
                    //不用锁，因为upnp的callback已经失效，没有对self.devices的操作。
                    [self.devices removeAllObjects];
                }
            }

        }
    };
    
    if (async) {
        dispatch_async(upnp_manager_offandon_queue(), block);
    } else {
        block();
    }
}

- (void)connectTo:(UPnPDevice *)device {
    if (device && ![self.connectedDevices containsObject:device]) {
        device.fadeExpiration = 0;
        
        for (UPnPService *service in device.services) {
            [self subscribeService:service];
        }
        
        [self.connectedDevices addObject:device];
    }
}

- (void)disconnectFrom:(UPnPDevice *)device {
    if (device && [self.connectedDevices containsObject:device]) {
        
        for (UPnPService *service in device.services) {
            [self unsubscribeService:service];
        }
        
        [self.connectedDevices removeObject:device];
    }
}

- (void)sendAction:(NSString *)actionName withParameters:(NSDictionary *)parameters toService:(UPnPService *)service completion:(UPnPManagerActionCompletionBlock)completion {
    UPnPOperation *operation = [[UPnPOperation alloc] initWithCompletion:completion];
    operation.service = service;
    operation.actionName = actionName;
    operation.parameters = parameters;
    operation.clientHandle = self.clientHandle;
    operation.completionQueue = self.opreationCompletionQueue;
    operation.completionGroup = self.opreationCompletionGroup;
    
    [service.actionOperationQueue addOperation:operation];
}

#pragma mark - private methods

- (BOOL)upnpManagerSetupServer {
    if (_dir) {
        const char * dir = [_dir cStringUsingEncoding:NSASCIIStringEncoding];
        int retcode = UpnpSetWebServerRootDir(dir);
        if (retcode == UPNP_E_SUCCESS) {
            char * ip = UpnpGetServerIpAddress();
            unsigned short port = UpnpGetServerPort();
            NSString * ipAddress = [NSString stringWithCString:ip encoding:NSUTF8StringEncoding];
            NSString * fullAddress = [NSString stringWithFormat:@"%@:%d",ipAddress,port];
            _address = fullAddress;
#ifdef DEBUG
            NSLog(@"ipAddress:%@",fullAddress);
#endif
            return YES;
        }else{
#ifdef DEBUG
            NSLog(@"setWebServerRootDir failed!");
#endif
        }
    }else{
        _address = nil;
#ifdef DEBUG
        NSLog(@"webServerRootDir was nil");
#endif
    }
    return NO;
}

- (BOOL)registerClient {
    if (self.clientHandle > 0) {
        return YES;
    }
    
    UpnpClient_Handle clientHandle = -1;
    int retCode = UpnpRegisterClient(UPnP_Client_Callback, NULL, &clientHandle);
    
    BOOL succeed = NO;
    
    switch (retCode) {
        case UPNP_E_SUCCESS:
            _clientHandle = clientHandle;
#ifdef DEBUG
            NSLog(@"UpnpRegisterClient Success");
#endif
            succeed = YES;
            break;
            
        default:
#ifdef DEBUG
            NSLog(@"UPnP Register Client Failed:[ERROR:%d]:%s", retCode, UpnpGetErrorMessage(retCode));
#endif
            break;
    }
    
    return succeed;
}

- (BOOL)unregisterClient {
    if (self.clientHandle > 0) {
        int retCode = UpnpUnRegisterClient(self.clientHandle);
        if (UPNP_E_SUCCESS == retCode) {
            _clientHandle = -1;
#ifdef DEBUG
            NSLog(@"UpnpUnRegisterClient Success");
#endif
            return YES;
        }else{
#ifdef DEBUG
            NSLog(@"UPnP Unregister Client Failed:[ERROR:%d]:%s", retCode, UpnpGetErrorMessage(retCode));
#endif
        }
    }
    return NO;
}


- (void)subscribeService:(UPnPService *)service {
    if (!service || !service.eventSubURL) {
        return;
    }
    void (^block)(void) = ^{
        if (service.subscriptionState == UPnPServiceSubscriptionStateSubscribed || service.subscriptionState == UPnPServiceSubscriptionStatePending) {
            return;
        }
        service.subscriptionState = UPnPServiceSubscriptionStatePending;
        Upnp_SID sid;
        int timeout = self.subscriptionTimeout;
        int retCode = UpnpSubscribe(self.clientHandle, service.eventSubURL.absoluteString.UTF8String, &timeout, sid);
        if (retCode == UPNP_E_SUCCESS) {
            NSAssert([NSString stringWithUTF8String:sid].length > 0, @"Subscribe:[%@] succeed but get a invalid SID(nil)", service.eventSubURL);
            service.subscriptionTimeout = timeout;
            service.subscriptionID = [NSString stringWithUTF8String:sid];
            service.subscriptionState = UPnPServiceSubscriptionStateSubscribed;
        } else {
            service.subscriptionTimeout = 0;
            service.subscriptionID = nil;
            service.subscriptionState = UPnPServiceSubscriptionStateNone;
#ifdef DEBUG
            NSLog(@"Unscribe:[%@] Failed:[ERROR:%d]:%s", service.eventSubURL, retCode, UpnpGetErrorMessage(retCode));
#endif
        }
    };
    dispatch_async(self.service_subscription_queue, block);
}

- (void)unsubscribeService:(UPnPService *)service {
    if (!service || !service.eventSubURL || service.subscriptionID.length == 0) {
        return;
    }
    void (^block)(void) = ^{
        if (service.subscriptionState == UPnPServiceSubscriptionStateNone || service.subscriptionState == UPnPServiceSubscriptionStatePending) {
            return;
        }
        service.subscriptionState = UPnPServiceSubscriptionStatePending;
        if (service.subscriptionID.length > 0) {
            int retCode = UpnpUnSubscribe(self.clientHandle, service.subscriptionID.UTF8String);
            
            if (retCode == UPNP_E_SUCCESS) {
            } else {
#ifdef DEBUG
               NSLog(@"Unscribe:[%@] Failed:[ERROR:%d]:%s", service.eventSubURL, retCode, UpnpGetErrorMessage(retCode));
#endif
            }
        } else {
#ifdef DEBUG
            NSLog(@"Unscribe:[%@] Failed:[ERROR:Invalid sid (nil)]", service.eventSubURL);
#endif
        }
        service.subscriptionTimeout = 0;
        service.subscriptionID = nil;
        service.subscriptionState = UPnPServiceSubscriptionStateNone;
    };
    dispatch_async(self.service_subscription_queue, block);
}

#pragma mark helper methods

- (NSDictionary *)propertyDictionaryFromChangedVariables:(IXML_Document *)changedVariables {
    NSDictionary *propertyDictionary = nil;
    
    IXML_NodeList *properties = ixmlDocument_getElementsByTagName(changedVariables,
                                                                  "e:property");
    if (properties) {
        unsigned long length = ixmlNodeList_length(properties);
        
        for (int i = 0; i < length; i++) {
            /* Loop through each property change found */
            IXML_Node *property = ixmlNodeList_item(properties, i);
            
            if (property == NULL) {
#ifdef DEBUG
                NSLog(@"%@:Fetal error, property=NULL", NSStringFromSelector(_cmd));
#endif
                continue;
            } else {
                IXML_Node *child = property->firstChild;
                
                const char *name = ixmlNode_getNodeName(child);
                IXML_Node *valueChild = child->firstChild;
                
                const char *value = NULL;
                
                if (valueChild != NULL && ixmlNode_getNodeType(valueChild) == eTEXT_NODE) {
                    value = ixmlNode_getNodeValue(valueChild);
                }
                
                NSString *key = nil;
                
                if (name != NULL) {
                    key = [NSString stringWithUTF8String:name];
                    id objValue = nil;
                    
                    if (value != NULL) {
                        objValue = [NSString stringWithUTF8String:value];
                        
                        if ([key caseInsensitiveCompare:@"LastChange"] == NSOrderedSame) {
                            IXML_Document *event_ixml_doc = NULL;
                            
                            if (ixmlParseBufferEx(value, &event_ixml_doc) == IXML_SUCCESS) {
                                IXML_NodeList *instanceNodeList = ixmlDocument_getElementsByTagName(event_ixml_doc, "InstanceID");
                                unsigned long length = ixmlNodeList_length(instanceNodeList);
                                NSMutableArray *instanceMutableArray = [NSMutableArray arrayWithCapacity:length];
                                for (int i = 0; i < length; i++) {
                                    IXML_Node *instanceNode = ixmlNodeList_item(instanceNodeList, i);
                                    if (instanceNode) {
                                        NSMutableDictionary *instanceMutableDict = [NSMutableDictionary dictionary];
                                        const char *instanceIDValueChar = ixmlElement_getAttribute((IXML_Element *)instanceNode, "val");
                                        NSString *instanceIDValue = [NSString stringWithUTF8String:instanceIDValueChar];
                                        [instanceMutableDict setValue:instanceIDValue forKey:@"id"];
                                        
                                        IXML_Node *childNode = ixmlNode_getFirstChild(instanceNode);
                                        
                                        while (childNode) {
                                            const char *childName = ixmlElement_getTagName((IXML_Element *)childNode);
                                            const char *childValue = ixmlElement_getAttribute((IXML_Element *)childNode, "val");
                                            if (childName) {
                                                NSString *childKey = [NSString stringWithUTF8String:childName];
                                                if (childValue) {
                                                    [instanceMutableDict setObject:[NSString stringWithUTF8String:childValue] forKey:childKey];
                                                } else {
                                                    [instanceMutableDict setObject:[NSNull null] forKey:childKey];
                                                }
                                            }
                                            
                                            childNode = ixmlNode_getNextSibling(childNode);
                                        }
                                        
                                        [instanceMutableArray addObject:instanceMutableDict];
                                    }
                                }
                                
                                ixmlNodeList_free(instanceNodeList);
                                objValue = [NSDictionary dictionaryWithObjectsAndKeys:instanceMutableArray, @"Instances", nil];
                                
                                ixmlDocument_free(event_ixml_doc);
                            }
                        }
                    } else {
                        objValue = [NSNull null];
                    }
                    
                    propertyDictionary = [NSDictionary dictionaryWithObjectsAndKeys:objValue, key, nil];
                }
            }
        }
        
        ixmlNodeList_free(properties);
    }
    
    return propertyDictionary;
}

- (void)addDevice:(UPnPDevice *)device {
    [self.devices addObject:device];
    [device connect];
}

- (void)removeDevice:(UPnPDevice *)device {
    [self.devices removeObject:device];
    [device disConnect];
}

- (UPnPService *)serviceOfSubscriptionID:(NSString *)subscriptionID {
    UPnPService *candidateService = nil;
    
    for (UPnPDevice *device in self.devices) {
        for (UPnPService *service in device.services) {
            if ([service.subscriptionID isEqualToString:subscriptionID]) {
                candidateService = service;
                break;
            }
        }
    }
    
    return candidateService;
}

@end
