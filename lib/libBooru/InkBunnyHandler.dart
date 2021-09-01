import 'dart:convert';
import 'dart:math';

import 'package:LoliSnatcher/utilities/Logger.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'dart:async';
import 'BooruHandler.dart';
import 'BooruItem.dart';
import 'Booru.dart';

/**
 * Booru Handler for the gelbooru engine
 */
class InkBunnyHandler extends BooruHandler{
  String resultsID = "";
  String sessionToken = "";
  @override
  bool tagSearchEnabled = false;
  bool hasSizeData = true;
  // Dart constructors are weird so it has to call super with the args
  InkBunnyHandler(Booru booru, int limit) : super(booru, limit);

  Future<bool> setSessionToken() async {
    //https://inkbunny.net/api_login.php?output_mode=xml&username=guest
    //https://inkbunny.net/api_login.php?output_mode=xml&username=myusername&password=mypassword
    String url = "${booru.baseURL}/api_login.php?output_mode=json";
    if (booru.apiKey!.isEmpty && booru.userID!.isEmpty){
        url += "&username=guest";
    } else {
      url += "&username=${booru.userID}&password=${booru.apiKey}";
    }
    try{
      final response = await http.get(Uri.parse(url),headers: getHeaders());
      Map<String, dynamic> parsedResponse = jsonDecode(response.body);
      if (parsedResponse["sid"] != null){
        sessionToken = parsedResponse["sid"].toString();
        Logger.Inst().log("Inkbunny session token found: $sessionToken", "InkBunnyHandler", "getSessionToken", LogTypes.booruHandlerInfo);
        await setRatingOptions();
      } else {
        Logger.Inst().log("Inkbunny couldn't get session token", "InkBunnyHandler", "getSessionToken", LogTypes.booruHandlerInfo);
      }
    } catch (e){
      Logger.Inst().log("Exception getting session token: $url " + e.toString(), "InkBunnyHandler", "getSessionToken", LogTypes.booruHandlerInfo);
    }
    return sessionToken.isEmpty ? false : true;
  }

  Future<bool> setRatingOptions() async {
    String url = "${booru.baseURL}/api_userrating.php?output_mode=json&sid=$sessionToken&tag[2]=yes&tag[3]=yes&tag[4]=yes&tag[5]=yes";
    try{
      final response = await http.get(Uri.parse(url),headers: getHeaders());
      Map<String, dynamic> parsedResponse = jsonDecode(response.body);
      if (parsedResponse["sid"] != null){
        if (sessionToken == parsedResponse["sid"]){
          Logger.Inst().log("Inkbunny set ratings", "InkBunnyHandler", "setRatingOptions", LogTypes.booruHandlerInfo);
        }
      } else {
        Logger.Inst().log("Inkbunny failed to set ratings", "InkBunnyHandler", "setRatingOptions", LogTypes.booruHandlerInfo);
      }
    } catch (e){
      Logger.Inst().log("Exception setting ratings " + e.toString(), "InkBunnyHandler", "setRatingOptions", LogTypes.booruHandlerInfo);
    }
    return true;
  }

  /**
   * This function will call a http get request using the tags and pagenumber parsed to it
   * it will then create a list of booruItems
   */
  Future Search(String tags, int? pageNumCustom) async{
    if (sessionToken.isEmpty){
      bool gotToken = await setSessionToken();
      if (!gotToken){
        return fetched;
      }
    }
    tags = validateTags(tags);
    if (prevTags != tags){
      fetched.value = [];
      resultsID = "";
    }

    String? url = makeURL(tags);
    Logger.Inst().log(url, "InkBunnyHandler", "Search", LogTypes.booruHandlerSearchURL);
    try {
      int length = fetched.length;
      Uri uri = Uri.parse(url);
      final response = await http.get(uri,headers: getHeaders());
      if (response.statusCode == 200) {
        if (totalCount.value > 0 && (pageNum.value * 30) > totalCount.value){
          if (fetched.length == length){locked.value = true;}
        } else {
          parseResponse(await getSubmissionResponse(response));
          prevTags = tags;
        }
        if (fetched.length == length){locked.value = true;}
        return fetched;
      } else {
        Logger.Inst().log("InkBunnyHandler status is: ${response.statusCode}", "BooruHandler", "Search", LogTypes.booruHandlerFetchFailed);
        Logger.Inst().log("InkBunnyHandler url is: $url", "BooruHandler", "Search", LogTypes.booruHandlerFetchFailed);
      }
    } catch(e) {
      Logger.Inst().log(e.toString(), "InkBunnyHandler", "Search", LogTypes.exception);
      return fetched;
    }
  }

