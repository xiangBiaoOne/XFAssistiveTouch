//
//  XFAssistiveTouch.m
//  XFAssistiveTouchExample
//
//  Created by 徐亚非 on 2016/9/26.
//  Copyright © 2016年 XuYafei. All rights reserved.
//

#import "XFAssistiveTouch.h"

@interface XFAssistiveTouch () <XFATNavigationControllerDelegate>

@property (nonatomic, assign) CGPoint assistiveWindowPoint;
@property (nonatomic, assign) CGPoint coverWindowPoint;

@end

@implementation XFAssistiveTouch

+ (instancetype)shareInstance {
    static id shareInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareInstance = [self new];
    });
    return shareInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _rootNavigationController = [[XFATNavigationController alloc] initWithRootViewController:[XFATRootViewController new]];
        _rootNavigationController.delegate = self;
        _assistiveWindowPoint = [XFATLayoutAttributes cotentViewDefaultPoint];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillChangeFrame:)
                                                     name:UIKeyboardWillChangeFrameNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)showAssistiveTouch {
    _assistiveWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, [XFATLayoutAttributes itemImageWidth], [XFATLayoutAttributes itemImageWidth])];
    _assistiveWindow.center = _assistiveWindowPoint;
    _assistiveWindow.windowLevel = CGFLOAT_MAX;
    _assistiveWindow.backgroundColor = [UIColor clearColor];
    _assistiveWindow.rootViewController = _rootNavigationController;
    [self makeVisibleWindow];
}

- (void)makeVisibleWindow {
    UIWindow *keyWindows = [UIApplication sharedApplication].keyWindow;
    [_assistiveWindow makeKeyAndVisible];
    if (keyWindows) {
        [keyWindows makeKeyWindow];
    }
}

#pragma mark - XFATViewControllerDelegate

- (void)navigationController:(XFATNavigationController *)navigationController actionBeginAtPoint:(CGPoint)point {
    _coverWindowPoint = CGPointZero;
    _assistiveWindow.frame = [UIScreen mainScreen].bounds;
    _rootNavigationController.view.frame = [UIScreen mainScreen].bounds;
    [_rootNavigationController moveContentViewToPoint:_assistiveWindowPoint];
}

- (void)navigationController:(XFATNavigationController *)navigationController actionEndAtPoint:(CGPoint)point {
    _assistiveWindowPoint = point;
    _assistiveWindow.frame = CGRectMake(0, 0, [XFATLayoutAttributes itemImageWidth], [XFATLayoutAttributes itemImageWidth]);
    _assistiveWindow.center = _assistiveWindowPoint;
    CGPoint contentPoint = CGPointMake([XFATLayoutAttributes itemImageWidth] / 2, [XFATLayoutAttributes itemImageWidth] / 2);
    [_rootNavigationController moveContentViewToPoint:contentPoint];
}

#pragma mark - UIKeyboardWillChangeFrameNotification

- (void)keyboardWillChangeFrame:(NSNotification *)notification {
    
    if ([[UIDevice currentDevice].systemVersion integerValue] >= 10) {
        return;
    }
    
    /*因为动画过程中不能实时修改_assistiveWindowRect,
     *所以如果执行点击操作的话,_assistiveTouchView位置会以动画之前的位置为准.
     *如果执行拖动操作则会有跳动效果.所以需要禁止用户操作.*/
    _assistiveWindow.userInteractionEnabled = NO;
    NSDictionary *info = [notification userInfo];
    CGFloat duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    CGRect endKeyboardRect = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];

    //根据实时位置计算于键盘的间距
    CGFloat yOffset = endKeyboardRect.origin.y - CGRectGetMaxY(_assistiveWindow.frame);

    //如果键盘弹起给_coverWindowPoint赋值
    if (endKeyboardRect.origin.y < CGRectGetHeight([UIScreen mainScreen].bounds)) {
        _coverWindowPoint = _assistiveWindowPoint;
    }

    //根据间距计算移动后的位置viewPoint
    CGPoint viewPoint = _assistiveWindow.center;
    viewPoint.y += yOffset;
    //如果viewPoint在原位置之下,将viewPoint变为原位置
    if (viewPoint.y > _coverWindowPoint.y) {
        viewPoint.y = _coverWindowPoint.y;
    }
    //如果_assistiveWindow被移动,将viewPoint变为移动后的位置
    if (CGPointEqualToPoint(_coverWindowPoint, CGPointZero)) {
        viewPoint.y = _assistiveWindow.center.y;
    }

    //根据计算好的位置执行动画
    [UIView animateWithDuration:duration animations:^{
        _assistiveWindow.center = viewPoint;
    } completion:^(BOOL finished) {
        //将_assistiveWindowRect变为移动后的位置并恢复用户操作
        _assistiveWindowPoint = _assistiveWindow.center;
        _assistiveWindow.userInteractionEnabled = YES;
        //使其遮盖键盘
        [self makeVisibleWindow];
    }];
}

#pragma mark - PushViewController

- (void)pushViewController:(UIViewController *)viewController {
    UIViewController *topvc = [self p_topViewController];
    if ([topvc isKindOfClass:[UINavigationController class]]) {
        [(UINavigationController *)topvc pushViewController:viewController animated:YES];
    } else {
        [topvc presentViewController:viewController animated:YES completion:^{}];
    }
    [_rootNavigationController shrink];
}

- (UIViewController *)p_topViewController{
    static UIViewController *cachevc;
    if (cachevc) {
        return cachevc;
    }
    cachevc = [self p_topViewController:[UIApplication sharedApplication].keyWindow.rootViewController];
    return cachevc;
}

- (UIViewController *)p_topViewController:(UIViewController *)rootvc {
    if (_navigationController) {
        return _navigationController;
    } else {
        if ([rootvc isKindOfClass:[UITabBarController class]]) {
            UIViewController *tabvc = ((UITabBarController *)rootvc).selectedViewController;
            return [self p_topViewController:tabvc];
        } else {
            UIViewController *topvc = rootvc;
            while (topvc.presentedViewController) {
                topvc = topvc.presentedViewController;
            }
            return topvc;
        }
    }
}

@end
