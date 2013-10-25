#import "QSAirPortProvider.h"
#import <CoreWLAN/CoreWLAN.h>

// Taken from http://stackoverflow.com/questions/4869416/keychain-access-required-for-displaying-list-of-known-wifi-networks-in-osx-app
BOOL networkIsPreferredForInterface(CWNetwork *network, CWInterface *wif) {
    NSOrderedSet *profiles = wif.configuration.networkProfiles;
    for (CWNetworkProfile *profile in profiles) {
        if ([network.ssid isEqualToString:profile.ssid] && [network.ssidData isEqualToData:profile.ssidData] && [network supportsSecurity:profile.security]) {
            return YES;
        }
    }
    return NO;
}

BOOL isEnterpriseNetwork(CWNetwork *network) {
 
    return [network supportsSecurity:kCWSecurityWPAEnterprise] || [network supportsSecurity:kCWSecurityWPAEnterpriseMixed] || [network supportsSecurity:kCWSecurityWPA2Enterprise] || [network supportsSecurity:kCWSecurityEnterprise];
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



-(NSArray *)availableNetworksForInterface:(CWInterface *)wif {
    // scan for currently available wireless networks
    // retrun the entire network object
    NSMutableArray *available = [NSMutableArray arrayWithCapacity:1];
    NSError *error = nil;
    NSSet *networks = [wif scanForNetworksWithSSID:nil error:&error];
    if (error) {
        QSShowAppNotifWithAttributes(@"AirportPlugin", NSLocalizedStringFromTableInBundle(@"Airport Scanning Failed", nil, [NSBundle bundleForClass:[self class]], nil), [error localizedDescription]);
        return nil;
    }
    for (CWNetwork *net in networks)
    {
        [available addObject:net];
    }
    return available;
}

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
    return ([object containsType:kQSAirPortItemType] && [[CWInterface interface] powerOn]);
}

