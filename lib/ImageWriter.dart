import 'dart:io';
import 'dart:async';
import 'dart:convert';
// import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:LoliSnatcher/libBooru/BooruItem.dart';
import 'package:LoliSnatcher/ServiceHandler.dart';
import 'package:LoliSnatcher/SettingsHandler.dart';

import 'libBooru/Booru.dart';

// move writing to separate thread, so the app won't hang while it saves - Leads to memory leak!
// Future<void> writeBytesIsolate(Map<String, dynamic> map) async {
//   await map['file'].writeAsBytes(map['bytes']);
//   return;
// }

class ImageWriter {
  final SettingsHandler settingsHandler = Get.find();
  String? path = "";
  String? cacheRootPath = "";
  ServiceHandler serviceHandler = ServiceHandler();
  int SDKVer = 0;

  ImageWriter() {
    setPaths();
  }
  /**
   * return null - file already exists
   * return String - file saved
   * return Error - something went wrong
   */
  Future write(BooruItem item, Booru booru) async {
    int queryLastIndex = item.fileURL.lastIndexOf("?");
    int lastIndex = queryLastIndex != -1 ? queryLastIndex : item.fileURL.length;
    String fileName = "";
    if (booru.type == ("BooruOnRails") || booru.type == "Philomena"){
      fileName = booru.name! + '_' + item.serverId! + "." + item.fileExt!;
    } else if (booru.type == "Hydrus"){
      fileName = "Hydrus_${item.md5String}.${item.fileExt}";
    } else {
      fileName = booru.name! + '_' + item.fileURL.substring(item.fileURL.lastIndexOf("/") + 1, lastIndex);
    }
    print("out file is $fileName");
    // print(fileName);
    await setPaths();

    if(SDKVer == 0){
        SDKVer = await serviceHandler.getSDKVersion();
        print(SDKVer);
    }

    // Don't do anything if file already exists
    File image = File(path! + fileName);
    // print(path! + fileName);
    bool fileExists = await image.exists();
    if(fileExists || item.isSnatched.value) return null;
    try {
      Uri fileURI = Uri.parse(item.fileURL);
      var response = await http.get(fileURI);
      if (SDKVer < 30) {
        await Directory(path!).create(recursive:true);
        await image.writeAsBytes(response.bodyBytes, flush: true);
        print("Image written: " + path! + fileName);
        if (settingsHandler.jsonWrite){
          File json = File(path! + fileName.split(".")[0]+".json");
          await json.writeAsString(jsonEncode(item.toJSON()), flush: true);
        }
        item.isSnatched.value = true;
        if (settingsHandler.dbEnabled){
          settingsHandler.dbHandler.updateBooruItem(item,"local");
        }
        try {
          if(Platform.isAndroid){
            serviceHandler.callMediaScanner(image.path);
          }
        } catch (e){
          print("Image not found");
          return e;
        }
      } else {
        print("files ext is " + item.fileExt!);
        //if (item.fileExt.toUpperCase() == "PNG" || item.fileExt.toUpperCase() == "JPEG" || item.fileExt.toUpperCase() == "JPG"){
          var writeResp = await serviceHandler.writeImage(response.bodyBytes, fileName.split(".")[0], item.mediaType, item.fileExt);
          if (writeResp != null){
            print("write response: $writeResp");
            item.isSnatched.value = true;
            if (settingsHandler.dbEnabled){
              settingsHandler.dbHandler.updateBooruItem(item,"local");
            }
            return (fileName);
          }
        //} else {
         // Get.snackbar("File write error","Only jpg and png can be saved on android 11 currently",snackPosition: SnackPosition.BOTTOM,duration: Duration(seconds: 5),colorText: Colors.black, backgroundColor: Get.theme.primaryColor);
         // return 0;
        //}

      }
    } catch (e){
      print("Image Writer Exception");
      print(e);
      return e;
    }
    return (fileName);
  }

  Stream<int> writeMultiple(List<BooruItem> snatched, Booru booru, int cooldown) async* {
    int snatchedCounter = 1;
    List<String> existsList = [];
    List<String> failedList = [];
    for (int i = 0; i < snatched.length ; i++){
      await Future.delayed(Duration(milliseconds: cooldown), () async{
        var snatchResult = await write(snatched.elementAt(i), booru);
        if (snatchResult == null){
          existsList.add(snatched[i].fileURL);
        } else if (snatchResult is !String) {
          failedList.add(snatched[i].fileURL);
        }
      });
      yield snatchedCounter++;
    }
    String toastString = "Snatching Complete ¡¡¡( •̀ ᴗ •́ )و!!! \n";
    if (existsList.length > 0){
      toastString += "Some files were already snatched! \n File Count: ${existsList.length} \n";
    }
    if (failedList.length > 0){
      toastString += "Snatching failed for some files!  \n File Count: ${failedList.length} \n";
    }
    ServiceHandler.displayToast(toastString);
  }

  Future writeCache(String fileURL, String typeFolder) async{
    String? cachePath;
    Uri fileURI = Uri.parse(fileURL);
    try {
      var response = await http.get(fileURI);
      await setPaths();
      cachePath = cacheRootPath! + typeFolder + "/";
      await Directory(cachePath).create(recursive:true);

      String fileName = sanitizeName(parseThumbUrlToName(fileURL));
      File image = File(cachePath+fileName);
      await image.writeAsBytes(response.bodyBytes, flush: true);
    } catch (e){
      print("Image Writer Exception:: cache write");
      print(e);
    }
    return (cachePath!+fileURL.substring(fileURL.lastIndexOf("/") + 1));
  }

