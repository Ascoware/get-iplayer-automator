//
//  HTTPRequest.h
//
//  Created by Samuel Colak on 11/4/11.
//

#import <Foundation/Foundation.h>

enum kHTTPCode {
    kHTTPCodeUndefined = 0,
    kHTTPCodeContinue = 100,
    kHTTPCodeSwitchingProtocol = 101,
    kHTTPCodeOK = 200,
    kHTTPCodeCreated = 201,
    kHTTPCodeAccepted = 202,
    kHTTPCodeNonAuthoritiveAnswer = 203,
    kHTTPCodeNoAnswer = 204,
    kHTTPCodeResetContent = 205,
    kHTTPCodePartialContent = 206,
    kHTTPCodeRedirectMultipleChoices = 300,
    kHTTPCodeRedirectMovedPermanently = 301,
    kHTTPCodeRedirectFound = 302,
    kHTTPCodeRedirectSeeOther = 303,
    kHTTPCodeRedirectNotModified = 304,
    kHTTPCodeRedirectUseProxy = 305,
    kHTTPCodeRedirectTemporaryRedirect = 306,
    kHTTPCodeClientBadRequest = 400,
    kHTTPCodeClientUnauthorized = 401,
    kHTTPCodeClientPaymentRequired = 402,
    kHTTPCodeClientForbidden = 403,
    kHTTPCodeClientNotFound = 404,
    kHTTPCodeClientMethodNotAllowed = 405,
    kHTTPCodeClientNotAcceptable = 406,
    kHTTPCodeClientProxyAuthenticationRequired = 407,
    kHTTPCodeClientRequestTimeout = 408,
    kHTTPCodeClientConflict = 409,
    kHTTPCodeClientGone = 410,
    kHTTPCodeClientLengthRequired = 411,
    kHTTPCodeClientPreconditionFailed = 412,
    kHTTPCodeClientRequestEntityTooLarge = 413,
    kHTTPCodeClientRequestURITooLong = 414,
    kHTTPCodeClientUnsupportedMediaType = 415,
    kHTTPCodeClientRequestedRangeNotSatisfiable = 416,
    kHTTPCodeClientExpectationFailed = 417,
    kHTTPCodeServerInternalServer = 500,
    kHTTPCodeServerNotImplemented = 501,
    kHTTPCodeServerBadGateway = 502,
    kHTTPCodeServerServiceUnavailable = 503,
    kHTTPCodeServerGatewayTimeout = 504,
    kHTTPCodeServerHTTPVersionNotSupported = 505
};

@interface HTTPRequest : NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate> {
	
	NSURL *_URL;
	
@private

	NSURLConnection *_connection;
	NSMutableURLRequest *_request;
    NSInteger _responseCode;
    NSMutableData *_responseData;
    BOOL _inProgress;
    
}

    @property (nonatomic, retain) NSMutableDictionary *headers;
    @property (nonatomic, retain) NSString *contentType;
    @property (nonatomic, retain) NSString *username;
    @property (nonatomic, retain) NSString *password;
    @property (nonatomic, retain) NSData *bodyContent;

	@property (nonatomic, readonly, getter = getURL) NSMutableURLRequest *URL;
	@property (nonatomic, readonly, getter = getResponseData) NSData *responseData;
	@property (nonatomic, readonly, getter = getResponseStatusCode) NSInteger responseStatusCode;
    @property (nonatomic, readonly, getter = getInProgress) BOOL inProgress;

    + (HTTPRequest *) requestWithURL:(NSURL *)url;

	- (id) initWithURL:(NSURL *)url;
    - (id) initWithURL:(NSURL *)url timeout:(float)timeout method:(NSString *)method;

	- (void) addRequestHeader:(NSString *)key value:(NSString *)data;
	- (void) start;

@end

@protocol HTTPRequestDelegate <NSObject>

@optional
    - (void) request:(HTTPRequest *)request initialized:(NSURL *) url;
    - (void) request:(HTTPRequest *)request connected:(NSURLResponse *)response;
    - (void) request:(HTTPRequest *)request failed:(NSError *) error;
    - (void) request:(HTTPRequest *)request receivedData:(NSData *)data;
    - (void) request:(HTTPRequest *)request receivedChallenge:(NSURLAuthenticationChallenge *)challenge;
    - (void) request:(HTTPRequest *)request authenticationFailed:(NSURLAuthenticationChallenge *)challenge;
@end

@interface HTTPRequest ()

    @property (retain, nonatomic) id<HTTPRequestDelegate> delegate;

@end