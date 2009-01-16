//
//  WebDAV.h
//  MobileMe
//
//  Created by Ryan Detzel on 1/12/09.
//  Copyright 2009 Fifth Floor Media. All rights reserved.
//

#import <Foundation/Foundation.h>

enum ConnectionState {
    kConnectionState_listDir,
	kConnectionState_makeDir,
	kConnectionState_uploadFile,
	kConnectionState_uploadData,
};

typedef enum ConnectionState ConnectionState;

@interface WebDAV : NSObject {
	id delegate;
	
	NSString *username;
	NSString *password;
	
	NSInteger globalTimeout;
	ConnectionState connectionState;

	NSURLConnection *connection;
	NSMutableData *incomingData;
	NSURLAuthenticationChallenge *pendingChallenge;
	NSURL *documentURL;
	
	NSMutableString *_xmlChars;
	NSUInteger _uriLength;
	
	NSMutableArray *directoryList;
}

@property (nonatomic, copy)	NSString *username;
@property (nonatomic, copy) NSString *password;

@property (nonatomic, assign) NSInteger globalTimeout;

@property (nonatomic, retain)	NSURLConnection *connection;
@property (nonatomic, retain)   NSMutableData *incomingData;
@property (nonatomic, retain)   NSURLAuthenticationChallenge *pendingChallenge;

@property (nonatomic, readonly) NSURL *documentURL;


-(id)initWithUsername:(NSString *)u password:(NSString *)p;
-(void)setup:(NSString *)u password:(NSString *)p;
-(id)delegate;
-(void)setDelegate:(id)val;

-(NSString *)buildURL;

-(void)listDir:(NSString *)path;
-(void)throwError:(NSString *)error;

-(void)makeDir:(NSString *)path;

-(void)uploadData:(NSData *)data destination:(NSString *)path;
-(void)uploadFile:(NSString *)local destination:(NSString *)path;

@end
