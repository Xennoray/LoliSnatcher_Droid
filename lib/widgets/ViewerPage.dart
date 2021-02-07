import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:flutter/cupertino.dart';

import 'package:LoliSnatcher/SearchGlobals.dart';
import 'package:LoliSnatcher/SnatchHandler.dart';
import 'package:LoliSnatcher/ServiceHandler.dart';
import 'package:LoliSnatcher/SettingsHandler.dart';
import 'package:LoliSnatcher/ImageWriter.dart';
import 'package:LoliSnatcher/getPerms.dart';
import 'package:LoliSnatcher/Tools.dart';

import 'package:LoliSnatcher/widgets/MediaViewer.dart';
import 'package:LoliSnatcher/widgets/VideoApp.dart';
import 'package:LoliSnatcher/widgets/HideableAppbar.dart';

/**
 * The image page is what is dispalyed when an iamge is clicked it shows a full resolution
 * version of an image and allows scrolling left and right through the currently loaded booruItems
 *
 */
class ImagePage extends StatefulWidget {
  List fetched;
  int index;
  SearchGlobals searchGlobals;
  SettingsHandler settingsHandler;
  SnatchHandler snatchHandler;

  ImagePage(this.fetched, this.index, this.searchGlobals, this.settingsHandler,
      this.snatchHandler);
  @override
  _ImagePageState createState() => _ImagePageState();
}

class _ImagePageState extends State<ImagePage> {
  PreloadPageController controller;
  PageController controllerLinux;
  ImageWriter writer = new ImageWriter();

  @override
  void initState() {
    super.initState();
    controller = PreloadPageController(
      initialPage: widget.index,
    );
    controllerLinux = PageController(
      initialPage: widget.index,
    );
    widget.searchGlobals.viewedIndex.value = widget.index;
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle =
        "${(widget.searchGlobals.viewedIndex.value + 1).toString()} / ${widget.fetched.length.toString()}";

    return Scaffold(
        appBar: HideableAppBar(appBarTitle, appBarActions(),
            widget.searchGlobals, widget.settingsHandler.autoHideImageBar),
        backgroundColor: Colors.transparent,
        body: Dismissible(
          direction: DismissDirection.vertical,
          // background: Container(color: Colors.black.withOpacity(0.3)),
          key: const Key('imagePageDismissibleKey'),
          resizeDuration: null, // Duration(milliseconds: 100),
          // dismissThresholds: {DismissDirection.vertical: 0.33},
          onDismissed: (_) => Navigator.of(context).pop(),
          child: Center(
            /**
         * The pageView builder will created a page for each image in the booruList(fetched)
         */
            child:
                Platform.isAndroid ? androidPageBuilder() : linuxPageBuilder(),
          ),
        ));
  }

