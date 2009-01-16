//
//  WebDAV.m
//  MobileMe
//
//  Created by Ryan Detzel on 1/12/09.
//  Copyright 2009 Fifth Floor Media. All rights reserved.
//

#import "WebDAV.h"

@interface WebDAV (Private)
-(void)listDirSuccess:(NSMutableArray *)dirList;
-(void)listDirFailed:(NSString *)error;
-(void)makeDirFailed:(NSString *)error;
-(void)makeDirSuccess;
-(void)uploadFileFailed:(NSString *)error;
-(void)uploadFileSuccess;
-(void)uploadDataFailed:(NSString *)error;
-(void)uploadDataSuccess;
@end

@implementation WebDAV


@synthesize username,password,globalTimeout,connection,pendingChallenge;
@synthesize incomingData, documentURL;

static NSString *kURLTemplate = @"https://idisk.me.com/%@";

-(id)init{
	
	self = [super init];
	
	self.connection = nil;
	self.pendingChallenge = nil;
	self.incomingData = [[NSMutableData alloc] init];
	
	self.globalTimeout = 15;
	
	return self;
}

-(id)initWithUsername:(NSString *)u password:(NSString *)p{
	self = [self init];

	self.username = u;
	self.password = p;
	
	return self;
}

- (void)setDelegate:(id)val{
    delegate = val;
}

- (id)delegate{
    return delegate;
}

-(NSString *)buildURL{
	return [NSString stringWithFormat:kURLTemplate,self.username];
}

-(void)setup:(NSString *)u password:(NSString *)p{
	if (self.pendingChallenge != nil) {
        if (p != nil) {
            NSURLCredential *cred;
            NSURLCredentialPersistence  credPersist;
			
            credPersist = NSURLCredentialPersistencePermanent;
			#if TARGET_IPHONE_SIMULATOR
			credPersist = NSURLCredentialPersistenceForSession;
			#endif

            cred = [NSURLCredential credentialWithUser:username password:p persistence:credPersist];            
            [self.pendingChallenge.sender useCredential:cred forAuthenticationChallenge:self.pendingChallenge];
        } else {
            [self.pendingChallenge.sender cancelAuthenticationChallenge:self.pendingChallenge];
        }
        self.pendingChallenge = nil;
    }
}

/* ********* List Directory *****************/
/* Path must start and end with a slash (/) */

-(void)listDir:(NSString *)path{
	
	connectionState = kConnectionState_listDir;
	
	if ([path length] <= 0){
		return [self throwError:@"Path length is zero"];
	}
	
	NSRange range;
	range.location = [path length]-1;
	range.length = 1;
	
	NSString *lastChar = [path substringWithRange:range];
	if (![lastChar isEqualToString:@"/"]){
		return [self throwError:@"Path must end with a /"];
	}
	
	if (self.connection != nil){
		return [self throwError:@"A connection is already open; close it"];	
	}
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	
	directoryList = [[NSMutableArray alloc] init];

	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",[self buildURL],path]];
	_uriLength = [[url path] length] + 1;
		
	NSString *xml = @"<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n<D:propfind xmlns:D=\"DAV:\"><D:allprop/></D:propfind>";

	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
	[request setTimeoutInterval:self.globalTimeout];
	[request setHTTPMethod:@"PROPFIND"];
	[request setValue:@"1" forHTTPHeaderField:@"Depth"];
    [request setValue:@"application/xml" forHTTPHeaderField:@"Content-Type:"];
    [request setHTTPBody:[xml dataUsingEncoding:NSUTF8StringEncoding]];
    
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];	
}

/************** Make Directory ******************/
/* Pass in the full path to create */

-(void)makeDir:(NSString *)path{
	connectionState = kConnectionState_makeDir;
	
	if (self.connection != nil){
		return [self throwError:@"A connection is already open; close it"];	
	}
	
	NSURL *url = [NSURL URLWithString:[[NSString stringWithFormat:@"%@%@",[self buildURL],path] stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];

	if (url == nil){
		return [self throwError:@"Failed to create URL, maybe the filename is invalid?"];	
	}
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
	[request setHTTPMethod:@"MKCOL"];
	[request setTimeoutInterval:self.globalTimeout];

	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
}


/************ Upload File *****************/

/** Pass a data object if you already have it read in */
-(void)uploadData:(NSData *)data destination:(NSString *)path{
	if (connectionState != kConnectionState_uploadFile)
		connectionState = kConnectionState_uploadData;

	if (path == nil || [path isEqualToString:@""]){
		return [self throwError:@"The destination path is missing"];	
	}
	
	if (data == nil){
		return [self throwError:@"Data is missing"];	
	}
	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",[self buildURL],path]];
	
	NSLog(@"updateData URL: %@",url);
	
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    
    [request setHTTPMethod:@"PUT"];
    [request setHTTPBody:data];
    
    self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
}

/** Pass a filename if it's on disk */
-(void)uploadFile:(NSString *)local destination:(NSString *)path{
	connectionState = kConnectionState_uploadFile;

	if (path == nil || [path isEqualToString:@""]){
		return [self throwError:@"The destination path is missing"];	
	}
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:local]){
		NSData *outgoingData = [NSData dataWithContentsOfFile:local];
		if (outgoingData){
			[self uploadData:outgoingData destination:path];
		}
		else{
			return [self throwError:@"Failed reading in file"];	
		}
	}
	else{
		return [self throwError:@"That file does not exist"];	
	}
}




