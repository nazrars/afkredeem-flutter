import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info/package_info.dart';

import 'package:afk_redeem/data/consts.dart';
import 'package:afk_redeem/data/redemption_code.dart';
import 'package:afk_redeem/data/user_message.dart';
import 'package:afk_redeem/data/json_reader.dart';

class Preferences {
  static Preferences? _singleton;
  factory Preferences() {
    return _singleton!;
  }

  SharedPreferences _prefs;
  PackageInfo _packageInfo;

  bool _isHypogean;
  String _userID;
  bool _wasDisclosureApproved;
  bool _wasFirstConnectionSuccessful;
  bool _wasManualRedeemMessageShown;
  int _appInStoreVersion;
  int _redeemApiVersion;
  int _appInStoreApiVersionSupport;
  DateTime _christmasThemeStartDate;
  DateTime _christmasThemeEndDate;

  List<RedemptionCode> redemptionCodes;
  Map<String, RedemptionCode> redemptionCodesMap;

  bool get isHypogean => _isHypogean;
  String get userID => _userID;
  bool get wasDisclosureApproved => _wasDisclosureApproved;
  bool get wasFirstConnectionSuccessful => _wasFirstConnectionSuccessful;
  bool get wasManualRedeemMessageShown => _wasManualRedeemMessageShown;
  int get appInStoreVersion => _appInStoreVersion;
  int get redeemApiVersion => _redeemApiVersion;
  int get appInStoreApiVersionSupport => _appInStoreApiVersionSupport;
  DateTime get christmasThemeStartDate => _christmasThemeStartDate;
  DateTime get christmasThemeEndDate => _christmasThemeEndDate;

  set userID(String value) {
    _userID = value;
    _prefs.setString('userID', value);
  }

  set isHypogean(bool value) {
    _isHypogean = value;
    _prefs.setBool('isHypogean', value);
  }

  set wasDisclosureApproved(bool value) {
    _wasDisclosureApproved = value;
    _prefs.setBool('wasDisclosureApproved', value);
  }

  set wasFirstConnectionSuccessful(bool value) {
    _wasFirstConnectionSuccessful = value;
    _prefs.setBool('wasFirstConnectionSuccessful', value);
  }

  set wasManualRedeemMessageShown(bool value) {
    _wasManualRedeemMessageShown = value;
    _prefs.setBool('wasManualRedeemMessageShown', value);
  }

  set appInStoreVersion(int value) {
    _appInStoreVersion = value;
    _prefs.setInt('appInStoreVersion', value);
  }

  set redeemApiVersion(int value) {
    _redeemApiVersion = value;
    _prefs.setInt('redeemApiVersion', value);
  }

  set appInStoreApiVersionSupport(int value) {
    _appInStoreApiVersionSupport = value;
    _prefs.setInt('appInStoreApiVersionSupport', value);
  }

  set christmasThemeStartDate(DateTime value) {
    _christmasThemeStartDate = value;
    _prefs.setString(
        'christmasThemeStartDate', DateFormat('yyyy-MM-dd').format(value));
  }

  set christmasThemeEndDate(DateTime value) {
    _christmasThemeEndDate = value;
    _prefs.setString(
        'christmasThemeEndDate', DateFormat('yyyy-MM-dd').format(value));
  }

  bool wasAppMessageShown(int messageId) {
    return _prefs.getBool('appMessageShown-$messageId') ?? false;
  }

  void setAppMessageShown(int messageId) {
    _prefs.setBool('appMessageShown-$messageId', true);
  }

  static Future<Preferences> create() async {
    if (_singleton != null) {
      return _singleton!;
    }
    var sharedPreferences = SharedPreferences.getInstance();
    var packageInfo = PackageInfo.fromPlatform();
    _singleton =
        Preferences._create(await sharedPreferences, await packageInfo);
    return _singleton!;
  }

  Preferences._create(this._prefs, this._packageInfo)
      : _isHypogean = _prefs.getBool('isHypogean') ?? true,
        _userID = _prefs.getString('userID') ?? '',
        _wasDisclosureApproved =
            _prefs.getBool('wasDisclosureApproved') ?? false,
        _wasFirstConnectionSuccessful =
            _prefs.getBool('wasFirstConnectionSuccessful') ?? false,
        _wasManualRedeemMessageShown =
            _prefs.getBool('wasManualRedeemMessageShown') ?? false,
        _appInStoreVersion =
            _prefs.getInt('appInStoreVersion') ?? kDefaultAppInStoreVersion,
        _redeemApiVersion =
            _prefs.getInt('redeemApiVersion') ?? kDefaultRedeemApiVersion,
        _appInStoreApiVersionSupport =
            _prefs.getInt('appInStoreApiVersionSupport') ??
                kDefaultAppInStoreApiVersionSupport,
        _christmasThemeStartDate = DateTime.parse(
            _prefs.getString('christmasThemeStartDate') ?? '2222-01-01'),
        _christmasThemeEndDate = DateTime.parse(
            _prefs.getString('christmasThemeEndDate') ?? '2222-01-01'),
        redemptionCodes =
            _codesFromJsonString(_prefs.getString('redemptionCodes')),
        redemptionCodesMap = {} {
    if (wasAppMessageShown(kManualRedeemApiBrutusMessageId)) {
      // old user has seen manual redeem message when it was an api brutus message
      wasManualRedeemMessageShown = true;
    }
    // can't rely on member redemptionCodes in initialization
    redemptionCodesMap = {for (var rc in redemptionCodes) rc.code: rc};
    // sort by isActive & date
    redemptionCodes.sort();

    // set successful first connection for existing users (already have codes)
    if (redemptionCodes.isNotEmpty) {
      wasFirstConnectionSuccessful = true;
    }
  }

