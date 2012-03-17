//
//  NetworkingSource.m
//  Networking
//
//  Created by Rob McBroom on 2012/03/16.
//

#import "NetworkingSource.h"

@implementation QSNetworkingSource

#pragma mark Object Source

- (BOOL)indexIsValidFromDate:(NSDate *)indexDate forEntry:(NSDictionary *)theEntry
{
	return NO;
}

- (NSImage *)iconForEntry:(NSDictionary *)dict
{
	return [QSResourceManager imageNamed:@"GenericNetworkIcon"];
}

// Return a unique identifier for an object (if you haven't assigned one before)
//- (NSString *)identifierForObject:(id <QSObject>)object
//{
//	return nil;
//}

- (NSArray *) objectsForEntry:(NSDictionary *)theEntry
{
	NSMutableArray *objects=[NSMutableArray arrayWithCapacity:1];
	QSObject *newObject;
	
	newObject=[QSObject objectWithName:@"TestObject"];
	[newObject setObject:@"" forType:QSNetworkingType];
	[newObject setPrimaryType:QSNetworkingType];
	[objects addObject:newObject];
	
	return objects;
}

#pragma mark Proxy Objects

- (QSObject *)resolveProxyObject:(id)proxy
{
	// local IP address
	if ([[proxy identifier] isEqualToString:@"QSNetworkIPAddressProxy"]) {
		NSMutableArray *addresses = [NSMutableArray arrayWithCapacity:1];
		for (NSString *addr in [[NSHost currentHost] addresses]) {
			NSArray *octets = [addr componentsSeparatedByString:@"."];
			if ([[octets objectAtIndex:0] isEqualToString:@"127"]) {
				continue;
			}
			if ([octets count] == 4) {
				[addresses addObject:addr];
			}
		}
		QSObject *localIP = [QSObject makeObjectWithIdentifier:@"QSNetworkIPAddress"];
		[localIP setName:@"IP Address"];
		[localIP setDetails:[addresses componentsJoinedByString:@", "]];
		[localIP setObject:[addresses componentsJoinedByString:@" "] forType:QSTextType];
		return localIP;
	}
	// remote IP address
	if ([[proxy identifier] isEqualToString:@"QSNetworkExternalIPProxy"]) {
		NSURL *IPService = [NSURL URLWithString:@"http://checkip.dyndns.org/"];
		NSURLRequest *req = [NSURLRequest requestWithURL:IPService cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5];
		NSURLResponse *response;
		NSError *error;
		NSData *contentData = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&error];
		NSString *content = [[NSString alloc] initWithData:contentData encoding:NSUTF8StringEncoding];
		// poor man's parsing :-)
		NSString *ipRegEx = @"^[:number:]{1,3}\\.[:number:]{1,3}\\.[:number:]{1,3}\\.[:number:]{1,3}$";
		NSPredicate *ipFilter = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", ipRegEx];
		// change all tags from <tag>blah</tag> to |tag|blah|/tag|
		// replace whitespace with | as well
		NSArray *replacements = [NSArray arrayWithObjects:@"<", @">", @" ", @"\n", nil];
		for (NSString *replace in replacements) {
			content = [content stringByReplacingOccurrencesOfString:replace withString:@"|"];
		}
		// split on | and look for an IP address
		NSArray *contentParts = [content componentsSeparatedByString:@"|"];
		NSArray *IPs = [contentParts filteredArrayUsingPredicate:ipFilter];
		// return the first match
		if ([IPs count]) {
			QSObject *externalIP = [QSObject makeObjectWithIdentifier:@"QSNetworkExternalIP"];
			[externalIP setName:@"External IP Address"];
			[externalIP setDetails:[IPs objectAtIndex:0]];
			[externalIP setObject:[IPs objectAtIndex:0] forType:QSTextType];
			return externalIP;
		}
	}
	return nil;
}

// Object Handler Methods

/*
- (void)setQuickIconForObject:(QSObject *)object
{
	[object setIcon:nil]; // An icon that is either already in memory or easy to load
}

- (BOOL)loadIconForObject:(QSObject *)object
{
	return NO;
	id data=[object objectForType:QSNetworkingType];
	[object setIcon:nil];
	return YES;
}
*/
@end
