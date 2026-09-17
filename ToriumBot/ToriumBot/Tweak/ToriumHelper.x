#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CFNetwork/CFNetwork.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>

#define IPC_DIR @"/var/mobile/Library/ToriumBot/ipc"

static void postDarwinNotification(NSString* name) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)name, NULL, NULL, true);
}

static __weak WKWebView *sActiveWebView = nil;

// Forward declarations
static void applyProxyConfiguration(NSURLSessionConfiguration *config);
static void inspectRequest(NSURLRequest *request);
static void autoFillRegistrationForm(void);
static void autoFillOTP(void);
static void injectTurnstileToken(void);
static void findTextFieldsInView(UIView *view, NSMutableArray<UITextField *> *result);

// MARK: - In-App Proxy Swizzling

%hook NSURLSessionConfiguration

+ (NSURLSessionConfiguration *)defaultSessionConfiguration {
    NSURLSessionConfiguration *config = %orig;
    applyProxyConfiguration(config);
    return config;
}

+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration {
    NSURLSessionConfiguration *config = %orig;
    applyProxyConfiguration(config);
    return config;
}

%end

static void applyProxyConfiguration(NSURLSessionConfiguration *config) {
    NSString *proxyPath = [IPC_DIR stringByAppendingPathComponent:@"proxy.json"];
    NSData *data = [NSData dataWithContentsOfFile:proxyPath];
    if (!data) return;

    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (!dict) return;

    NSString *host = dict[@"host"];
    NSNumber *port = dict[@"port"];
    NSString *user = dict[@"username"];
    NSString *pass = dict[@"password"];
    NSString *proto = [dict[@"protocol"] lowercaseString] ?: @"socks5";

    if (!host || !port) return;

    NSMutableDictionary *proxyDict = [NSMutableDictionary dictionary];

    if ([proto containsString:@"socks"]) {
        proxyDict[(NSString *)kCFStreamPropertySOCKSProxyHost] = host;
        proxyDict[(NSString *)kCFStreamPropertySOCKSProxyPort] = port;
        proxyDict[(NSString *)kCFStreamPropertySOCKSVersion] = (NSString *)kCFStreamSocketSOCKSVersion5;
        if (user.length > 0) proxyDict[(NSString *)kCFStreamPropertySOCKSUser] = user;
        if (pass.length > 0) proxyDict[(NSString *)kCFStreamPropertySOCKSPassword] = pass;
    } else {
        proxyDict[(NSString *)kCFNetworkProxiesHTTPEnable] = @1;
        proxyDict[(NSString *)kCFNetworkProxiesHTTPProxy] = host;
        proxyDict[(NSString *)kCFNetworkProxiesHTTPPort] = port;
        proxyDict[@"HTTPSEnable"] = @1;
        proxyDict[@"HTTPSProxy"] = host;
        proxyDict[@"HTTPSPort"] = port;
        if (user.length > 0) proxyDict[(NSString *)kCFProxyUsernameKey] = user;
        if (pass.length > 0) proxyDict[(NSString *)kCFProxyPasswordKey] = pass;
    }

    config.connectionProxyDictionary = proxyDict;
}

// MARK: - Auth & Turnstile Sniffer

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(id)completionHandler {
    inspectRequest(request);
    return %orig;
}

%end

%hook WKWebView

- (WKNavigation *)loadRequest:(NSURLRequest *)request {
    sActiveWebView = self;
    inspectRequest(request);
    return %orig;
}

%end

static void inspectRequest(NSURLRequest *request) {
    NSString *urlStr = request.URL.absoluteString;
    if (!urlStr) return;

    // 1. Capture dynamic Turnstile Sitekey
    if ([urlStr containsString:@"challenges.cloudflare.com"] || [urlStr containsString:@"turnstile"]) {
        NSURLComponents *components = [NSURLComponents componentsWithString:urlStr];
        for (NSURLQueryItem *item in components.queryItems) {
            if ([item.name isEqualToString:@"sitekey"] || [item.name isEqualToString:@"k"]) {
                NSString *sitekey = item.value;
                if (sitekey.length > 5) {
                    NSDictionary *sitekeyDict = @{@"sitekey": sitekey, @"url": urlStr};
                    NSData *skData = [NSJSONSerialization dataWithJSONObject:sitekeyDict options:0 error:nil];
                    [skData writeToFile:[IPC_DIR stringByAppendingPathComponent:@"turnstile_sitekey.json"] atomically:YES];
                    postDarwinNotification(@"com.toriumbot.sitekey_captured");
                    break;
                }
            }
        }
    }

    if (![urlStr containsString:@"torium.network"]) return;

    // 2. Capture dynamic OTA & App Versions
    NSString *otaVersion = [request valueForHTTPHeaderField:@"x-ota-version"];
    NSString *appVersion = [request valueForHTTPHeaderField:@"x-app-version"];
    if (otaVersion.length > 0 || appVersion.length > 0) {
        NSMutableDictionary *versions = [NSMutableDictionary dictionary];
        if (otaVersion) versions[@"x_ota_version"] = otaVersion;
        if (appVersion) versions[@"x_app_version"] = appVersion;
        NSData *vData = [NSJSONSerialization dataWithJSONObject:versions options:0 error:nil];
        [vData writeToFile:[IPC_DIR stringByAppendingPathComponent:@"ota_version.json"] atomically:YES];
    }

    // 3. Capture Bearer Token
    NSString *authHeader = [request valueForHTTPHeaderField:@"Authorization"];
    if (authHeader && [authHeader hasPrefix:@"Bearer "]) {
        NSString *token = [authHeader stringByReplacingOccurrencesOfString:@"Bearer " withString:@""];
        if (token.length > 20) {
            NSString *deviceId = [request valueForHTTPHeaderField:@"x-device-id"] ?: [[NSUUID UUID] UUIDString];
            NSDictionary *authDict = @{
                @"token": token,
                @"clerkId": @"user_synced",
                @"deviceId": deviceId
            };
            NSData *resData = [NSJSONSerialization dataWithJSONObject:authDict options:0 error:nil];
            [resData writeToFile:[IPC_DIR stringByAppendingPathComponent:@"result.json"] atomically:YES];
            postDarwinNotification(@"com.toriumbot.auth_extracted");
        }
    }
}

