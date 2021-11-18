import Flutter
import UIKit
import UserNotifications
import MarketingCloudSDK

public class SwiftMarketingCloudMessagingFlutterPlugin:
  NSObject,
  FlutterPlugin,
  MarketingCloudSDKEventDelegate,
  MarketingCloudSDKURLHandlingDelegate
{
  let inbox = true
  let location = false
  let analytics = true
  let piAnalytics = true
  
  private var channel: FlutterMethodChannel?
  private var resumingFromBackground: Bool = false
  private var launchNotification: [AnyHashable : Any]? = nil
   
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "marketing_cloud_messaging_flutter", binaryMessenger: registrar.messenger())
    let instance = SwiftMarketingCloudMessagingFlutterPlugin()
    
    registrar.addApplicationDelegate(instance)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch(call.method){
    case "initialize":
      if let args = call.arguments as? Dictionary<String, Any>,
        let appID = args["appID"] as? String,
        let accessToken = args["accessToken"] as? String,
        let appEndpoint = args["appEndpoint"] as? String,
        let mid = args["mid"] as? String
      {
        result(self.configureMarketingCloudSDK(appID: appID,accessToken: accessToken,appEndpoint: appEndpoint,mid: mid))
      } else {
        result(FlutterError.init(code: "errorSetDebug", message: "data or format error", details: nil))
      }
      case "setMessagingToken": result(true)
      case "getMessagingToken": result(MarketingCloudSDK.sharedInstance().sfmc_deviceToken())
      case "setAttribute":
        if let args = call.arguments as? Dictionary<String, Any>,
          let key = args["key"] as? String,
          let value = args["value"] as? String {
          result(MarketingCloudSDK.sharedInstance().sfmc_setAttributeNamed(key, value: value))
        } else {
          result(FlutterError.init(code: "errorSetDebug", message: "data or format error", details: nil))
        }
      case "addTags":
        if let args = call.arguments as? Dictionary<String, Any>,
          let tags = args["tags"] as? [String]{
            result(MarketingCloudSDK.sharedInstance().sfmc_addTags(tags))
        } else {
          result(FlutterError.init(code: "errorSetDebug", message: "data or format error", details: nil))
        }
      case "removeTags":
        if let args = call.arguments as? Dictionary<String, Any>,
          let tags = args["tags"] as? [String]{
            result(MarketingCloudSDK.sharedInstance().sfmc_removeTags(tags))
        } else {
          result(FlutterError.init(code: "errorSetDebug", message: "data or format error", details: nil))
        }
      case "setUserId":
        if let args = call.arguments as? Dictionary<String, Any>,
          let id = args["id"] as? String{
            result(MarketingCloudSDK.sharedInstance().sfmc_setContactKey(id))
        } else {
          result(FlutterError.init(code: "errorSetDebug", message: "data or format error", details: nil))
        }
      case "sdkState":
          print("SDK State = \(MarketingCloudSDK.sharedInstance().sfmc_getSDKState() ?? "SDK State is nil")")
      case "trackCart": MarketingCloudSDK.sharedInstance().sfmc_trackCartContents(call.arguments as! [AnyHashable : Any])
      case "trackConversion": MarketingCloudSDK.sharedInstance().sfmc_trackCartConversion(call.arguments as! [AnyHashable : Any])
      case "trackPageView":
        if let args = call.arguments as? Dictionary<String, Any>,
         let url = args["url"] as? String,
         let title = args["title"] as? String,
         let item = args["item"] as? String,
         let search = args["search"] as? String {
           MarketingCloudSDK.sharedInstance().sfmc_trackPageView(withURL: url,title: title,item: item,search: search)
         } else {
           result(FlutterError.init(code: "errorSetDebug", message: "data or format error", details: nil))
         }
    default: result(FlutterMethodNotImplemented)
    }
  }
    
    
  func configureMarketingCloudSDK(
    appID: String,
    accessToken: String,
    appEndpoint: String,
    mid: String
  ) -> Bool {
    let builder = MarketingCloudSDKConfigBuilder()
        .sfmc_setApplicationId(appID)
        .sfmc_setAccessToken(accessToken)
        .sfmc_setMarketingCloudServerUrl(appEndpoint)
        .sfmc_setMid(mid)
        .sfmc_setInboxEnabled(NSNumber(value: inbox))
        .sfmc_setLocationEnabled(NSNumber(value: location))
        .sfmc_setAnalyticsEnabled(NSNumber(value: analytics))
        .sfmc_setPiAnalyticsEnabled(NSNumber(value: piAnalytics))
        .sfmc_build()!
            
    var success = false
    var msg = ""
    
    do {
      try MarketingCloudSDK.sharedInstance().sfmc_configure(with:builder)
      success = true
    } catch let error as NSError {
        msg = String(format: "MarketingCloudSDK sfmc_configure failed with error = %@", error)
        logMessage(msg)
    }
    
    
    if success {
      #if DEBUG
      MarketingCloudSDK.sharedInstance().sfmc_setDebugLoggingEnabled(true)
      #endif
      
      MarketingCloudSDK.sharedInstance().sfmc_setEventDelegate(self)
      MarketingCloudSDK.sharedInstance().sfmc_setURLHandlingDelegate(self)

      DispatchQueue.main.async {
          if #available(iOS 10.0, *) {
              UNUserNotificationCenter.current().delegate = self
              UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge], completionHandler: {(_ granted: Bool, _ error: Error?) -> Void in
                  if error == nil {
                      if granted {
                        let deviceToken = MarketingCloudSDK.sharedInstance().sfmc_deviceToken()

                        if deviceToken == nil {
                            self.logMessage("error: no token - was UIApplication.shared.registerForRemoteNotifications() called?")
                        } else {
                            let token = deviceToken ?? "** empty **"
                            self.logMessage("success: token - was \(token)")
                        }
                      }
                  }
              })
          }
          
          UIApplication.shared.registerForRemoteNotifications()
        
          if self.launchNotification != nil {
            self.channel?.invokeMethod("onLaunch", arguments: self.launchNotification!)
          }
      }
    }
    
    return success
  }
  
  
  private func logMessage(_ s: String) {
      print("Marketing Cloud: \(s)")
  }
  
  public func sfmc_handle(_ url: URL, type: String) {
    UIApplication.shared.open(url, options: [:],
      completionHandler: {
        (success) in
        print("Open \(url): \(success)")
    })
  }
  
  // MobilePush SDK: REQUIRED IMPLEMENTATION
  // The method will be called on the delegate when the user responded to the notification by opening the application, dismissing the notification or choosing a UNNotificationAction. The delegate must be set before the application returns from applicationDidFinishLaunching:.
  @available(iOS 10.0, *)
  public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
      // Required: tell the MarketingCloudSDK about the notification. This will collect MobilePush analytics
      // and process the notification on behalf of your application.
      MarketingCloudSDK.sharedInstance().sfmc_setNotificationRequest(response.notification.request)
      completionHandler()
  }
  
  // MobilePush SDK: REQUIRED IMPLEMENTATION
  // The method will be called on the delegate only if the application is in the foreground. If the method is not implemented or the handler is not called in a timely manner then the notification will not be presented. The application can choose to have the notification presented as a sound, badge, alert and/or in the notification list. This decision should be based on whether the information in the notification is otherwise visible to the user.
  @available(iOS 10.0, *)
  public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    logMessage("willPresent")
    completionHandler(UNNotificationPresentationOptions.alert)
  }
  
  
  public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
      logMessage("didReceiveRemoteNotification")
      MarketingCloudSDK.sharedInstance().sfmc_setNotificationUserInfo(userInfo)
    
      if (resumingFromBackground) {
          channel?.invokeMethod("onResume", arguments: userInfo)
      } else {
          channel?.invokeMethod("onMessage", arguments: userInfo)
      }

      for key in userInfo.keys {
          guard let key = key as? String else {
              continue
          }
          if let object = userInfo[key] {
              logMessage("property value: \(object)")
          }
      }
  }
  
  public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
      MarketingCloudSDK.sharedInstance().sfmc_setDeviceToken(deviceToken)
  }
  
  public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
      logMessage("\(error.localizedDescription)")
  }
  
  @nonobjc public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable : Any] = [:]) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    launchNotification = launchOptions[UIApplication.LaunchOptionsKey.remoteNotification] as? [AnyHashable: Any]
    return true
  }
  
  public func applicationDidBecomeActive(_ application: UIApplication) {
      resumingFromBackground = false
      application.applicationIconBadgeNumber = 1
      application.applicationIconBadgeNumber = 0
  }
  
  public func applicationDidEnterBackground(_ application: UIApplication) {
      resumingFromBackground = true
  }
}
