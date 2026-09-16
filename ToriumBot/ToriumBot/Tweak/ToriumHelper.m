#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CFNetwork/CFNetwork.h>
#import <objc/runtime.h>

#define IPC_DIR @"/var/mobile/Library/ToriumBot/ipc"

static void postDarwinNotification(NSString* name) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)name, NULL, NULL, true);
}

// Forward declarations
static void applyProxyConfiguration(NSURLSessionConfiguration *config);
static void inspectRequest(NSURLRequest *request);
static void autoFillRegistrationForm(void);
static void autoFillOTP(void);
static void findTextFieldsInView(UIView *view, NSMutableArray<UITextField *> *result);

// MARK: - Method Swizzling Function Pointers

static NSURLSessionConfiguration * (*orig_defaultSessionConfiguration)(Class, SEL) = NULL;
static NSURLSessionConfiguration * hooked_defaultSessionConfiguration(Class self, SEL _cmd) {
    NSURLSessionConfiguration *config = orig_defaultSessionConfiguration ? orig_defaultSessionConfiguration(self, _cmd) : nil;
    if (config) {
        applyProxyConfiguration(config);
    }
    return config;
}

static NSURLSessionConfiguration * (*orig_ephemeralSessionConfiguration)(Class, SEL) = NULL;
static NSURLSessionConfiguration * hooked_ephemeralSessionConfiguration(Class self, SEL _cmd) {
    NSURLSessionConfiguration *config = orig_ephemeralSessionConfiguration ? orig_ephemeralSessionConfiguration(self, _cmd) : nil;
    if (config) {
        applyProxyConfiguration(config);
    }
    return config;
}

static NSURLSessionDataTask * (*orig_dataTaskWithRequest)(id, SEL, NSURLRequest *, id) = NULL;
static NSURLSessionDataTask * hooked_dataTaskWithRequest(id self, SEL _cmd, NSURLRequest *request, id completionHandler) {
    inspectRequest(request);
    if (orig_dataTaskWithRequest) {
        return orig_dataTaskWithRequest(self, _cmd, request, completionHandler);
    }
    return nil;
}

// MARK: - In-App Proxy Swizzling

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

// MARK: - Auth & OTA Version Sniffer

static void inspectRequest(NSURLRequest *request) {
    NSString *urlStr = request.URL.absoluteString;
    if (![urlStr containsString:@"torium.network"]) return;

    // 1. Capture dynamic OTA & App Versions
    NSString *otaVersion = [request valueForHTTPHeaderField:@"x-ota-version"];
    NSString *appVersion = [request valueForHTTPHeaderField:@"x-app-version"];
    if (otaVersion.length > 0 || appVersion.length > 0) {
        NSMutableDictionary *versions = [NSMutableDictionary dictionary];
        if (otaVersion) versions[@"x_ota_version"] = otaVersion;
        if (appVersion) versions[@"x_app_version"] = appVersion;
        NSData *vData = [NSJSONSerialization dataWithJSONObject:versions options:0 error:nil];
        [vData writeToFile:[IPC_DIR stringByAppendingPathComponent:@"ota_version.json"] atomically:YES];
    }

    // 2. Capture Bearer Token
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
            // Field 0: Email
            [fields[0] becomeFirstResponder];
            fields[0].text = email;
            [[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification object:fields[0]];

            // Field 1: Password
            [fields[1] becomeFirstResponder];
            fields[1].text = password;
            [[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification object:fields[1]];

            // Field 2: Referral Code (Optional)
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
            // Single input field
            fields[0].text = otp;
            [[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification object:fields[0]];
        } else if (fields.count >= 6) {
            // 6 segmented individual boxes
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

// MARK: - Constructor

__attribute__((constructor))
static void toriumHelperInit(void) {
    @autoreleasepool {
        // Swizzle NSURLSessionConfiguration class methods
        Method m1 = class_getClassMethod([NSURLSessionConfiguration class], @selector(defaultSessionConfiguration));
        if (m1) {
            orig_defaultSessionConfiguration = (NSURLSessionConfiguration * (*)(Class, SEL))method_getImplementation(m1);
            method_setImplementation(m1, (IMP)hooked_defaultSessionConfiguration);
        }

        Method m2 = class_getClassMethod([NSURLSessionConfiguration class], @selector(ephemeralSessionConfiguration));
        if (m2) {
            orig_ephemeralSessionConfiguration = (NSURLSessionConfiguration * (*)(Class, SEL))method_getImplementation(m2);
            method_setImplementation(m2, (IMP)hooked_ephemeralSessionConfiguration);
        }

        // Swizzle NSURLSession dataTaskWithRequest:completionHandler:
        Method m3 = class_getInstanceMethod([NSURLSession class], @selector(dataTaskWithRequest:completionHandler:));
        if (m3) {
            orig_dataTaskWithRequest = (NSURLSessionDataTask * (*)(id, SEL, NSURLRequest *, id))method_getImplementation(m3);
            method_setImplementation(m3, (IMP)hooked_dataTaskWithRequest);
        }

        // Register Darwin notification observers
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
    }
}
