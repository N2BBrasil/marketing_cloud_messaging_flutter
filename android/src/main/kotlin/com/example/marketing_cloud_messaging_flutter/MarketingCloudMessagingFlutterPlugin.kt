package com.example.marketing_cloud_messaging_flutter

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.annotation.NonNull
import com.salesforce.marketingcloud.MCLogListener
import com.salesforce.marketingcloud.MarketingCloudConfig
import com.salesforce.marketingcloud.MarketingCloudSdk
import com.salesforce.marketingcloud.analytics.PiCart
import com.salesforce.marketingcloud.analytics.PiCartItem
import com.salesforce.marketingcloud.analytics.PiOrder
import com.salesforce.marketingcloud.messages.iam.InAppMessage
import com.salesforce.marketingcloud.messages.iam.InAppMessageManager
import com.salesforce.marketingcloud.messages.push.PushMessageManager
import com.salesforce.marketingcloud.notifications.NotificationCustomizationOptions
import com.salesforce.marketingcloud.sfmcsdk.BuildConfig
import com.salesforce.marketingcloud.sfmcsdk.SFMCSdk
import com.salesforce.marketingcloud.sfmcsdk.SFMCSdkModuleConfig

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.*

class MarketingCloudMessagingFlutterPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel
  private lateinit var context: Context
  private var blockedMessageId: String? = null

  private var inbox = true
  private var analytics = true
  private var piAnalytics = true

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "marketing_cloud_messaging_flutter")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
        "getPlatformVersion" -> {
          result.success("Android ${android.os.Build.VERSION.RELEASE}")
        }
        "initialize" -> {
          initialize(
            call.argument<String>("appID")!!,
            call.argument<String>("accessToken")!!,
            call.argument<String>("senderId")!!,
            call.argument<String>("appEndpoint")!!,
            call.argument<String>("mid")!!
          )
        }
        "setUserId" -> {
          setUserId(call.argument<String>("id")!!)
        }
        "setMessagingToken" -> {
          setMessagingToken(call.argument<String>("token")!!)
        }
        "getMessagingToken" -> {
          SFMCSdk.requestSdk { sdk ->
            sdk.mp {
              it.pushMessageManager.pushToken?.let {
                token -> result.success(token)
              }
            }
          }
        }
        "isMarketingCloudPush" -> {
          result.success(PushMessageManager.isMarketingCloudPush(call.argument<Map<String, String>>("message")!!))
        }
        "sdkState" -> {
          SFMCSdk.requestSdk { sdk ->
              Log.d("SDK STATE", sdk.getSdkState().toString())
          }
        }
        "setAttribute" -> {
            setAttribute(
                call.argument<String>("key")!!,
                call.argument<String>("value")!!
            )
        }
        "addTags" -> { addTags(call.argument<List<String>>("tags")!!) }
        "removeTags" -> { removeTags(call.argument<List<String>>("tags")!!) }
        "trackCart" -> {
          trackCart(
            call.argument<String>("item")!!,
            call.argument<Int>("quantity")!!,
            call.argument<Double>("value")!!,
            call.argument<String>("id")!!
          )
        }
        "trackConversion" -> {
          trackConversion(
            call.argument<String>("item")!!,
            call.argument<Int>("quantity")!!,
            call.argument<Double>("value")!!,
            call.argument<String>("id")!!,
            call.argument<String>("order")!!,
            call.argument<Double>("shipping")!!,
            call.argument<Double>("discount")!!
          )
        }
        "trackPageView" -> {
          trackPageView(
            call.argument<String>("url")!!,
            call.argument<String>("title"),
            call.argument<String>("item"),
            call.argument<String>("searchTerms"),
          )
        }
        else -> {
          result.notImplemented()
        }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  @SuppressLint("UnspecifiedImmutableFlag")
  private fun initialize(appID: String, accessToken: String, senderID: String, appEndpoint: String, mid: String) {
    if(BuildConfig.DEBUG) {
      MarketingCloudSdk.setLogLevel(MCLogListener.VERBOSE)
      MarketingCloudSdk.setLogListener(MCLogListener.AndroidLogListener())
    }

    SFMCSdk.configure(context, SFMCSdkModuleConfig.build {
      pushModuleConfig = MarketingCloudConfig.builder().apply {
        setApplicationId(appID)
        setAccessToken(accessToken)
//        setSenderId(senderID)
        setMarketingCloudServerUrl(appEndpoint)
        setMid(mid)
        setNotificationCustomizationOptions(NotificationCustomizationOptions.create(R.drawable.notification_icon))
        setAnalyticsEnabled(analytics)
        setPiAnalyticsEnabled(piAnalytics)
        setInboxEnabled(inbox)
        setDelayRegistrationUntilContactKeyIsSet(true)
        setUrlHandler { context, url, _ ->
          PendingIntent.getActivity(
            context,
            Random().nextInt(),
            Intent(Intent.ACTION_VIEW, Uri.parse(url)),
            PendingIntent.FLAG_UPDATE_CURRENT
          )
        }
      }.build(context)
    }) { initStatus ->
      Log.d("INIT STATUS",initStatus.toString())
    }
  }

  private fun setUserId(id: String) {
    SFMCSdk.requestSdk { sdk ->
        sdk.identity.setProfileId(id)
    }
  }

  private fun setMessagingToken(token: String) {
    SFMCSdk.requestSdk { sdk ->
        sdk.mp {
            it.pushMessageManager.setPushToken(token)
        }
    }
  }

  private fun setAttribute(key: String, value: String) {
    SFMCSdk.requestSdk { sdk ->
        sdk.identity.run {
            setProfileAttribute(key, value)
        }
    }
  }

  private fun addTags(tags: List<String>) {
    SFMCSdk.requestSdk { sdk ->
      sdk.mp {
        it.registrationManager.edit().run {
          addTags(tags)
          commit()
        }
      }
    }
  }

  private fun removeTags(tags: List<String>) {
    SFMCSdk.requestSdk { sdk ->
      sdk.mp {
        it.registrationManager.edit().run {
          removeTags(tags)
          commit()
        }
      }
    }
  }

  private fun trackCart(item: String, quantity: Int, value: Double, id: String) {
    SFMCSdk.requestSdk { sdk ->
      sdk.mp {
        val cartItem = PiCartItem(item, quantity, value, id)
        val cart = PiCart(listOf(cartItem))

        it.analyticsManager.trackCartContents(cart)
      }
    }
  }

  private fun trackConversion(item: String, quantity: Int, value: Double, id: String, order: String, shipping: Double, discount: Double) {
    SFMCSdk.requestSdk { sdk ->
      sdk.mp {
        val cartItem = PiCartItem(item, quantity, value, id)
        val cart = PiCart(listOf(cartItem))
        val piOrder = PiOrder(cart, order, shipping, discount)

        it.analyticsManager.trackCartConversion(piOrder)
      }
    }
  }

  private fun trackPageView(url: String, title: String?, item: String?, searchTerms: String?) {
    SFMCSdk.requestSdk { sdk ->
      sdk.mp {
        it.analyticsManager.trackPageView(url, title, item, searchTerms)
      }
    }
  }
}
