//
//  NetworkingSource.m
//  Networking
//
//  Created by Rob McBroom on 2012/03/16.
//

#import "NetworkingSource.h"
#import <sys/socket.h>
#import <ifaddrs.h>
#import <netdb.h>

@implementation QSNetworkingSource

#pragma mark Object Source

- (BOOL)indexIsValidFromDate:(NSDate *)indexDate forEntry:(NSDictionary *)theEntry
{
	return YES;
}

- (NSImage *)iconForEntry:(NSDictionary *)dict
{
	return [QSResourceManager imageNamed:@"GenericNetworkIcon"];
}

- (NSArray *) objectsForEntry:(NSDictionary *)theEntry
{
	return nil;
}

#pragma mark Proxy Objects

- (QSObject *)resolveProxyObject:(id)proxy
{
	// local IP address
	if ([[proxy identifier] isEqualToString:@"QSNetworkIPAddressProxy"]) {
		NSMutableArray *addresses = [NSMutableArray arrayWithCapacity:1];
		NSString *testaddr;
		struct ifaddrs *addr0, *addr;
		NSInteger family, result;
		char ipaddr[NI_MAXHOST];
		if (getifaddrs(&addr0) == -1) {
			return nil;
		}
		for (addr = addr0; addr != NULL; addr = addr->ifa_next) {
			family = addr->ifa_addr->sa_family;
			if (family == AF_INET) {
				result = getnameinfo(addr->ifa_addr, sizeof(struct sockaddr_in), ipaddr, NI_MAXHOST, NULL, 0, NI_NUMERICHOST);
				if (result == 0) {
					testaddr = [NSString stringWithCString:ipaddr encoding:NSUTF8StringEncoding];
					if ([testaddr hasPrefix:@"127."]) {
						continue;
					}
					[addresses addObject:testaddr];
				}
			}
		}
		QSObject *localIP = [QSObject makeObjectWithIdentifier:@"QSNetworkIPAddress"];
		[localIP setName:@"IP Address"];
		[localIP setDetails:[addresses componentsJoinedByString:@", "]];
		[localIP setObject:[addresses componentsJoinedByString:@" "] forType:QSTextType];
		[localIP setIcon:[QSResourceManager imageNamed:@"GenericNetworkIcon"]];
		return localIP;
	}
	// remote IP address
	if ([[proxy identifier] isEqualToString:@"QSNetworkExternalIPProxy"]) {
		NSString *externalIPSource = [[NSUserDefaults standardUserDefaults] objectForKey:@"QSExternalIPSource"];
		NSURL *IPService = [NSURL URLWithString:externalIPSource];
		NSURLRequest *req = [NSURLRequest requestWithURL:IPService cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5];
		NSURLResponse *response;
		NSError *error = nil;
		NSData *contentData = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&error];
		if (error) {
			NSLog(@"Error retrieving external IP address: %@", error);
			NSBeep();
			return nil;
		}
		NSString *content = [[[NSString alloc] initWithData:contentData encoding:NSUTF8StringEncoding] autorelease];
		content = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		NSRegularExpression *ipRegEx = [NSRegularExpression regularExpressionWithPattern:@"^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$" options:0 error:nil];
		NSUInteger matches = [ipRegEx numberOfMatchesInString:content options:0 range:NSMakeRange(0, content.length)];
		// return the first match
		if (matches) {
			QSObject *externalIP = [QSObject makeObjectWithIdentifier:@"QSNetworkExternalIP"];
			[externalIP setName:@"External IP Address"];
			[externalIP setDetails:content];
			[externalIP setObject:content forType:QSTextType];
			[externalIP setIcon:[QSResourceManager imageNamed:@"GenericNetworkIcon"]];
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