- (void)connection:(NSURLConnection *)conn didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge{	    
    self.pendingChallenge = challenge;
	[self setup:self.username password:self.password];
}

- (void)connection:(NSURLConnection *)conn didReceiveResponse:(NSURLResponse *)response{
    NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
	
	switch (connectionState) {
		case kConnectionState_makeDir:
			if (statusCode == 201){
				if ( [delegate respondsToSelector:@selector(makeDirSuccess)] ) {
					[delegate makeDirSuccess];
				}				
			}
			else{
				[self throwError:@"Failed to create directory"];
			}
			break;
		case kConnectionState_uploadData:
			if (statusCode == 201){
				if ( [delegate respondsToSelector:@selector(uploadDataSuccess)] ) {
					[delegate uploadDataSuccess];
				}				
			}
			else{
				[self throwError:@"Failed to upload data"];
			}
			break;
		case kConnectionState_uploadFile:
			if (statusCode == 201){
				if ( [delegate respondsToSelector:@selector(uploadFileSuccess)] ) {
					[delegate uploadFileSuccess];
				}				
			}
			else{
				[self throwError:@"Failed to upload file"];
			}
			break;
		default:
			NSLog(@"Status Code: %d",statusCode);
			break;
	}
}

- (void)connection:(NSURLConnection *)conn didReceiveData:(NSData *)data{
	if (self.incomingData == nil) {
		[self setIncomingData:[NSMutableData data]];
	} else {
		[self.incomingData appendData:data];
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)conn{	

	NSData *finalData = [self.incomingData retain];

    switch (connectionState) {
		case kConnectionState_listDir:
			if (finalData != nil) {
				NSXMLParser *parser = [[[NSXMLParser alloc] initWithData:finalData] autorelease];
				[parser setDelegate:self];
				if ([parser parse]){
					if ( [delegate respondsToSelector:@selector(listDirSuccess:)] ) {
						[delegate listDirSuccess:[directoryList autorelease]];
					}
				}
				else{
					return [self throwError:@"Failed to get data from listDir"];
				}
			}
			else{
				return [self throwError:@"Failed to get data from listDir"];	
			}
			
			break;
	}
	
	[finalData release];
	self.connection = nil;
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

-(void)throwError:(NSString *)error{
	switch (connectionState) {
		case kConnectionState_listDir:
			if ( [delegate respondsToSelector:@selector(listDirFailed:)] ) {
				[delegate listDirFailed:error];
			}				
			break;
		case kConnectionState_makeDir:
			if ( [delegate respondsToSelector:@selector(makeDirFailed:)] ) {
				[delegate makeDirFailed:error];
			}				
			break;
		case kConnectionState_uploadFile:
			if ( [delegate respondsToSelector:@selector(uploadFileFailed:)] ) {
				[delegate uploadFileFailed:error];
			}				
			break;
		case kConnectionState_uploadData:
			if ( [delegate respondsToSelector:@selector(uploadDataFailed:)] ) {
				[delegate uploadDataFailed:error];
			}				
			break;
	}
}

- (void)connection:(NSURLConnection *)conn didFailWithError:(NSError *)error{
	self.connection = nil;
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	return [self throwError:[error description]];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {    
    if (!_xmlChars) {
        _xmlChars = [[NSMutableString string] retain];
    }
    
    [_xmlChars setString:@""];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {    
	switch (connectionState) {
		case kConnectionState_listDir:
			if ( [elementName isEqualToString:@"D:href"]) {
				NSString *lastBit = [_xmlChars substringFromIndex:_uriLength];
				if ([lastBit length]) {
					[directoryList addObject:lastBit];
				}
			}
			break;
	}
    
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    [_xmlChars appendString:string];
}

@end