  Future<File?> writeCacheFromBytes(String fileURL, List<int> bytes, String typeFolder, {bool clearName = true}) async{
    File? image;
    try {
      await setPaths();
      String cachePath = cacheRootPath! + typeFolder + "/";
      // print("write cahce from bytes:: cache path is $cachePath");
      await Directory(cachePath).create(recursive:true);

      String fileName = sanitizeName(clearName ? parseThumbUrlToName(fileURL) : fileURL);
      image = File(cachePath + fileName);
      await image.writeAsBytes(bytes, flush: true);

      // move writing to separate thread, so the app won't hang while it saves - Leads to memory leak!
      // await compute(writeBytesIsolate, {"file": image, "bytes": bytes});
    } catch (e){
      print("Image Writer Exception:: cache write");
      print(e);
      return null;
    }
    return image;
  }

  // Deletes file from given cache folder
  // returns true if successful, false if there was an exception and null if file didn't exist
  Future deleteFileFromCache(String fileURL, String typeFolder) async {
    try {
      await setPaths();
      String cachePath = cacheRootPath! + typeFolder + "/";
      String fileName = sanitizeName(parseThumbUrlToName(fileURL));
      File file = File(cachePath + fileName);
      if (await file.exists()) {
        file.delete();
        return true;
      } else {
        return null;
      }
    } catch (e){
      print("Image Writer Exception");
      print(e);
      return false;
    }
  }

  Future deleteCacheFolder(String typeFolder) async {
    try {
      await setPaths();
      String cachePath = cacheRootPath! + typeFolder + "/";
      Directory folder = Directory(cachePath);
      if (await folder.exists()) {
        folder.delete(recursive: true);
        return true;
      } else {
        return null;
      }
    } catch (e){
      print("Image Writer Exception");
      print(e);
      return false;
    }
  }

  Future<String?> getCachePath(String fileURL, String typeFolder, {bool clearName = true}) async{
    String cachePath;
    try {
      await setPaths();
      cachePath = cacheRootPath! + typeFolder + "/";

      String fileName = sanitizeName(clearName ? parseThumbUrlToName(fileURL) : fileURL);
      File cacheFile = File(cachePath+fileName);
      bool fileExists = await cacheFile.exists();
      bool fileIsNotEmpty = (await cacheFile.stat()).size > 0;
      if (fileExists){
        if(fileIsNotEmpty) {
          return cachePath+fileName;
        } else {
          // somehow some files can save with zero bytes - we remove them
          cacheFile.delete();
          return null;
        }
      } else {
        return null;
      }
    } catch (e){
      print("Image Writer Exception");
      print(e);
      return null;
    }
  }

  // calculates cache (total or by type) size and file count
  Future<Map<String,int>> getCacheStat(String? typeFolder) async {
    String cacheDirPath;
    int fileNum = 0;
    int totalSize = 0;
    try {
      await setPaths();
      cacheDirPath = cacheRootPath! + (typeFolder ?? '') + "/";

      Directory cacheDir = Directory(cacheDirPath);
      bool dirExists = await cacheDir.exists();
      if (dirExists) {
        cacheDir.listSync(recursive: true, followLinks: false)
          .forEach((FileSystemEntity entity) {
            if (entity is File) {
              fileNum++;
              totalSize += entity.lengthSync();
            }
          });
      }
    } catch (e){
      print("Image Writer Exception");
      print(e);
    }

    return {'fileNum': fileNum, 'totalSize': totalSize};
  }

  String parseThumbUrlToName(String thumbURL) {
    int queryLastIndex = thumbURL.lastIndexOf("?"); // Sankaku fix
    int lastIndex = queryLastIndex != -1 ? queryLastIndex : thumbURL.length;
    String result = thumbURL.substring(thumbURL.lastIndexOf("/") + 1, lastIndex);
    if(result.startsWith('thumb.')) { //Paheal/shimmie(?) fix
      String unthumbedURL = thumbURL.replaceAll('/thumb', '');
      result = unthumbedURL.substring(unthumbedURL.lastIndexOf("/") + 1);
    }
    return result;
  }

  String sanitizeName(String fileName, {String replacement = ''}) {
    RegExp illegalRe = RegExp(r'[\/\?<>\\:\*\|"]');
    RegExp controlRe = RegExp(r'[\x00-\x1f\x80-\x9f]');
    RegExp reservedRe = RegExp(r'^\.+$');
    RegExp windowsReservedRe = RegExp(r'^(con|prn|aux|nul|com[0-9]|lpt[0-9])(\..*)?$', caseSensitive: false);
    RegExp windowsTrailingRe = RegExp(r'[\. ]+$');

    return fileName
      .replaceAll(illegalRe, replacement)
      .replaceAll(controlRe, replacement)
      .replaceAll(reservedRe, replacement)
      .replaceAll(windowsReservedRe, replacement)
      .replaceAll(windowsTrailingRe, replacement);
    // TODO truncate to 255 symbols for windows?
  }

  Future<bool> setPaths() async {
    if(path == ""){
      if (settingsHandler.extPathOverride.isEmpty){
        path = await serviceHandler.getPicturesDir();
      } else {
        path = settingsHandler.extPathOverride;
      }
    }

    if(cacheRootPath == ""){
      cacheRootPath = await serviceHandler.getCacheDir();
    }
    // print('path: $path');
    // print(cache'path: $cacheRootPath');
    return true;
  }
}