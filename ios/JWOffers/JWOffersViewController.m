//
//  JWOffersViewController.m
//  Jowalla
//
//  Created by Juan Alvarez on 7/24/14.
//  Copyright (c) 2014 Jowalla. All rights reserved.
//

#import "JWOffersViewController.h"
#import <WebKit/WebKit.h>

@import PassKit;
@import MessageUI;

@interface JWOffersViewController () <UIWebViewDelegate, WKNavigationDelegate, PKAddPassesViewControllerDelegate, MFMailComposeViewControllerDelegate>

@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) WKWebView *webkitView;

@property (nonatomic, strong) NSURL *url;

@end

@implementation JWOffersViewController

- (id)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self) {
        self.url = url;
        self.title = @"Offers";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.view addSubview:self.webView];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    self.webView.frame = self.view.bounds;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)willMoveToParentViewController:(UIViewController *)parent
{
    if (parent) {
        NSURLRequest *request = [NSURLRequest requestWithURL:self.url];
        
        [self.webView loadRequest:request];
    } else {
        [self.webView stopLoading];
    }
}

#pragma mark -
#pragma mark PKAddPassesViewControllerDelegate Methods

- (void)addPassesViewControllerDidFinish:(PKAddPassesViewController *)controller
{
    [self.webView goBack];
    
    [controller dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark -
#pragma mark MFMailComposeViewControllerDelegate Methods

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    switch (result) {
        case MFMailComposeResultCancelled: {
            NSLog(@"Mail Compose Cancelled");
        }
            break;
        case MFMailComposeResultSaved: {
            NSLog(@"Mail Compose Saved");
        }
            break;
        case MFMailComposeResultSent: {
            NSLog(@"Mail Compose Sent");
        }
            break;
        case MFMailComposeResultFailed: {
            NSLog(@"Mail Compose Failed");
        }
            break;
            
        default:
            break;
    }
    
    [controller dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Private Method

- (BOOL)canOpenURL:(NSURL *)url
{
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    NSString *ext = url.pathExtension;
    
    if ([ext isEqualToString:@"pkpass"]) {
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                                   if (data) {
                                       PKPass *pass = [[PKPass alloc] initWithData:data error:nil];
                                       
                                       PKAddPassesViewController *controller = [[PKAddPassesViewController alloc] initWithPass:pass];
                                       controller.delegate = self;
                                       
                                       [self presentViewController:controller animated:YES completion:NULL];
                                   }
                               }];
        
        return NO;
    }
    
    else if ([url.scheme isEqualToString:@"mailto"] && [MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
        mailViewController.mailComposeDelegate = self;
        
        NSArray *rawURLparts = [[url resourceSpecifier] componentsSeparatedByString:@"?"];
        if (rawURLparts.count > 2) {
            return NO; // invalid URL
        }
        
        NSMutableArray *toRecipients = [NSMutableArray array];
        NSString *defaultRecipient = [rawURLparts objectAtIndex:0];
        if (defaultRecipient.length) {
            [toRecipients addObject:defaultRecipient];
        }
        
        if (rawURLparts.count == 2) {
            NSString *queryString = [rawURLparts objectAtIndex:1];
            
            NSArray *params = [queryString componentsSeparatedByString:@"&"];
            for (NSString *param in params) {
                NSArray *keyValue = [param componentsSeparatedByString:@"="];
                if (keyValue.count != 2) {
                    continue;
                }
                NSString *key = [[keyValue objectAtIndex:0] lowercaseString];
                NSString *value = [keyValue objectAtIndex:1];
                
                value =  (NSString *)CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
                                                                                                               (CFStringRef)value,
                                                                                                               CFSTR(""),
                                                                                                               kCFStringEncodingUTF8));
                
                if ([key isEqualToString:@"subject"]) {
                    [mailViewController setSubject:value];
                }
                
                if ([key isEqualToString:@"body"]) {
                    [mailViewController setMessageBody:value isHTML:NO];
                }
                
                if ([key isEqualToString:@"to"]) {
                    [toRecipients addObjectsFromArray:[value componentsSeparatedByString:@","]];
                }
                
                if ([key isEqualToString:@"cc"]) {
                    NSArray *recipients = [value componentsSeparatedByString:@","];
                    [mailViewController setCcRecipients:recipients];
                }
                
                if ([key isEqualToString:@"bcc"]) {
                    NSArray *recipients = [value componentsSeparatedByString:@","];
                    [mailViewController setBccRecipients:recipients];
                }
            }
        }
        
        [mailViewController setToRecipients:toRecipients];
        
        [self presentViewController:mailViewController animated:YES completion:^{
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
        }];
        
        return NO;
    }
    
    return YES;
}

#pragma mark -
#pragma mark UIWebViewDelegate Methods

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    return [self canOpenURL:request.URL];
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    if (![self canOpenURL:webView.URL])
    {
        [webView stopLoading];
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    NSLog(@"DONE");
}

#pragma mark -
#pragma mark Views

- (id)webView
{
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 8.0)
    {
        if (_webView)
        {
            return _webView;
        }
        _webView = [[UIWebView alloc] init];
        _webView.delegate = self;
        _webView.scalesPageToFit = YES;
        return _webView;
    }
    else
    {
        if (_webkitView)
        {
            return _webkitView;
        }
        _webkitView = [[WKWebView alloc] init];
        _webkitView.navigationDelegate = self;
        return _webkitView;
    }
    
}

@end
