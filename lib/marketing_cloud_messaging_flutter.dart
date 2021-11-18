import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef MessageHandler = Future<dynamic> Function(Map<String, dynamic> message);

void _mcSetupBackgroundChannel(
    {MethodChannel backgroundChannel =
        const MethodChannel('marketing_cloud_messaging_background')}) async {
  WidgetsFlutterBinding.ensureInitialized();

  backgroundChannel.setMethodCallHandler((MethodCall call) async {
    if (call.method == 'handleBackgroundMessage') {
      final CallbackHandle handle =
          CallbackHandle.fromRawHandle(call.arguments['handle']);
      final Function? handlerFunction =
          PluginUtilities.getCallbackFromHandle(handle);

      try {
        await handlerFunction!(
            Map<String, dynamic>.from(call.arguments['message']));
      } catch (e) {
        print('Unable to handle incoming background message.');
        print(e);
      }
      return Future<void>.value();
    }
  });

  backgroundChannel.invokeMethod<void>('McDartService#initialized');
}

class MarketingCloudMessaging {
  static const MethodChannel _channel =
      MethodChannel('marketing_cloud_messaging_flutter');

  late MessageHandler _onMessage;
  late MessageHandler _onLaunch;
  late MessageHandler _onResume;
  MessageHandler? _onBackgroundMessage;

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  Future<void> initialize({
    required String appID,
    required String accessToken,
    required String senderId,
    required String marketingCloudServerUrl,
    required String mid,
    required MessageHandler onMessage,
    required MessageHandler onLaunch,
    required MessageHandler onResume,
    MessageHandler? onBackgroundMessage,
  }) async {
    _onMessage = onMessage;
    _onLaunch = onLaunch;
    _onResume = onResume;
    _channel.setMethodCallHandler(_handleMethod);

    await _channel.invokeMethod<void>(
      'initialize',
      {
        'appID': appID,
        'accessToken': accessToken,
        'senderId': senderId,
        'appEndpoint': marketingCloudServerUrl,
        'mid': mid
      },
    );

    if (onBackgroundMessage != null) {
      _onBackgroundMessage = onBackgroundMessage;
      final CallbackHandle? backgroundSetupHandle =
          PluginUtilities.getCallbackHandle(_mcSetupBackgroundChannel);
      final CallbackHandle? backgroundMessageHandle =
          PluginUtilities.getCallbackHandle(_onBackgroundMessage!);

      if (backgroundMessageHandle == null) {
        throw ArgumentError(
          '''Failed to setup background message handler! `onBackgroundMessage`
          should be a TOP-LEVEL OR STATIC FUNCTION and should NOT be tied to a
          class or an anonymous function.''',
        );
      }

      _channel.invokeMethod<bool>(
        'McDartService#start',
        <String, dynamic>{
          'setupHandle': backgroundSetupHandle!.toRawHandle(),
          'backgroundHandle': backgroundMessageHandle.toRawHandle()
        },
      );
    }
  }

  void setMessagingToken(String token) {
    _channel.invokeMethod('setMessagingToken', {'token': token});
  }

  void setUserId(String id) {
    _channel.invokeMethod<void>('setUserId', {'id': id});
  }

  void logSdkState() {
    _channel.invokeMethod<void>('sdkState');
  }

  Future<String?> get getMessagingToken {
    return _channel.invokeMethod('getMessagingToken');
  }

  Future<bool> isMarketingCloudPush(Map message) {
    if (Platform.isAndroid) {
      return _channel.invokeMethod('isMarketingCloudPush', {'message': message})
          as Future<bool>;
    }

    return Future.value(false);
  }

  void setAttribute(String key, String value) {
    _channel.invokeMethod<void>('setAttribute', {'key': key, 'value': value});
  }

  void addTags(List<String> tags) {
    _channel.invokeMethod<void>('addTags', {'tags': tags});
  }

  void removeTags(List<String> tags) {
    _channel.invokeMethod<void>('removeTags', {'tags': tags});
  }

  void trackCart({
    required String item,
    required int quantity,
    required double value,
    required String id,
  }) {
    _channel.invokeMethod<void>('trackCart', {
      'item': item,
      'quantity': quantity,
      'value': value,
      'id': id,
    });
  }

  void trackConversion({
    required String item,
    required int quantity,
    required double value,
    required String id,
    required String order,
    required double shipping,
    required double discount,
  }) {
    _channel.invokeMethod<void>('trackConversion', {
      'item': item,
      'quantity': quantity,
      'value': value,
      'id': id,
      'order': order,
      'shipping': shipping,
      'discount': discount
    });
  }

  void trackPageViews({
    required String url,
    String title = '',
    String item = '',
    String searchTerms = '',
  }) {
    _channel.invokeMethod<void>(
      'trackPageView',
      {
        'url': url,
        'title': title,
        'item': item,
        'searchTerms': searchTerms,
      },
    );
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case "onMessage":
        return _onMessage(call.arguments.cast<String, dynamic>());
      case "onLaunch":
        return _onLaunch(call.arguments.cast<String, dynamic>());
      case "onResume":
        return _onResume(call.arguments.cast<String, dynamic>());
      default:
        throw UnsupportedError("Unrecognized JSON message");
    }
  }
}