  void updateConfigData({
    required Map<String, dynamic> configData,
    required UserErrorHandler userErrorHandler,
    required Function() applyThemeHandler,
  }) {
    JsonReader jsonReader = JsonReader(
      context: 'Preferences::updateConfigData',
      json: configData,
    );
    redeemApiVersion = jsonReader.read('redeemApiVersion');
    if (Platform.isAndroid) {
      appInStoreVersion = jsonReader.read('androidStoreAppVersion');
      appInStoreApiVersionSupport =
          jsonReader.read('androidAppApiVersionSupport');
    } else if (Platform.isIOS) {
      appInStoreVersion = jsonReader.read('iosStoreAppVersion');
      appInStoreApiVersionSupport = jsonReader.read('iosAppApiVersionSupport');
    } else {
      throw Exception('Unsupported platform for api version config data');
    }
    bool wasChristmasTime = isChristmasTime;
    christmasThemeStartDate =
        DateTime.parse(jsonReader.read('christmasThemeStartDate'));
    christmasThemeEndDate =
        DateTime.parse(jsonReader.read('christmasThemeEndDate'));
    if (wasChristmasTime != isChristmasTime) {
      applyThemeHandler(); // christmas changed
    }
  }

  bool get isAppUpgradable {
    return appInStoreVersion > int.parse(_packageInfo.buildNumber);
  }

  bool get isRedeemApiVersionSupported {
    return redeemApiVersion <= kRedeemApiVersion;
  }

  bool get isRedeemApiVersionUpgradable {
    return redeemApiVersion <= appInStoreApiVersionSupport;
  }

  bool get isChristmasTime {
    return DateTime.now().isAfter(_christmasThemeStartDate) &&
        DateTime.now().isBefore(_christmasThemeEndDate);
  }

  void updateRedeemedCodes(List<RedemptionCode> redeemed) {
    for (RedemptionCode redeemedCode in redeemed) {
      redemptionCodesMap[redeemedCode.code]?.wasRedeemed = true;
    }
    _prefs.setString('redemptionCodes', _codesToJsonString(redemptionCodes));
  }

  void updateCodesFromExternalSource({
    required List<dynamic> newCodesJson,
    required UserErrorHandler? userErrorHandler,
  }) {
    wasFirstConnectionSuccessful = true;
    List<RedemptionCode> newCodes =
        _codesFromJson(newCodesJson, userErrorHandler: userErrorHandler);
    if (redemptionCodes.isEmpty) {
      // first codes update
      redemptionCodes = newCodes;
      redemptionCodes.forEach((rc) {
        rc.wasRedeemed = true; // mark all redeemed
      });
      redemptionCodesMap = {for (var rc in redemptionCodes) rc.code: rc};
    } else {
      for (RedemptionCode newRC in newCodes) {
        if (redemptionCodesMap.containsKey(newRC.code)) {
          redemptionCodesMap[newRC.code]!.updateFromExternalSource(newRC);
        } else {
          redemptionCodes.add(newRC);
          redemptionCodesMap[newRC.code] = newRC;
        }
      }
    }
    // sort by isActive & date
    redemptionCodes.sort();
    _prefs.setString('redemptionCodes', _codesToJsonString(redemptionCodes));
  }

  static List<RedemptionCode> _codesFromJsonString(String? codesJsonString) {
    return codesJsonString == null
        ? []
        : _codesFromJson(json.decode(codesJsonString));
  }

  static List<RedemptionCode> _codesFromJson(List<dynamic> jsonCodes,
      {UserErrorHandler? userErrorHandler}) {
    List<RedemptionCode> codes = [];
    JsonReader jsonReader = JsonReader(
      context: 'Reading redemption codes json',
    );
    for (dynamic codeJson in jsonCodes) {
      jsonReader.json = codeJson;
      codes.add(RedemptionCode.fromJson(jsonReader));
    }
    return codes;
  }

  static String _codesToJsonString(List<RedemptionCode> redemptionCodes) {
    return jsonEncode(redemptionCodes);
  }
}
