#import <UIKit/UIKit.h>
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "MBProgressHUD.h"

@interface BaseViewController : UIViewController {
	
	NSMutableArray* requests;
	
}

- (ASIHTTPRequest*) requestWithURL:(NSString*) s;
- (ASIFormDataRequest*) formRequestWithURL:(NSString*) s;
- (void) addRequest:(ASIHTTPRequest*)request;
- (void) clearFinishedRequests;
- (void) cancelRequests;

- (void)informError:(id)error;
- (void)informMessage:(NSString *)message;

@end
