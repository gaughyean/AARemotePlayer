//
//  UPnPDevice.m
//  AARemotePlayer
//
//  Created by AAMac on 2017/4/20.
//  Copyright © 2017年 Gavin Tsang. All rights reserved.
//

#import "UPnPDevice.h"
#import "UPnPService.h"

static NSString *const kDeviceType                 = @"deviceType";
static NSString *const kDeviceFriendlyName         = @"friendlyName";
static NSString *const kDeviceManufacturer         = @"manufacturer";
static NSString *const kDeviceManufacturerURL      = @"manufacturerURL";
static NSString *const kDeviceModelDescription     = @"modelDescription";
static NSString *const kDeviceModelName            = @"modelName";
static NSString *const kDeviceModelNumber          = @"modelNumber";
static NSString *const kDeviceModelURL             = @"modelURL";
static NSString *const kDeviceSerialNumber         = @"serialNumber";
static NSString *const kDeviceUniqueDeviceName     = @"UDN";
static NSString *const kDeviceUniversalProductCode = @"UPC";
static NSString *const kDeviceIconList             = @"iconList";
static NSString *const kDeviceIconListIcon         = @"icon";
static NSString *const kDeviceIconURL              = @"url";
static NSString *const kDeviceServiceList          = @"serviceList";
static NSString *const kDeviceServiceListService   = @"service";
static NSString *const kDeviceDeviceList           = @"deviceList";
static NSString *const kDeviceDeviceListDevice     = @"device";
static NSString *const kDevicePresentationURL      = @"presentationURL";

@interface UPnPService (PrivatePropertiesRWSupport)

@property (nonatomic, strong) NSString *serviceID;
@property (nonatomic, strong) NSString *serviceType;
@property (nonatomic, strong) NSURL    *eventSubURL;
@property (nonatomic, strong) NSURL    *controlURL;
@property (nonatomic, strong) NSURL    *descriptionURL;

@end

@interface UPnPDevice ()<NSXMLParserDelegate>

@property (nonatomic, strong) UPnPService * currentService;

@property (strong, nonatomic) NSRecursiveLock * parserLock;

@property (nonatomic, strong) NSMutableSet * mutableServices;

@property (nonatomic, strong) NSMutableSet * mutableIconURLs;

@property (nonatomic, strong) NSMutableString * currentStringValue;

@property (strong, nonatomic) NSXMLParser * parser;

@property (atomic, assign) BOOL descriptionURLIsNew;

@property (nonatomic, strong, readonly) NSURL * baseURL;

@end

static dispatch_queue_t upnp_device_xml_parser_queue() {
    static dispatch_queue_t _upnp_device_xml_parser_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _upnp_device_xml_parser_queue = dispatch_queue_create("com.AA.UPnP.UPnPDevice.XMLParser", DISPATCH_QUEUE_CONCURRENT);
    });
    
    return _upnp_device_xml_parser_queue;
}

@implementation UPnPDevice

@synthesize parser = _parser;

