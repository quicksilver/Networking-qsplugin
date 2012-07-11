#import "QSNetworkLocationSource.h"

@implementation QSNetworkLocationObjectSource

- (id)init
{
	if (self = [super init]) {
		[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(networkChange:) name:@"com.apple.system.config.network_change" object:nil];
	}
	return self;
}

- (void)networkChange:(NSNotification *)notif
{
	NSLog(@"Quicksilver observed a network location change");
}

- (BOOL)indexIsValidFromDate:(NSDate *)indexDate forEntry:(NSDictionary *)theEntry
{
	NSDate *modDate = [[[NSFileManager defaultManager] attributesOfItemAtPath:[@"/Library/Preferences/SystemConfiguration/preferences.plist" stringByResolvingSymlinksInPath] error:nil] fileModificationDate];
	return [modDate compare:indexDate] == NSOrderedAscending;
}

- (NSImage *) iconForEntry:(NSDictionary *)dict
{
    return [QSResourceManager imageNamed:@"GenericNetworkIcon"];
}

- (NSArray *)objectsForEntry:(NSDictionary *)theEntry
{
	NSMutableArray *objects = [NSMutableArray arrayWithCapacity:1];
	QSObject *newObject;
	NSDictionary *networkLocations = [[NSDictionary dictionaryWithContentsOfFile:@"/Library/Preferences/SystemConfiguration/preferences.plist"] objectForKey:@"Sets"];
	NSString *locationName = nil;
	for (NSString *key in networkLocations) {
		locationName = [[networkLocations objectForKey:key] objectForKey:@"UserDefinedName"];
		newObject = [QSObject makeObjectWithIdentifier:[NSString stringWithFormat:@"[Network Location]:%@", key]];
		[newObject setName:[NSString stringWithFormat:@"%@ Network Location", locationName]];
		[newObject setDetails:[NSString stringWithFormat:@"%@ Network Location", locationName]];
		[newObject setLabel:locationName];
		[newObject setObject:key forType:QSNetworkLocationPasteboardType];
		[newObject setPrimaryType:QSNetworkLocationPasteboardType];
		[objects addObject:newObject];
	}
	return objects;
}

- (void)setQuickIconForObject:(QSObject *)object
{
	[object setIcon:[QSResourceManager imageNamed:@"GenericNetworkIcon"]];
}
@end





#define kQSNetworkLocationSelectAction @"QSNetworkLocationSelectAction"


@implementation QSNetworkLocationActionProvider
//- (NSArray *) types{
//    return [NSArray arrayWithObject:QSNetworkLocationPasteboardType];
//}
//- (NSArray *) actions{
//    QSAction *action=[QSAction actionWithIdentifier:kQSNetworkLocationSelectAction];
//    [action setIcon:[QSResourceManager imageNamed:@"GenericNetworkIcon"]];
//    [action setProvider:self];
//    [action setAction:@selector(selectNetwork:)];
//    [action setArgumentCount:1];
//    return [NSArray arrayWithObject:action];
//}
//
//- (NSArray *)validActionsForDirectObject:(QSObject *)dObject indirectObject:(QSObject *)iObject{
//    return [NSArray arrayWithObject:kQSNetworkLocationSelectAction];
//}

- (QSObject *)selectNetwork:(QSObject *)dObject
{
	NSString *location = [dObject objectForType:QSNetworkLocationPasteboardType];
	NSTask *setNetTask = [[[NSTask alloc] init] autorelease];
	[setNetTask setLaunchPath:@"/usr/sbin/scselect"];
	[setNetTask setArguments:[NSArray arrayWithObject:location]];
	[setNetTask launch];
	[setNetTask waitUntilExit];
	
	QSShowNotifierWithAttributes([NSDictionary dictionaryWithObjectsAndKeys:@"QSiTunesTrackChangeNotification", QSNotifierType, @"Network Changed", QSNotifierTitle, [dObject name], QSNotifierText, [QSResourceManager imageNamed:@"GenericNetworkIcon"], QSNotifierIcon, nil]);
	return nil;
}
@end
