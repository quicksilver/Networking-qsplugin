#import "QSAirPortProvider.h"
#import <CoreWLAN/CoreWLAN.h>

NSArray *getAvailableNetworks(void)
{
    // scan for currently available wireless networks
    // retrun the entire network object
    NSMutableArray *available = [NSMutableArray arrayWithCapacity:1];
    NSError *error = nil;
    CWInterface *wif = [CWInterface interface];
    for (CWNetwork *net in [wif scanForNetworksWithParameters:nil error:&error])
    {
        [available addObject:net];
    }
    return available;
}

NSInteger sortNetworkObjects(QSObject *net1, QSObject *net2, void *context)
{
    NSNumber *n1 = [net1 objectForMeta:@"priority"];
    NSNumber *n2 = [net2 objectForMeta:@"priority"];
    // reverse the sort order
    if ([n1 isEqualToNumber:n2]) {
        return NSOrderedSame;
    } else if ([n1 compare:n2] == NSOrderedDescending) {
        return NSOrderedAscending;
    } else {
        return NSOrderedDescending;
    }
}

@implementation QSAirPortNetworkObjectSource

- (NSImage *)iconForEntry:(NSDictionary *)dict
{
    return [QSResourceManager imageNamed:@"com.apple.airport.airportutility"];
}

- (NSArray *)objectsForEntry:(NSDictionary *)theEntry
{
    // create a virtual object representing the wireless interface
	QSObject *wireless;
	if ([NSApplication isLion]) {
		// AirPort is called Wi-Fi in 10.7+
		wireless = [QSObject objectWithName:@"Wi-Fi"];
		[wireless setDetails:@"Wi-Fi Networks"];
		[wireless setObject:@"Virtual Wi-Fi Object" forType:kQSAirPortItemType];
	} else {
		wireless = [QSObject objectWithName:@"AirPort"];
		[wireless setDetails:@"AirPort Wireless Networks"];
		[wireless setObject:@"Virtual AirPort Object" forType:kQSAirPortItemType];
	}
    [wireless setIcon:[QSResourceManager imageNamed:@"com.apple.airport.airportutility"]];
    [wireless setIdentifier:@"AirPortNetworks"];
    [wireless setPrimaryType:kQSAirPortItemType];
    return [NSArray arrayWithObject:wireless];
}

- (BOOL)objectHasChildren:(QSObject *)object
{
    // only the virtual wireless object has children (not the networks)
    // nothing to list if the interface is powered off
    return ([object containsType:kQSAirPortItemType] && [[CWInterface interface] power]);
}

- (BOOL)loadChildrenForObject:(QSObject *)object
{
    if ([object containsType:kQSAirPortItemType])
    {
		NSString *technologyName = [NSApplication isLion] ? @"Wi-Fi" : @"AirPort";
        NSMutableArray *objects = [NSMutableArray arrayWithCapacity:1];
        QSObject *newObject = nil;
        NSArray *networks = getAvailableNetworks(); 
        for(CWNetwork *net in networks)
        {
            NSString *ssid = net.ssid;
            NSNumber *priority = net.rssi;
            NSString *securityString = @"Secure ";
            // this should use kCWSecurityModeOpen instead of 0, but that constant seems to be (null)
            if ([net.securityMode intValue] == 0) {
                securityString = @"";
            }
            if (net.wirelessProfile)
            {
                // indicate that this is a preferred network
                newObject = [QSObject objectWithName:[NSString stringWithFormat:@"%@ ★", ssid]];
                [newObject setDetails:[NSString stringWithFormat:@"%@%@ Network (Preferred)", securityString, technologyName]];
                // artificially inflate the priority for preferred networks
                priority = [NSNumber numberWithInt:[priority intValue] + 1000];
            } else {
                // just use the name
                newObject = [QSObject objectWithName:ssid];
                [newObject setDetails:[NSString stringWithFormat:@"%@%@ Network", securityString, technologyName]];
            }
            [newObject setObject:priority forMeta:@"priority"];
            [newObject setObject:net forType:kQSWirelessNetworkType];
            [newObject setPrimaryType:kQSWirelessNetworkType];
            [newObject setParentID:[object identifier]];
            int signal = [net.rssi intValue];
            if (signal > -70) {
                [newObject setIcon:[QSResourceManager imageNamed:@"AirPort" inBundle:[NSBundle bundleForClass:[self class]]]];
            } else if (signal > -80) {
                [newObject setIcon:[QSResourceManager imageNamed:@"AirPort3" inBundle:[NSBundle bundleForClass:[self class]]]];
            } else if (signal > -90) {
                [newObject setIcon:[QSResourceManager imageNamed:@"AirPort2" inBundle:[NSBundle bundleForClass:[self class]]]];
            } else if (signal > -100) {
                [newObject setIcon:[QSResourceManager imageNamed:@"AirPort1" inBundle:[NSBundle bundleForClass:[self class]]]];
            } else {
                [newObject setIcon:[QSResourceManager imageNamed:@"AirPort0" inBundle:[NSBundle bundleForClass:[self class]]]];
            }
            [objects addObject:newObject];
        }
        [object setChildren:[objects sortedArrayUsingFunction:sortNetworkObjects context:NULL]];
        return YES;
    }
	return NO;
}

