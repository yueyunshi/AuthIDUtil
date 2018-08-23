//
//  SNBAuthIDUtil.m
//  SNBAuthIDUtil
//
//  Created by 岳云石 on 2018/6/13.
//  Copyright © 2018年 岳云石. All rights reserved.
//



#import "SNBAuthIDUtil.h"
#import <UIKit/UIKit.h>

// 操作系统版本号
#define IOS_VERSION ([[[UIDevice currentDevice] systemVersion] floatValue])

/**
 AuthID报错信息整理
 支持AuthID的情况:
 LAErrorAuthenticationFailed -> AuthID验证失败
 LAErrorUserCancel           -> 取消AuthID验证 (用户点击了取消,按下Home键)
 LAErrorUserFallback         -> 在AuthID对话框中点击输入密码按钮
 LAErrorSystemCancel         -> 在验证的AuthID的过程中被系统取消 例如突然来电话、锁屏...
 LAErrorAuthIDNotAvailable  -> 该设备的AuthID无效
 LAErrorAppCancel            -> 在验证的AuthID的过程中被系统取消
 LAErrorInvalidContext       -> 当前软件被挂起取消了授权 (授权过程中,LAContext对象被释)
 
 不支持AuthID的情况:
 LAErrorAuthIDLockout       -> 多次连续使用Touch ID失败，Touch ID被锁，
 需要从新输入密码才能启动 在这种情况吊起AuthID会产生设备不支持AuthID
 LAErrorAuthIDNotEnrolled   -> 设备没有录入AuthID,无法启用AuthID
 LAErrorPasscodeNotSet       -> 无法启用AuthID,设备没有设置密码
 */

@implementation SNBAuthIDUtil


/**
 指纹/面容解锁
 
 @param content  提示文本
 @param cancelButtonTitle  取消按钮显示内容(此参数只有iOS10以上才能生效)，默认（nil）：取消
 @param otherButtonTitle   密码登录按钮显示内容，默认（nil）：输入密码（nil）
 @param policy  LAPolicyDeviceOwnerAuthenticationWithBiometrics  LAPolicyDeviceOwnerAuthentication
 @param snb_authIDTypeBlock   返回状态码和错误，可以自行单独处理
 */
+ (void)authIDWithContent:(NSString *)content
        cancelButtonTitle:(NSString *)cancelButtonTitle
         otherButtonTitle:(NSString *)otherButtonTitle
                   policy:(LAPolicy)policy
      snb_authIDTypeBlock:(SNB_AuthID_Block)snb_authIDTypeBlock
{
    if (NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_8_0) {
        //此设备不支持Touch ID";
        snb_authIDTypeBlock(SNBBiometryNone, SNBAuthIDTypeNotSupport, nil, @"系统不支持",nil);
        return;
    }
    
    [SNBAuthIDUtil authIDVerifyIsSupportWithBlock:^(BOOL isSupport, LAContext *context, NSError *error) {
        
        SNBBiometryType biometryType = [SNBAuthIDUtil _snb_getContextBiometryType:context
                                                                         isSuport:isSupport];
        
        context.localizedFallbackTitle = otherButtonTitle;
        
        if (@available(iOS 10.0, *)) {
            context.localizedCancelTitle = cancelButtonTitle;
        }
        
        if (isSupport)
        {
            // 支持指纹/面容验证
            [context evaluatePolicy:policy localizedReason:content reply:^(BOOL success, NSError * _Nullable error) {
                if (success)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (@available(iOS 9.0, *)) {
                            snb_authIDTypeBlock(biometryType, SNBAuthIDTypeSuccess, error, nil, context.evaluatedPolicyDomainState);
                        }else
                        {
                            snb_authIDTypeBlock(biometryType, SNBAuthIDTypeSuccess, error, nil, nil);
                        }
                    });
                    
                    return ;
                }
                else if (error){
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [SNBAuthIDUtil _snb_handleError:error isSupport:YES
                                        ContextBiometry:biometryType
                                    snb_AuthIDTypeBlock:snb_authIDTypeBlock];
                    });
                }
            }];
        }
        else{
            dispatch_async(dispatch_get_main_queue(), ^{
                [SNBAuthIDUtil _snb_handleError:error
                                      isSupport:NO
                                ContextBiometry:biometryType
                            snb_AuthIDTypeBlock:snb_authIDTypeBlock];
            });
        }
    }];
}

/**
 判断是否支持指纹/面容解锁
 
 @param block block
 */
