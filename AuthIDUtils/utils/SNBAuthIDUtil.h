//
//  SNBAuthIDUtil.h
//  SNBAuthIDUtil
//
//  Created by 岳云石 on 2018/6/13.
//  Copyright © 2018年 岳云石. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <LocalAuthentication/LocalAuthentication.h>

/**
 *  AuthID 状态
 */
typedef NS_ENUM(NSUInteger, SNB_AuthIDType){
    
    /**
     *  当前设备不支持AuthID
     */
    SNBAuthIDTypeNotSupport = 0,
    /**
     *  AuthID 验证成功
     */
    SNBAuthIDTypeSuccess,
    /**
     *  AuthID 验证失败
     */
    SNBAuthIDTypeFail,
    /**
     *  AuthID 被用户手动取消
     */
    SNBAuthIDTypeUserCancel,
    /**
     *  用户不使用AuthID,选择手动输入密码
     */
    SNBAuthIDTypeInputPassword,
    /**
     *  AuthID 被系统取消 (如遇到来电,锁屏,按了Home键等)
     */
    SNBAuthIDTypeSystemCancel,
    /**
     *  AuthID 无法启动,因为用户没有设置密码
     */
    SNBAuthIDTypePasswordNotSet,
    /**
     *  AuthID 无法启动,因为用户没有设置AuthID
     */
    SNBAuthIDTypeAuthIDNotSet,
    /**
     *  AuthID 无效
     */
    SNBAuthIDTypeAuthIDNotAvailable,
    /**
     *  AuthID 被锁定(连续多次验证AuthID失败,系统需要用户手动输入密码)
     */
    SNBAuthIDTypeAuthIDLockout,
    /**
     *  当前软件被挂起并取消了授权 (如App进入了后台等)
     */
    SNBAuthIDTypeAppCancel,
    /**
     *  当前软件被挂起并取消了授权 (LAContext对象无效)
     */
    SNBAuthIDTypeInvalidContext,
    /**
     *  系统版本不支持AuthID (必须高于iOS 8.0才能使用)
     */
    SNBAuthIDTypeVersionNotSupport
};

/**
 *  生物识别方式
 */
typedef NS_ENUM(NSUInteger, SNBBiometryType) {
    SNBBiometryNone,
    SNBBiometryTouchID,
    SNBBiometryFaceID,
};

/**
 指纹/面容解锁 回调
 
 @param AuthIDType 返回的类型，SNB_AuthIDType
 @param error error
 @param errorMessage errorMessage
 @param policyDomainState 设备生物识别认证数据（add modify 都会变 只有认证成功之后才会有值）
 */
typedef void (^SNB_AuthID_Block)(SNBBiometryType biometryType, SNB_AuthIDType AuthIDType, NSError *error, NSString *errorMessage, NSData * policyDomainState);

/**
 判断是否支持指纹/面容解锁 回调
 policy:
 LAPolicyDeviceOwnerAuthenticationWithBiometrics iOS8 用这种策略
 LAPolicyDeviceOwnerAuthentication  iOS9 三次失败之后会弹出系统密码输入框过于暴力
 @param isSupport 是否支持
 @param context context
 @param policy policy
 @param error error
 */
typedef void (^SNB_AuthIDVerifyIsSupport_Block)(BOOL isSupport, LAContext *context, NSError *error);


@interface SNBAuthIDUtil : NSObject

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
      snb_authIDTypeBlock:(SNB_AuthID_Block)snb_authIDTypeBlock;

/**
 判断是否支持指纹/面容解锁
 */
+ (void)authIDVerifyIsSupportWithBlock:(SNB_AuthIDVerifyIsSupport_Block)block;

/**
 判断是指纹/面容认证
 */

+ (SNBBiometryType)getBiometryType;

@end