  Widget androidPageBuilder() {
    return PhotoViewGestureDetectorScope(
        // prevents triggering page change early when panning
        axis: Axis.horizontal,
        child: PreloadPageView.builder(
          preloadPagesCount: widget.settingsHandler.preloadCount,
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            String fileURL = widget.fetched[index].fileURL;
            bool isVideo = widget.fetched[index].isVideo();
            int preloadCount = widget.settingsHandler.preloadCount;
            bool isViewed = widget.searchGlobals.viewedIndex.value == index;
            bool isNear =
                (widget.searchGlobals.viewedIndex.value - index).abs() <=
                    preloadCount;
            print(fileURL);

            // Render only if viewed or in preloadCount range
            if (isViewed || isNear) {
              // Cut to the size of the container, prevents overlapping
              return ClipRect(
                  child: GestureDetector(
                      onLongPress: () {
                        print('longpress');
                        widget.searchGlobals.displayAppbar.value =
                            !widget.searchGlobals.displayAppbar.value;
                      },
                      child: isVideo
                          ? VideoApp(
                              widget.fetched[index],
                              index,
                              widget.searchGlobals.viewedIndex.value,
                              widget.settingsHandler)
                          : MediaViewer(
                              widget.fetched[index],
                              index,
                              widget.searchGlobals.viewedIndex.value,
                              widget.settingsHandler)));
            } else {
              return Container();
            }
          },
          controller: controller,
          onPageChanged: (int index) {
            setState(() {
              widget.searchGlobals.viewedIndex.value = index;
            });
            // print('Page changed ' + index.toString());
          },
          itemCount: widget.fetched.length,
        ));
  }

  Widget linuxPageBuilder() {
    return PageView.builder(
        controller: controllerLinux,
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          String fileURL = widget.fetched[index].fileURL;
          bool isVideo = widget.fetched[index].isVideo();
          if (isVideo) {
            return Container(
              child: Column(
                children: [
                  Image.network(widget.fetched[index].thumbnailURL),
                  Container(
                    margin: EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: FlatButton(
                      shape: RoundedRectangleBorder(
                        borderRadius: new BorderRadius.circular(20),
                        side: BorderSide(color: Theme.of(context).accentColor),
                      ),
                      onPressed: () {
                        Process.run('mpv', ["--loop", fileURL]);
                      },
                      child: Text("Open in MPV"),
                    ),
                  )
                ],
              ),
            );
          } else {
            return Image.network(fileURL);
          }
        });
  }

  List<Widget> appBarActions() {
    return [
      IconButton(
        icon: Icon(Icons.save),
        onPressed: () async {
          getPerms();
          // call a function to save the currently viewed image when the save button is pressed
          // TODO: show progress, maybe use system downloader?
          widget.snatchHandler.queue(
              [widget.fetched[widget.searchGlobals.viewedIndex.value]],
              widget.settingsHandler.jsonWrite,
              widget.searchGlobals.selectedBooru.name);
        },
      ),
      IconButton(
        icon: Icon(Icons.share),
        onPressed: () {
          ServiceHandler serviceHandler = new ServiceHandler();
          serviceHandler.loadShareIntent(
              widget.fetched[widget.searchGlobals.viewedIndex.value].fileURL);
        },
      ),
      IconButton(
        icon: Icon(Icons.public),
        onPressed: () {
          if (Platform.isAndroid) {
            Tools.launchURL(
                widget.fetched[widget.searchGlobals.viewedIndex.value].postURL);
          } else if (Platform.isLinux) {
            Process.run('xdg-open', [
              widget.fetched[widget.searchGlobals.viewedIndex.value].postURL
            ]);
          }
        },
      ),
      IconButton(
        icon: Icon(Icons.info),
        onPressed: () {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return Dialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0)),
                  child: Container(
                    margin: EdgeInsets.all(5),
                    child: ListView.builder(
                        itemCount: widget
                            .fetched[widget.searchGlobals.viewedIndex.value]
                            .tagsList
                            .length,
                        itemBuilder: (BuildContext context, int index) {
                          String currentTag = widget
                              .fetched[widget.searchGlobals.viewedIndex.value]
                              .tagsList[index];

                          if (currentTag != '') {
                            return Column(children: <Widget>[
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(currentTag),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.add,
                                      color: Theme.of(context).accentColor,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        widget.searchGlobals.addTag.value =
                                            " " + currentTag;
                                      });
                                      Get.snackbar("Added to search",
                                          "Tag: " + currentTag,
                                          snackPosition: SnackPosition.BOTTOM,
                                          duration: Duration(seconds: 2),
                                          colorText: Colors.black,
                                          backgroundColor: Colors.pink[200]);
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.fiber_new,
                                        color: Theme.of(context).accentColor),
                                    onPressed: () {
                                      setState(() {
                                        widget.searchGlobals.newTab.value =
                                            currentTag;
                                      });
                                      Get.snackbar(
                                          "Added new tab", "Tag: " + currentTag,
                                          snackPosition: SnackPosition.BOTTOM,
                                          duration: Duration(seconds: 2),
                                          colorText: Colors.black,
                                          backgroundColor: Colors.pink[200]);
                                    },
                                  ),
                                ],
                              ),
                              Divider(
                                color: Colors.white,
                                height: 2,
                              ),
                            ]);
                          } else {
                            // Render nothing if currentTag is an empty string
                            return Container();
                          }
                        }),
                  ),
                );
              });
        },
      ),
    ];
  }
}