// MARK: - Turnstile DOM Token Injection

static void injectTurnstileToken(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *tokenPath = [IPC_DIR stringByAppendingPathComponent:@"turnstile_token.json"];
        NSData *data = [NSData dataWithContentsOfFile:tokenPath];
        if (!data) return;

        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *token = dict[@"token"];
        if (!token || token.length < 10) return;

        if (sActiveWebView) {
            NSString *js = [NSString stringWithFormat:
                @"(() => {"
                @"  const el = document.querySelector('[name=\"cf-turnstile-response\"]') || document.querySelector('input[name*=\"turnstile\"]');"
                @"  if (el) {"
                @"    el.value = '%@';"
                @"    el.dispatchEvent(new Event('input', { bubbles: true }));"
                @"    el.dispatchEvent(new Event('change', { bubbles: true }));"
                @"  }"
                @"  if (window.turnstile && typeof window.turnstile.submit === 'function') {"
                @"    window.turnstile.submit('%@');"
                @"  }"
                @"})();", token, token];
            [sActiveWebView evaluateJavaScript:js completionHandler:nil];
        }
    });
}

// MARK: - Form Auto-Fill & OTP Injection Helpers

static void autoFillRegistrationForm(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *taskPath = [IPC_DIR stringByAppendingPathComponent:@"task.json"];
        NSData *data = [NSData dataWithContentsOfFile:taskPath];
        if (!data) return;

        NSDictionary *task = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *email = task[@"email"];
        NSString *password = task[@"password"];
        NSString *refCode = task[@"referralCode"];

        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) return;

        NSMutableArray<UITextField *> *fields = [NSMutableArray array];
        findTextFieldsInView(keyWindow, fields);

        if (fields.count >= 2) {
            [fields[0] becomeFirstResponder];
            fields[0].text = email;
            [[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification object:fields[0]];

            [fields[1] becomeFirstResponder];
            fields[1].text = password;
            [[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification object:fields[1]];

            if (fields.count >= 3 && refCode.length > 0) {
                [fields[2] becomeFirstResponder];
                fields[2].text = refCode;
                [[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification object:fields[2]];
            }

            [keyWindow endEditing:YES];
        }
    });
}

static void autoFillOTP(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *otpPath = [IPC_DIR stringByAppendingPathComponent:@"otp.json"];
        NSData *data = [NSData dataWithContentsOfFile:otpPath];
        if (!data) return;

        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *otp = dict[@"otp"];
        if (otp.length < 6) return;

        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) return;

        NSMutableArray<UITextField *> *fields = [NSMutableArray array];
        findTextFieldsInView(keyWindow, fields);

        if (fields.count == 1) {
            fields[0].text = otp;
            [[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification object:fields[0]];
        } else if (fields.count >= 6) {
            for (NSInteger i = 0; i < 6; i++) {
                NSString *digit = [otp substringWithRange:NSMakeRange(i, 1)];
                fields[i].text = digit;
                [[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification object:fields[i]];
            }
        }
    });
}

static void findTextFieldsInView(UIView *view, NSMutableArray<UITextField *> *result) {
    if ([view isKindOfClass:[UITextField class]]) {
        [result addObject:(UITextField *)view];
    }
    for (UIView *subview in view.subviews) {
        findTextFieldsInView(subview, result);
    }
}

// MARK: - Darwin Notification Listeners

static void onRegStartNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    autoFillRegistrationForm();
}

static void onOTPReadyNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    autoFillOTP();
}

static void onInjectTurnstileNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    injectTurnstileToken();
}

%ctor {
    @autoreleasepool {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            onRegStartNotification,
            CFSTR("com.toriumbot.reg_start"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            onOTPReadyNotification,
            CFSTR("com.toriumbot.otp_ready"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            onInjectTurnstileNotification,
            CFSTR("com.toriumbot.inject_turnstile"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
    }
}