  Future getSubmissionResponse(response) async{
    Map<String, dynamic> parsedResponse = jsonDecode(response.body);
    totalCount.value = int.parse(parsedResponse["results_count_all"]);
    resultsID = parsedResponse["rid"];
    String ids = "";
    for (int i =0; i < parsedResponse["submissions"].length; i++){
      var current = parsedResponse["submissions"][i];
      ids += current["submission_id"].toString();
      if (i < parsedResponse["submissions"].length - 1){
        ids += ",";
      }
    }
    Logger.Inst().log("Got submission ids: $ids", "InkBunnyHandler", "getSubmissionResponse", LogTypes.booruHandlerInfo);
    try {
      Uri uri = Uri.parse("${booru.baseURL}/api_submissions.php?output_mode=json&sid=${sessionToken}&submission_ids=$ids");
      var response = await http.get(uri,headers: getHeaders());
      Logger.Inst().log("Getting submission data: ${uri.toString()}", "InkBunnyHandler", "getSubmissionResponse", LogTypes.booruHandlerRawFetched);
      if (response.statusCode == 200) {
        Logger.Inst().log(response.body, "InkBunnyHandler", "getSubmissionResponse", LogTypes.booruHandlerRawFetched);
        return response;
      } else {
        Logger.Inst().log("InkBunnyHandler failed to get submissions", "InkBunnyHandler", "getSubmissionResponse", LogTypes.booruHandlerFetchFailed);
      }
    } catch(e) {
      Logger.Inst().log(e.toString(), "InkBunnyHandler", "getSubmissionResponse", LogTypes.exception);
    }
    print("returning null");
    return null;
  }

  @override
  void parseResponse(submissionResponse) async{
    if (submissionResponse != null){
      Map<String, dynamic> parsedResponse = jsonDecode(submissionResponse.body);
      // Loop backwards because the api order the results the wrong way
      for (int i = parsedResponse["submissions"].length - 1; i >= 0; i--){
        var current = parsedResponse["submissions"][i];
        Logger.Inst().log(current.toString(), "InkBunnyHandler","parseResponse", LogTypes.booruHandlerRawFetched);
        List<String> currentTags = [];
        currentTags.add("artist:" + current["username"]);
        var tags = current["keywords"];
        for (int i = 0; i < tags.length; i++){
          currentTags.add(tags[i]["keyword_name"].replaceAll(" ", "_"));
        }

        // A submission can have multiple files so a booru item must be made for each of them
        var files = current["files"];
        for (int i = 0; i < files.length; i++){
          String sampleURL = files[i]["file_url_screen"],
              thumbURL = files[i]["file_url_preview"],
              fileURL = files[i]["file_url_full"];
          if (fileURL.endsWith(".mp4")){
            thumbURL = files[i]["thumbnail_url_huge"];
            sampleURL = thumbURL;
          }
          fetched.add(BooruItem(
            fileURL: fileURL,
            sampleURL: sampleURL,
            thumbnailURL: thumbURL,
            fileWidth: double.tryParse(files[i]["full_size_x"] == null ? "" : files[i]["full_size_x"]),
            fileHeight: double.tryParse(files[i]["full_size_y"] == null ? "" : files[i]["full_size_y"]),
            sampleWidth: double.tryParse(files[i]["screen_size_x"] == null ? "" : files[i]["screen_size_x"]),
            sampleHeight: double.tryParse(files[i]["screen_size_y"]  == null ? "" : files[i]["screen_size_y"]),
            previewWidth: double.tryParse(files[i]["preview_size_x"]  == null ? "" : files[i]["preview_size_x"]),
            previewHeight: double.tryParse(files[i]["preview_size_y"] == null ? "" : files[i]["preview_size_y"]),
            md5String: files[i]["full_file_md5"],
            tagsList: currentTags,
            postURL: makePostURL(current["submission_id"].toString()),
            serverId: current["submission_id"].toString(),
            score: current["favorites_count"],
            postDate: current["create_datetime"].split(".")[0],
            rating: normalizeRating(current["rating_name"]),
            postDateFormat: "yyyy-MM-dd'T'HH:mm:ss'Z'",
          ));

          setTrackedValues(fetched.length - 1);
        }


      }
    }
  }
  String normalizeRating(String rating){
    //current.getAttribute("rating")
    return "";
  }
  // This will create a url to goto the images page in the browser
  String makePostURL(String id){
    return "${booru.baseURL}/s/$id";
  }