+ (void)authIDVerifyIsSupportWithBlock:(SNB_AuthIDVerifyIsSupport_Block)block
{
    LAContext *context = [LAContext new];
    
    NSInteger policy;
    
    if (@available(iOS 9.0, *)) {
        policy = LAPolicyDeviceOwnerAuthentication;
    } else {
        policy = LAPolicyDeviceOwnerAuthenticationWithBiometrics;
    }
    NSError *error = nil;
    // 首先使用 canEvaluatePolicy 判断设备支持状态
    BOOL isSupport = [context canEvaluatePolicy:policy error:&error];
    block(isSupport, context, error);
}

/**
 获取生物识别方式
 context LAContext
 isSuport 是否支持生物识别
 */
+ (SNBBiometryType)_snb_getContextBiometryType:(LAContext *)context isSuport:(BOOL)isSuport
{
    if (isSuport) {
        if (@available(iOS 11.0, *)) {
            switch (context.biometryType) {
                case LABiometryNone:
                    return SNBBiometryNone;
                    break;
                case LABiometryTypeTouchID:
                    return SNBBiometryTouchID;
                    break;
                case LABiometryTypeFaceID:
                    return SNBBiometryFaceID;
                    break;
                default:
                    break;
            }
        }else{
            return SNBBiometryTouchID;
        }
    }else
    {
        if (@available(iOS 11.0, *)) {
            return SNBBiometryNone; //无法识别
        }else{
            return SNBBiometryTouchID; //11 系统以下只有touchID
        }
    }
    /*
     isSuport 为No的情况下是无法获得认证情况的统一返回的都是LABiometryNone
     例如在 指纹解锁呗锁定的时候就无法区分是 指纹解锁 还是 面容解锁 但是ios9以后的认证方式不会出现
     */
    return SNBBiometryNone; //无法分别指纹还是faceid认证
}

/**
 判断是指纹认证还是面容
 */

+ (SNBBiometryType)getBiometryType
{
    __block SNBBiometryType biomType = SNBBiometryNone;
    [SNBAuthIDUtil authIDVerifyIsSupportWithBlock:^(BOOL isSupport, LAContext *context, NSError *error) {
        biomType = [SNBAuthIDUtil _snb_getContextBiometryType:context isSuport:isSupport];
    }];
    return biomType;
}

/**
 异常情况处理
 
 @param error error
 @param SNB_AuthIDTypeBlock  回调block
 */
