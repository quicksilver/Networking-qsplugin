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
		return localIP;
	}
	// remote IP address
	if ([[proxy identifier] isEqualToString:@"QSNetworkExternalIPProxy"]) {
		NSURL *IPService = [NSURL URLWithString:@"http://qs0.qsapp.com/plugin-data/external-ip.php"];
		NSURLRequest *req = [NSURLRequest requestWithURL:IPService cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5];
		NSURLResponse *response;
		NSError *error;
		NSData *contentData = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&error];
		NSString *content = [[[NSString alloc] initWithData:contentData encoding:NSUTF8StringEncoding] autorelease];
		// poor man's parsing :-)
		NSString *ipRegEx = @"^[:number:]{1,3}\\.[:number:]{1,3}\\.[:number:]{1,3}\\.[:number:]{1,3}$";
		NSPredicate *ipFilter = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", ipRegEx];
		// change all tags from <tag>blah</tag> to |tag|blah|/tag|
		// replace whitespace with | as well
		//NSArray *replacements = [NSArray arrayWithObjects:@"<", @">", @" ", @"\n", nil];
		//for (NSString *replace in replacements) {
		//	content = [content stringByReplacingOccurrencesOfString:replace withString:@"|"];
		//}
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
