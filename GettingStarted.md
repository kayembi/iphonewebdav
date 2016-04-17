# Introduction #

I will try and update this when I can but the best thing to do is download the source and read over the header file.


# Important Files #
Copy both of these files to your project.

WebDAV.m
WebDAV.h



# Initialize #
```
#import "WebDAV.h"
```

```
WebDAV *web = [[WebDAV alloc] initWithUsername:@"YOURUSERNAME" password:@"YOURPASSWORD"];
[web setDelegate:self];
```

# Listing Directories #
```
[web listDir:@"/"];
```

Responds with delegates

```
-(void)listDirFailed:(NSString *)reason;
-(void)listDirSuccess:(NSMutableArray *)dirList;
```

# Making Directories #
```
[web makeDir:@"/Documents/My Directory"];
```

Responds with delegates

```
-(void)makeDirFailed:(NSString *)error;
-(void)makeDirSuccess;
```

# Uploading Files #
```
NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
NSString *documentsDirectory = [paths objectAtIndex:0];
documentsDirectory = [NSString stringWithFormat:@"%@/test.jpg",documentsDirectory];
	
[web uploadFile:documentsDirectory destination:@"/Documents/test.jpg"];
```

Responds with delegates

```
-(void)uploadFileFailed:(NSString *)error;
-(void)uploadFileSuccess;
```


# Uploading Data #
This function is used by the uploadFile function. You can use it directly too if you have the data already loaded into memory

```
NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
NSString *documentsDirectory = [paths objectAtIndex:0];
documentsDirectory = [NSString stringWithFormat:@"%@/test.jpg",documentsDirectory];
	
NSData *testData = [[NSData alloc] initWithContentsOfFile:documentsDirectory];
[web uploadData:testData destination:@"/Documents/test-data.jpg"];
```

Responds with delegates
```
-(void)uploadDataFailed:(NSString *)error;
-(void)uploadDataSuccess;
```