- (instancetype)initWithUniversalDeviceNumber:(NSString *)udn {
    if (self = [super init]) {
        _udn = udn;
        self.parserLock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

#pragma mark - setter & getter

- (void)setDescriptionURL:(NSURL *)descriptionURL {
    if ([self url:_descriptionURL isEqualToUrl:descriptionURL ignorePort:NO]) {
        return;
    }
    
    if (_descriptionURL && descriptionURL) {
#ifdef DEBUG
       NSLog(@"CAUTION: %@'s Description file location changed from [%@] to [%@]", self.friendlyName, _descriptionURL, descriptionURL);
#endif
    }

    self.descriptionURLIsNew = YES;
    
    _descriptionURL = descriptionURL;
    
    if (descriptionURL) {
        _baseURL = [[NSURL URLWithString:@"/" relativeToURL:descriptionURL] absoluteURL];
    }    
}

- (void)setParser:(NSXMLParser *)parser {
    if (_parser == parser) {
        return;
    }
    
    [self.parserLock lock];
    NSXMLParser *oldParser = _parser;
    _parser = parser;
    
    if (oldParser) {
        [oldParser abortParsing];
        oldParser.delegate = nil;
    }
    [self.parserLock unlock];
}

- (NSXMLParser *)parser {
    NSXMLParser *parser = nil;
    
    [self.parserLock lock];
    parser = _parser;
    [self.parserLock unlock];
    
    return parser;
}

- (NSSet *)services {
    return self.mutableServices;
}

- (NSMutableSet *)mutableServices {
    if (!_mutableServices) {
        _mutableServices = [NSMutableSet set];
    }
    
    return _mutableServices;
}

- (NSMutableSet *)mutableIconURLs {
    if (!_mutableIconURLs) {
        _mutableIconURLs = [NSMutableSet set];
    }
    
    return _mutableIconURLs;
}

- (NSMutableString *)currentStringValue {
    if (!_currentStringValue) {
        _currentStringValue = [NSMutableString string];
    }
    
    return _currentStringValue;
}

#pragma mark - helper methods

- (BOOL)url:(NSURL *)url isEqualToUrl:(NSURL *)aURL ignorePort:(BOOL)ignorePort {
    if (url == nil) {
        return NO;
    }
    if ([url isEqual:aURL]) return YES;
    if ([url.scheme caseInsensitiveCompare:aURL.scheme] != NSOrderedSame) return NO;
    if ([url.host caseInsensitiveCompare:aURL.host] != NSOrderedSame) return NO;
    // NSURL path is smart about trimming trailing slashes
    // note case-sensitivty here
    if ([url.path compare:aURL.path] != NSOrderedSame) return NO;
    // at this point, we've established that the urls are equivalent according to the rfc
    // insofar as scheme, host, and paths match
    
    // according to rfc2616, port's can weakly match if one is missing and the
    // other is default for the scheme, but for now, let's insist on an explicit match
    if (!ignorePort) {
        if ([url.port compare:aURL.port] != NSOrderedSame) return NO;
    }
    
    if ([url.query compare:aURL.query] != NSOrderedSame) return NO;
    
#if URLStrictCompare
    // for things like user/pw, fragment, etc., seems sensible to be
    // permissive about these.  (plus, I'm tired :-))
    if ([url.fragment compare:aURL.fragment] != NSOrderedSame) return NO;
    
    if ([url.user compare:aURL.user] != NSOrderedSame) return NO;
    
    if ([url.password compare:aURL.path] != NSOrderedSame) return NO;
#endif
    return YES;
}

#pragma mark - public methods

- (NSString *)description {
    NSMutableString *description = [NSMutableString string];
    [description appendString:[NSString stringWithFormat:@"\n\t%@[%p]:\n", NSStringFromClass([self class]), self]];
    [description appendString:[NSString stringWithFormat:@"\t\tudn:%@\n", self.udn]];
    [description appendString:[NSString stringWithFormat:@"\t\tdescriptionURL:%@\n", self.descriptionURL]];
    [description appendString:[NSString stringWithFormat:@"\t\tdeviceType:%@\n", self.deviceType]];
    [description appendString:[NSString stringWithFormat:@"\t\tfriendlyName:%@\n", self.friendlyName]];
    [description appendString:[NSString stringWithFormat:@"\t\tmanufacturer:%@\n", self.manufacturer]];
    [description appendString:[NSString stringWithFormat:@"\t\tmanufacturerURL:%@\n", self.manufacturerURL]];
    [description appendString:[NSString stringWithFormat:@"\t\tmodelDescription:%@\n", self.modelDescription]];
    [description appendString:[NSString stringWithFormat:@"\t\tmodelName:%@\n", self.modelName]];
    [description appendString:[NSString stringWithFormat:@"\t\tmodelNumber:%@\n", self.modelNumber]];
    [description appendString:[NSString stringWithFormat:@"\t\tmodelURL:%@\n", self.modelURL]];
    [description appendString:[NSString stringWithFormat:@"\t\tserialNumber:%@\n", self.serialNumber]];
    [description appendString:@"\t\tservices:\n"];
    
    for (int i = 0; i < self.mutableServices.count; i++) {
        UPnPService *service = self.mutableServices.allObjects[i];
        
        if (i != 0) {
            [description appendString:@"\t\t\tnextService>\n"];
        }
        
        [description appendString:[NSString stringWithFormat:@"\t\t\tserviceType:%@\n", service.serviceType]];
        [description appendString:[NSString stringWithFormat:@"\t\t\tserviceID:%@\n", service.serviceID]];
        [description appendString:[NSString stringWithFormat:@"\t\t\tSCPDURL:%@\n", service.descriptionURL]];
        [description appendString:[NSString stringWithFormat:@"\t\t\tcontrolURL:%@\n", service.controlURL]];
        [description appendString:[NSString stringWithFormat:@"\t\t\teventSubURL:%@\n", service.eventSubURL]];
        [description appendString:[NSString stringWithFormat:@"\t\t\tsubscriptionID:%@\n", service.subscriptionID]];
    }
    
    [description appendString:@"\n"];
    
    return description;
}

- (void)updateDeviceFromDescriptionURL:(NSURL *)descriptionURL andDate:(NSDate *)lastActivityDate andExpiration:(NSTimeInterval)expiration {
    self.descriptionURL = descriptionURL;
    if ([self.lastActivityDate compare:lastActivityDate] == NSOrderedAscending) {
        self.lastActivityDate = lastActivityDate;
    }
    self.expiration = expiration;
}

- (void)connect {
    if (!self.descriptionURLIsNew) {
        return;
    }
    if (self.state == UPnPDeviceStateDisconnected || self.state == UPnPDeviceStateReady) {
        __weak __typeof(self) weakSelf = self;
        
        void (^bgBlock)() = ^{
            NSURL *url = weakSelf.descriptionURL;
            [weakSelf getDeviceDescriptionFromURL:url];
        };
        
        dispatch_async(upnp_device_xml_parser_queue(), bgBlock);
    }
}

- (void)disConnect {
    [[NSNotificationCenter defaultCenter] postNotificationName:kUPnPDevicesHasRemovedNotificationName object:self];
    self.state = UPnPDeviceStateDisconnected;
    self.parser = nil;
}

#pragma mark - private method

- (void)getDeviceDescriptionFromURL:(NSURL *)descriptionURL {
    if (self.state == UPnPDeviceStateDisconnected || self.state == UPnPDeviceStateReady) {
        if (self.state == UPnPDeviceStateDisconnected) self.state = UPnPDeviceStateInitializing;
        self.descriptionURLIsNew = NO;
        self.parser = [[NSXMLParser alloc] initWithContentsOfURL:descriptionURL];
        self.parser.delegate = self;
        self.parser.shouldResolveExternalEntities = YES;
        [self.parser parse];
    }
}

- (void)addService:(UPnPService *)service {
    if (service) [self.mutableServices addObject:service];
}

#pragma mark - NSXMLParserDelegate
- (void)parserDidStartDocument:(NSXMLParser *)parser {
    self.currentStringValue = nil;
    self.currentService = nil;
    [self.mutableIconURLs removeAllObjects];
    [self.mutableServices removeAllObjects];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    if ([elementName caseInsensitiveCompare:kDeviceServiceList] == NSOrderedSame) {
        [self.mutableServices removeAllObjects];
    } else if ([elementName caseInsensitiveCompare:kDeviceServiceListService] == NSOrderedSame) {
        self.currentService = [[UPnPService alloc] initWithDevice:self];
    } else if ([elementName caseInsensitiveCompare:kDeviceIconList] == NSOrderedSame) {
        [self.mutableIconURLs removeAllObjects];
    }
    
#if UPnPSubDeviceSupport
    else if ([elementName caseInsensitiveCompare:kDeviceDeviceList] == NSOrderedSame) {
        self.mutableSubDevices = [NSMutableSet set];
    }
#endif
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if ([string containsString:@"\n"]) {
        return;
    }
    [self.currentStringValue appendString:string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if ([elementName caseInsensitiveCompare:kServiceType] == NSOrderedSame) {
        self.currentService.serviceType = [self.currentStringValue copy];
    } else if ([elementName caseInsensitiveCompare:kServiceID] == NSOrderedSame) {
        self.currentService.serviceID = [self.currentStringValue copy];
    } else if ([elementName caseInsensitiveCompare:kServiceEventSubscriptionURL] == NSOrderedSame) {
        self.currentService.eventSubURL = [NSURL URLWithString:self.currentStringValue relativeToURL:self.baseURL];
    } else if ([elementName caseInsensitiveCompare:kServiceControlURL] == NSOrderedSame) {
        self.currentService.controlURL = [NSURL URLWithString:self.currentStringValue relativeToURL:self.baseURL];
    } else if ([elementName caseInsensitiveCompare:kServiceDescriptionURL] == NSOrderedSame) {
        self.currentService.descriptionURL = [NSURL URLWithString:self.currentStringValue relativeToURL:self.baseURL];
    } else if ([elementName caseInsensitiveCompare:kDeviceServiceListService] == NSOrderedSame) {
        [self addService:self.currentService];
        self.currentService = nil;
    } else if ([elementName caseInsensitiveCompare:kDeviceIconURL] == NSOrderedSame) {
        NSURL *url = [NSURL URLWithString:self.currentStringValue relativeToURL:self.baseURL];
        if (url) [self.mutableIconURLs addObject:url];
    } else if ([elementName caseInsensitiveCompare:kDeviceDeviceList] == NSOrderedSame) {
//        NSLog(@"devices");
    } else if ([elementName caseInsensitiveCompare:kDeviceManufacturerURL] == NSOrderedSame) {
        _manufacturerURL = [NSURL URLWithString:self.currentStringValue relativeToURL:self.baseURL];
    } else if ([elementName caseInsensitiveCompare:kDeviceModelDescription] == NSOrderedSame) {
        _modelDescription = [self.currentStringValue copy];
    } else if ([elementName caseInsensitiveCompare:kDeviceModelName] == NSOrderedSame) {
        _modelName = [self.currentStringValue copy];
    } else if ([elementName caseInsensitiveCompare:kDeviceModelNumber] == NSOrderedSame) {
        _modelNumber = [self.currentStringValue copy];
    } else if ([elementName caseInsensitiveCompare:kDeviceModelURL] == NSOrderedSame) {
        _modelURL = [NSURL URLWithString:self.currentStringValue relativeToURL:self.baseURL];
    } else if ([elementName caseInsensitiveCompare:kDeviceSerialNumber] == NSOrderedSame) {
        _serialNumber = [self.currentStringValue copy];
    } else if ([elementName caseInsensitiveCompare:kDeviceUniqueDeviceName] == NSOrderedSame) {
//        _udn = [self.currentStringValue copy];
    } else if ([elementName caseInsensitiveCompare:kDeviceUniversalProductCode] == NSOrderedSame) {
        _universalProductCode = [self.currentStringValue copy];
    } else if ([elementName caseInsensitiveCompare:kDeviceManufacturer] == NSOrderedSame) {
        _manufacturer = [self.currentStringValue copy];
    } else if ([elementName caseInsensitiveCompare:kDeviceFriendlyName] == NSOrderedSame) {
        [self willChangeValueForKey:@"friendlyName"];
        _friendlyName = [self.currentStringValue copy];
        [self didChangeValueForKey:@"friendlyName"];
    } else if ([elementName caseInsensitiveCompare:kDeviceType] == NSOrderedSame) {
        _deviceType = [self.currentStringValue copy];
    } else if ([elementName caseInsensitiveCompare:kDevicePresentationURL] == NSOrderedSame) {
        _presentationURL = [NSURL URLWithString:self.currentStringValue relativeToURL:self.baseURL];
    }
    
    self.currentStringValue = nil;
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
#ifdef DEBUG
    NSLog(@"parseError = %@", parseError);
#endif
    self.parser = nil;
    self.state = UPnPDeviceStateFailed;
}

- (void)parserDidEndDocument:(NSXMLParser *)parser {
    [[NSNotificationCenter defaultCenter] postNotificationName:kUPnPDevicesHasAddedNotificationName object:self];
    self.state = UPnPDeviceStateReady;
    self.parser = nil;
}


@end