+ (void)_snb_handleError:(NSError *)error
               isSupport:(BOOL)isSupport
         ContextBiometry:(SNBBiometryType)biometryType
     snb_AuthIDTypeBlock:(SNB_AuthID_Block)SNB_AuthIDTypeBlock
{
    NSString *msg = @"";
    if (@available(iOS 11.0, *)) {
        
        switch (error.code) {
            case LAErrorAuthenticationFailed:{
                msg = @"AuthID 验证失败";
                SNB_AuthIDTypeBlock(biometryType, SNBAuthIDTypeFail, error, msg, nil);
            }
                break;
            case LAErrorUserCancel:{
                msg = @"AuthID 被用户手动取消";
                SNB_AuthIDTypeBlock(biometryType, SNBAuthIDTypeUserCancel, error, msg, nil);
            }
                break;
            case LAErrorUserFallback:{
                msg = @"用户不使用AuthID,选择手动输入密码";
                SNB_AuthIDTypeBlock(biometryType, SNBAuthIDTypeInputPassword, error, msg, nil);
            }
                break;
            case LAErrorSystemCancel:{
                msg = @"AuthID 被系统取消 (如遇到来电,锁屏,按了Home键等)";
                SNB_AuthIDTypeBlock(biometryType, SNBAuthIDTypeSystemCancel, error, msg, nil);
            }
                break;
            case LAErrorPasscodeNotSet:{
                msg = @"AuthID 无法启动,因为用户没有设置密码";
                SNB_AuthIDTypeBlock(biometryType, SNBAuthIDTypePasswordNotSet, error, msg, nil);
            }
                break;
                //case LAErrorTouchIDNotEnrolled:{
            case LAErrorBiometryNotEnrolled:{
                msg = @"AuthID 无法启动,因为用户没有设置 AuthID";
                SNB_AuthIDTypeBlock(biometryType, SNBAuthIDTypeAuthIDNotSet, error, msg, nil);
            }
                break;
                //case LAErrorTouchIDNotAvailable:{
            case LAErrorBiometryNotAvailable:{
                msg = @"AuthID 无效";
                SNB_AuthIDTypeBlock(biometryType, SNBAuthIDTypeAuthIDNotAvailable, error, msg, nil);
            }
                break;
                //case LAErrorTouchIDLockout:{
            case LAErrorBiometryLockout:{
                msg = @"AuthID 被锁定(连续多次验证 AuthID 失败,系统需要用户手动输入密码)";
                SNB_AuthIDTypeBlock(biometryType, SNBAuthIDTypeAuthIDLockout, error, msg, nil);
            }
                break;
            case LAErrorAppCancel:{
                msg = @"当前软件被挂起并取消了授权 (如App进入了后台等)";
                SNB_AuthIDTypeBlock(biometryType, SNBAuthIDTypeAppCancel, error, msg, nil);
            }
                break;
            case LAErrorInvalidContext:{
                msg = @"当前软件被挂起并取消了授权 (LAContext对象无效)";
                SNB_AuthIDTypeBlock(biometryType, SNBAuthIDTypeInvalidContext, error, msg, nil);
            }
                break;
            default:
            {
                NSString *msg = @"";
                if (isSupport) {
                    msg = @"AuthID 验证失败";
                    SNB_AuthIDTypeBlock(biometryType, SNBAuthIDTypeFail, error, msg, nil);
                }else{
                    msg = @"此设备不支持AuthID";
                    SNB_AuthIDTypeBlock(biometryType, SNBAuthIDTypeNotSupport, nil, msg, nil);
                }
            }
                break;
        }
    }else{
        // iOS 11.0以下的版本只有 TouchID 认证
        switch (error.code) {
            case LAErrorAuthenticationFailed:{
                msg = @"AuthID 验证失败";
                SNB_AuthIDTypeBlock(SNBBiometryTouchID, SNBAuthIDTypeFail, error, msg, nil);
            }
                break;
            case LAErrorUserCancel:{
                msg = @"AuthID 被用户手动取消";
                SNB_AuthIDTypeBlock(SNBBiometryTouchID, SNBAuthIDTypeUserCancel, error, msg, nil);
            }
                break;
            case LAErrorUserFallback:{
                msg = @"用户不使用AuthID,选择手动输入密码";
                SNB_AuthIDTypeBlock(SNBBiometryTouchID, SNBAuthIDTypeInputPassword, error, msg, nil);
            }
                break;
            case LAErrorSystemCancel:{
                msg = @"AuthID 被系统取消 (如遇到来电,锁屏,按了Home键等)";
                SNB_AuthIDTypeBlock(SNBBiometryTouchID, SNBAuthIDTypeSystemCancel, error, msg, nil);
            }
                break;
            case LAErrorPasscodeNotSet:{
                msg = @"AuthID 无法启动,因为用户没有设置密码";
                SNB_AuthIDTypeBlock(SNBBiometryTouchID, SNBAuthIDTypePasswordNotSet, error, msg, nil);
            }
                break;
            case LAErrorTouchIDNotEnrolled:{
                msg = @"AuthID 无法启动,因为用户没有设置 AuthID";
                SNB_AuthIDTypeBlock(SNBBiometryTouchID, SNBAuthIDTypeAuthIDNotSet, error, msg, nil);
            }
                break;
                //case :{
            case LAErrorTouchIDNotAvailable:{
                msg = @"AuthID 无效";
                SNB_AuthIDTypeBlock(SNBBiometryTouchID, SNBAuthIDTypeAuthIDNotAvailable, error, msg, nil);
            }
                break;
            case LAErrorTouchIDLockout:{
                msg = @"AuthID 被锁定(连续多次验证 AuthID 失败,系统需要用户手动输入密码)";
                SNB_AuthIDTypeBlock(SNBBiometryTouchID, SNBAuthIDTypeAuthIDLockout, error, msg, nil);
            }
                break;
            case LAErrorAppCancel:{
                msg = @"当前软件被挂起并取消了授权 (如App进入了后台等)";
                SNB_AuthIDTypeBlock(SNBBiometryTouchID, SNBAuthIDTypeAppCancel, error, msg, nil);
            }
                break;
            case LAErrorInvalidContext:{
                msg = @"当前软件被挂起并取消了授权 (LAContext对象无效)";
                SNB_AuthIDTypeBlock(SNBBiometryTouchID, SNBAuthIDTypeInvalidContext, error, msg, nil);
            }
                break;
            default:
            {
                NSString *msg = @"";
                if (isSupport) {
                    msg = @"AuthID 验证失败";
                    SNB_AuthIDTypeBlock(SNBBiometryTouchID, SNBAuthIDTypeFail, error, msg, nil);
                }else{
                    msg = @"此设备不支持Touch ID";
                    SNB_AuthIDTypeBlock(SNBBiometryTouchID, SNBAuthIDTypeNotSupport, nil, msg, nil);
                }
            }
                break;
        }
    }
    NSLog(@"%@", msg);
}

@end
