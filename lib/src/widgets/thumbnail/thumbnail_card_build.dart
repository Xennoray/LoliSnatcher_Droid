import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import 'package:lolisnatcher/src/handlers/search_handler.dart';
import 'package:lolisnatcher/src/handlers/service_handler.dart';
import 'package:lolisnatcher/src/handlers/settings_handler.dart';
import 'package:lolisnatcher/src/data/booru_item.dart';
import 'package:lolisnatcher/src/widgets/common/flash_elements.dart';
import 'package:lolisnatcher/src/widgets/thumbnail/thumbnail_build.dart';
import 'package:lolisnatcher/src/data/settings/app_mode.dart';

class ThumbnailCardBuild extends StatelessWidget {
  ThumbnailCardBuild(this.index, this.columnCount, this.onTap, this.tab, {Key? key}) : super(key: key);
  final int index;
  final int columnCount;
  final SearchTab tab;
  final void Function(int) onTap;

  final SettingsHandler settingsHandler = SettingsHandler.instance;
  final SearchHandler searchHandler = SearchHandler.instance;

  void onDoubleTap(int index) async {
    BooruItem item = tab.booruHandler.filteredFetched[index];
    if (item.isFavourite.value != null) {
      ServiceHandler.vibrate();

      item.isFavourite.toggle();
      settingsHandler.dbHandler.updateBooruItem(item, "local");
    }
  }

  void onLongPress(int index) async {
    ServiceHandler.vibrate(duration: 5);

    if (tab.selected.contains(index)) {
      tab.selected.remove(index);
    } else {
      tab.selected.add(index);
    }
  }

  void onSecondaryTap(int index) {
    BooruItem item = tab.booruHandler.filteredFetched[index];
    Clipboard.setData(ClipboardData(text: item.fileURL));
    FlashElements.showSnackbar(
      duration: const Duration(seconds: 2),
      title: const Text("Copied File URL to clipboard!", style: TextStyle(fontSize: 20)),
      content: Text(item.fileURL, style: const TextStyle(fontSize: 16)),
      leadingIcon: Icons.copy,
      sideColor: Colors.green,
    );
  }

  @override
  Widget build(BuildContext context) {
    // print('ThumbnailCardBuild: $index');
    return Obx(() {
      bool isSelected = tab.selected.contains(index);
      bool isCurrent = settingsHandler.appMode.value == AppMode.DESKTOP && (searchHandler.viewedIndex.value == index);

      // print('ThumbnailCardBuild obx: $index');

      return AutoScrollTag(
        highlightColor: Colors.red,
        key: ValueKey(index),
        controller: searchHandler.gridScrollController,
        index: index,
        child: Material(
          borderOnForeground: true,
          child: Ink(
            decoration: (isCurrent || isSelected)
                ? BoxDecoration(
                    border: Border.all(
                      color: isCurrent ? Colors.red : Theme.of(context).colorScheme.secondary,
                      width: 2.0,
                    ),
                  )
                : null,
            child: GestureDetector(
              onSecondaryTap: () {
                onSecondaryTap(index);
              },
              child: InkResponse(
                enableFeedback: true,
                highlightShape: BoxShape.rectangle,
                containedInkWell: false,
                highlightColor: Theme.of(context).colorScheme.secondary,
                splashColor: Colors.pink,
                child: ThumbnailBuild(index, columnCount, tab),
                onTap: () {
                  onTap(index);
                },
                onDoubleTap: () {
                  onDoubleTap(index);
                },
                onLongPress: () {
                  onLongPress(index);
                },
              ),
            ),
          ),
        ),
      );
    });
  }
}