- (BOOL)loadChildrenForObject:(QSObject *)object
{
    if ([object containsType:kQSAirPortItemType])
    {
		NSString *technologyName = [NSApplication isLion] ? @"Wi-Fi" : @"AirPort";
        NSMutableArray *objects = [NSMutableArray arrayWithCapacity:1];
        QSObject *newObject = nil;
        CWInterface *wif = [CWInterface interface];
        NSArray *networks = [self availableNetworksForInterface:wif];
        for(CWNetwork *net in networks)
        {
            NSString *ssid = net.ssid;
            NSInteger priority = net.rssiValue;
            // this should use kCWSecurityModeOpen instead of 0, but that constant seems to be (null)
            NSString *securityString = [net supportsSecurity:kCWSecurityNone] ? @"" : @"Secure ";
            if (networkIsPreferredForInterface(net, wif))
            {
                // indicate that this is a preferred network
                newObject = [QSObject objectWithName:[NSString stringWithFormat:@"%@ ★", ssid]];
                [newObject setDetails:[NSString stringWithFormat:@"%@%@ Network (Preferred)", securityString, technologyName]];
                // artificially inflate the priority for preferred networks
                priority = priority + 1000;
            } else {
                // just use the name
                newObject = [QSObject objectWithName:ssid];
                [newObject setDetails:[NSString stringWithFormat:@"%@%@ Network", securityString, technologyName]];
            }
            [newObject setObject:[NSNumber numberWithInteger:priority] forMeta:@"priority"];
            [newObject setObject:net forType:kQSWirelessNetworkType];
            [newObject setPrimaryType:kQSWirelessNetworkType];
            [newObject setParentID:[object identifier]];
            NSInteger signal = net.rssiValue;
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

- (QSObject *)toggleAirPort
{
    NSError *error = nil;
    CWInterface *wif = [CWInterface interface];
    BOOL setPowerSuccess = [wif setPower:![wif powerOn] error:&error];
    if (! setPowerSuccess) {
        NSLog(@"error toggling wireless interface power: %@", error);
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
    
    CWInterface *wif = [CWInterface interface];
    CWNetwork *net = [dObject objectForType:kQSWirelessNetworkType];
    OSStatus err = 0;
    if (isEnterpriseNetwork(net)) {
        SecIdentityRef identity = nil;
        err = CWKeychainCopyEAPIdentity((CFDataRef)net.ssidData, &identity);
        if (!err) {
            NSString *username = nil;
            NSString *password = nil;
            err = CWKeychainCopyEAPUsernameAndPassword((CFDataRef)net.ssidData, (CFStringRef *)&username, (CFStringRef *)&password);
            if (!err) {
                NSError *error;
                [wif associateToEnterpriseNetwork:net identity:identity username:username password:password error:&error];
                if (error) {
                    NSLog(@"Failed to connect to network %@\%@", net.bssid, error);
                }
            }
            [username release];
            [password release];
            if (identity != nil) {
                CFRelease(identity);
            }
        }
    } else {
        NSString *password = nil;
        if (![net supportsSecurity:kCWSecurityNone]) {
            CWKeychainCopyPassword((CFDataRef)net.ssidData, (CFStringRef *)&password);
            [password autorelease];
        }
        NSError *error = nil;
        [wif associateToNetwork:net password:password error:&error];
        if (error) {
            NSLog(@"Failed to connect to network %@\%@", net.bssid, error);
        }
    }
    return nil;
}

- (QSObject *)connectNewNetwork:(QSObject *)dObject
{    
    CWNetwork *net = [dObject objectForType:kQSWirelessNetworkType];
    NSString *scriptPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AirPort" ofType:@"scpt"];
    NSAppleScript *script = [[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:scriptPath] error:nil];
	NSString *technologyName = [NSApplication isLion] ? @"Wi-Fi" : @"AirPort";
    [script executeSubroutine:@"connect_to_network" arguments:[NSArray arrayWithObjects:net.ssid, technologyName, nil] error:nil];
#ifdef DEBUG
    NSLog(@"Connecting to new network: \"%@\"", net.ssid);
    NSLog(@"ApleScript path: %@", scriptPath);
#endif
	[script release];
    return nil;
}

- (NSArray *)validActionsForDirectObject:(QSObject *)dObject indirectObject:(QSObject *)iObject
{
    CWInterface *wif = [CWInterface interface];
    if ([dObject containsType:kQSAirPortItemType]) {
        // the wireless interface object
		NSString *technologyName = [NSApplication isLion] ? @"Wi-Fi" : @"AirPort";
		NSMutableArray *actions = [NSMutableArray arrayWithObject:@"QSAirPortPowerToggle"];
		NSString *toggle = [NSString stringWithFormat:@"Toggle %@ Power", technologyName];
		[(QSAction *)[QSAction actionWithIdentifier:@"QSAirPortPowerToggle"] setName:toggle];
        if([wif powerOn])
        {
			NSString *powerOff = [NSString stringWithFormat:@"Turn %@ Off", technologyName];
			[(QSAction *)[QSAction actionWithIdentifier:@"QSAirPortPowerDisable"] setName:powerOff];
			[actions addObject:@"QSAirPortPowerDisable"];
			[actions addObject:@"QSAirPortDisassociate"];
        } else {
			NSString *powerOn = [NSString stringWithFormat:@"Turn %@ On", technologyName];
			[(QSAction *)[QSAction actionWithIdentifier:@"QSAirPortPowerEnable"] setName:powerOn];
			[actions addObject:@"QSAirPortPowerEnable"];
        }
		return actions;
    } else if ([dObject containsType:kQSWirelessNetworkType]) {
        // a wireless network
        CWNetwork *net = [dObject objectForType:kQSWirelessNetworkType];
        if (networkIsPreferredForInterface(net, wif)) {
            // preferred network
            return [NSArray arrayWithObject:@"QSAirPortNetworkSelectAction"];
        } else {
            return [NSArray arrayWithObject:@"QSAirPortNetworkNewConnection"];
        }

    }
    return nil;
}
@end