  // This will create a url for the http request
  String makeURL(String tags){
    String artist = "";
    bool random = false;
    List<String> tagList = tags.split(" ");
    String tagStr = "";
    for (int i = 0; i < tagList.length; i++){
      if (tagList[i].contains("artist:")){
        artist = tagList[i].replaceAll("artist:", "");
      } else if (tagList[i].contains("order:")){
        if (tagList[i] == "order:random"){
          random = true;
        }
      }else {
        tagStr += tagList[i] + ",";
      }
    }
    //https://inkbunny.net/api_search.php?output_mode=xml&sid=AiMAejQkj7tg5R6Lvff9y3CSMRGTCDtSJDdWku3UMMczHK2Io8mq7fStANk2QsCRBzHcZ7mIaLvXYjVitonv03&text=dragon&get_rid=yes
    if (resultsID.isEmpty){
      return "${booru.baseURL}/api_search.php?output_mode=json&sid=$sessionToken&text=$tagStr&username=$artist&get_rid=yes&type=1,2,3,8,9,13,14&random=${random ? "yes" : "no"}&submission_ids_only=yes";
    } else {
      return "${booru.baseURL}/api_search.php?output_mode=json&sid=$sessionToken&rid=$resultsID&page=$pageNum";
    }

  }

  String makeTagURL(String input){
    print(input);
    return "${booru.baseURL}/api_search_autosuggest.php?keyword=${input.replaceAll("_", "+")}&ratingsmask=11111";
  }

  // Doesn't work for some reasons does in browser. Is dodgy anyway and doesn't return many results
  @override
  Future tagSearch(String input) async {
    List<String> searchTags = [];
    String url = makeTagURL(input);
    try {
      Uri uri = Uri.parse(url);
      var response = await http.get(uri,headers: getHeaders());
      // 200 is the success http response code
      print(url);
      print(response.body);
      if (response.statusCode == 200) {
        if (response.body.contains("response")){
          var parsedResponse = xml.parse(response.body);
          var tags = parsedResponse.findAllElements("value");
          if (tags.length > 0){
            for (int i=0; i < tags.length; i++){
              print(tags.elementAt(i));
              searchTags.add(tags.elementAt(i).toString().replaceAll(" ", "_"));
            }
          }
        }
      } else {
        Logger.Inst().log(e.toString(), "InkBunnyHandler", "tagSearch", LogTypes.exception);
      }
    } catch(e) {
      Logger.Inst().log(e.toString(), "InkBunnyHandler", "tagSearch", LogTypes.exception);
    }
    return searchTags;
  }

}