- (void)setQuickIconForObject:(QSObject *)object
{
    [object setIcon:[QSResourceManager imageNamed:@"com.apple.airport.airportutility"]];
}
@end

@implementation QSAirPortNetworkActionProvider

- (id)init
{
	self = [super init];
	if (self) {
		NSString *technologyName = [NSApplication isLion] ? @"Wi-Fi" : @"AirPort";
		NSString *powerOn = [NSString stringWithFormat:@"Turn %@ On", technologyName];
		NSString *powerOff = [NSString stringWithFormat:@"Turn %@ Off", technologyName];
		[(QSAction *)[QSAction actionWithIdentifier:@"QSAirPortPowerEnable"] setName:powerOn];
		[(QSAction *)[QSAction actionWithIdentifier:@"QSAirPortPowerDisable"] setName:powerOff];
	}
	return self;
}

- (QSObject *)enableAirPort
{
    NSError *error = nil;
    CWInterface *wif = [CWInterface interface];
    BOOL setPowerSuccess = [wif setPower:YES error:&error];
    if (! setPowerSuccess) {
        NSLog(@"error enabling wireless interface: %@", error);
    }
    return nil;
}

- (QSObject *)disableAirPort
{
    NSError *error = nil;
    CWInterface *wif = [CWInterface interface];
    BOOL setPowerSuccess = [wif setPower:NO error:&error];
    if (! setPowerSuccess) {
        NSLog(@"error disabling wireless interface: %@", error);
    }
    return nil;
}

- (QSObject *)disassociateAirPort
{
    [[CWInterface interface] disassociate];
    return nil;
}

- (QSObject *)selectNetwork:(QSObject *)dObject
{
#ifdef DEBUG
    NSLog(@"Switching to network: \"%@\"", [dObject name]);
#endif
    
    NSError *error = nil;
    CWInterface *wif = [CWInterface interface];
    CWNetwork *net = [dObject objectForType:kQSWirelessNetworkType];
    NSString *passphrase = [net.wirelessProfile passphrase];
    NSDictionary *params = nil;
    if (passphrase != nil) {
        params = [NSDictionary dictionaryWithObjectsAndKeys:passphrase, kCWAssocKeyPassphrase, nil];
    }
    
    [wif associateToNetwork:net parameters:params error:&error];
    
    return nil;
}

- (QSObject *)connectNewNetwork:(QSObject *)dObject
{    
    CWNetwork *net = [dObject objectForType:kQSWirelessNetworkType];
    NSString *scriptPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AirPort" ofType:@"scpt"];
    NSAppleScript *script = [[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:scriptPath] error:nil];
    [script executeSubroutine:@"connect_to_network" arguments:[NSArray arrayWithObjects:net.ssid, nil] error:nil];
#ifdef DEBUG
    NSLog(@"Connecting to new network: \"%@\"", net.ssid);
    NSLog(@"ApleScript path: %@", scriptPath);
#endif
    return nil;
}

- (NSArray *)validActionsForDirectObject:(QSObject *)dObject indirectObject:(QSObject *)iObject
{
    if ([dObject containsType:kQSAirPortItemType]) {
        // the wireless interface object
        CWInterface *wif = [CWInterface interface];
        if([wif power])
        {
            return [NSArray arrayWithObjects:@"QSAirPortPowerDisable", @"QSAirPortDisassociate", nil];
        } else {
            return [NSArray arrayWithObject:@"QSAirPortPowerEnable"];
        }
    } else if ([dObject containsType:kQSWirelessNetworkType]) {
        // a wireless network
        CWNetwork *net = [dObject objectForType:kQSWirelessNetworkType];
        if (net.wirelessProfile) {
            // preferred network
            return [NSArray arrayWithObject:@"QSAirPortNetworkSelectAction"];
        } else {
            return [NSArray arrayWithObject:@"QSAirPortNetworkNewConnection"];
        }

    }
    return nil;
}
@end
