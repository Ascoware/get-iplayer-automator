//
//  HTTPRequest.m
//
//  Created by Samuel Colak on 11/4/11.
//

#import "HTTPRequest.h"

@implementation HTTPRequest

	@synthesize delegate;
    @synthesize headers=_headers;
    @synthesize contentType=_contentType;

    @synthesize password=_password;
    @synthesize username=_username;
    @synthesize bodyContent=_bodyContent;

    #pragma mark - Instantiation

    + (HTTPRequest *) requestWithURL:(NSURL *)url
    {		
        return [[HTTPRequest alloc] initWithURL:url];
    }

    - (id) initWithURL:(NSURL *)url 
    {
        return [self initWithURL:url timeout:60.0 method:@"PUT"];
    }

    - (id) initWithURL:(NSURL *)url timeout:(float)timeout method:(NSString *)method
	{
		self = [super init];
		if (self) {
			_URL = url;		
            _responseCode = kHTTPCodeUndefined;
            _responseData = nil;
            _inProgress = NO;
            _contentType = @"text/plain; charset=utf-8";
            _headers = [[NSMutableDictionary alloc] init];
            _request = [NSMutableURLRequest requestWithURL:_URL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:timeout];
            [_request setHTTPMethod:method];
		}
		return self;
	}

    #pragma mark - Properties and getters

	- (NSURL *) getURL
	{
		return _URL;
	}

    - (BOOL) getInProgress
    {
        return _inProgress;
    }

	- (NSData *) getResponseData
	{
		return _responseData;
	}

	- (NSInteger) getResponseStatusCode
	{
		return _responseCode;
	}

    #pragma mark - Functions

	- (void) addRequestHeader:(NSString *)key value:(NSString *)data
	{
        [_headers setValue:data forKey:key];
	}

	- (void) start
	{
        
        if (_inProgress) return;
        _inProgress = YES;
        
        _responseCode = kHTTPCodeUndefined;
        _responseData = nil;
                
        [_request addValue:_contentType forHTTPHeaderField:@"Content-Type"];

        if (_headers.count > 0) {
            for (NSString *key in _headers.allKeys)
            {
                [_request addValue:[_headers valueForKey:key] forHTTPHeaderField:key];
            }
        }
                        
        if (_bodyContent != nil) {
            [_request addValue:[NSString stringWithFormat:@"%d", _bodyContent.length] forHTTPHeaderField:@"Content-Length"];
            [_request setHTTPBody: _bodyContent];        
        }
        
        _connection = [[NSURLConnection alloc] initWithRequest:_request delegate:self];		

		if (_connection) {
            if (delegate && [delegate respondsToSelector:@selector(request:initialized:)]) {
                [delegate request:self initialized:_URL];
            }			
		} else {
			// connection failed ...
            _responseCode = kHTTPCodeServerServiceUnavailable;            
            if (delegate && [delegate respondsToSelector:@selector(request:failed:)]) {
                [delegate request:self failed:nil];
            }
            _inProgress = NO;
		}
		
	}

    #pragma mark - Delegate related functions

    - (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
    {
        // if you want to execute your own challenge functionality here....        
        if (delegate && [delegate respondsToSelector:@selector(request:receivedChallenge:)]) {
            [delegate request:self receivedChallenge:challenge];
        } else {
            // automate the response using the username / password information..
            if ([challenge previousFailureCount] == 0 && ![challenge proposedCredential]) {
                NSURLCredential *_credentials = [NSURLCredential credentialWithUser:_username password:_password persistence:NSURLCredentialPersistenceNone];
                [[challenge sender] useCredential:_credentials forAuthenticationChallenge:challenge];                
            } else {
                if (delegate && [delegate respondsToSelector:@selector(request:authenticationFailed:)]) {
                    [delegate request:self authenticationFailed:challenge];
                } else {
                    [[challenge sender] cancelAuthenticationChallenge:challenge];
                }
            }
        }
    }

    - (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
    {
        [_responseData appendData:data];        
    }

    - (void) connectionDidFinishLoading:(NSURLConnection *)connection
    {
        if (delegate && [delegate respondsToSelector:@selector(request:receivedData:)]) {
            [delegate request:self receivedData:_responseData];
        }
    }

	- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
	{           
        _responseData = [[NSMutableData alloc] init];        
        NSHTTPURLResponse *_httpResponse = (NSHTTPURLResponse *)response;
        _responseCode = [_httpResponse statusCode];         
        if (delegate && [delegate respondsToSelector:@selector(request:connected:)]) {
            [delegate request:self connected:response];
        }        
        _inProgress = NO;
	}

    - (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
    {
        _responseCode = kHTTPCodeServerInternalServer;
        if (delegate && [delegate respondsToSelector:@selector(request:failed:)]) {
            [delegate request:self failed:error];
        }
        _inProgress = NO;
    }
 

@end
