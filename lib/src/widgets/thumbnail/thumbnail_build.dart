import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:lolisnatcher/src/handlers/search_handler.dart';
import 'package:lolisnatcher/src/handlers/settings_handler.dart';
import 'package:lolisnatcher/src/data/booru_item.dart';
import 'package:lolisnatcher/src/widgets/thumbnail/thumbnail.dart';
import 'package:lolisnatcher/src/utils/tools.dart';

class ThumbnailBuild extends StatelessWidget {
  const ThumbnailBuild(this.index, this.columnCount, this.searchGlobal, {Key? key}) : super(key: key);
  final int index;
  final int columnCount;
  final SearchTab searchGlobal;

  @override
  Widget build(BuildContext context) {
    final SettingsHandler settingsHandler = SettingsHandler.instance;

    BooruItem item = searchGlobal.booruHandler.filteredFetched[index];
    IconData itemIcon = Tools.getFileIcon(item.mediaType);

    List<List<String>> parsedTags = settingsHandler.parseTagsList(item.tagsList, isCapped: false);
    bool isHated = parsedTags[0].isNotEmpty;
    bool isLoved = parsedTags[1].isNotEmpty;
    bool isSound = parsedTags[2].isNotEmpty;
    bool isNoted = item.hasNotes == true;

    // reset the isHated value since we already check for it on every render
    item.isHated.value = isHated;

    // print('ThumbnailBuild $index');

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Stack(
        alignment: settingsHandler.previewDisplay == "Square" ? Alignment.center : Alignment.bottomCenter,
        children: [
          Thumbnail(item, index, searchGlobal, columnCount, true),
          // Image(
          //   image: ResizeImage(NetworkImage(item.thumbnailURL), width: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio / 3).round()),
          //   fit: BoxFit.cover,
          //   isAntiAlias: true,
          //   filterQuality: FilterQuality.medium,
          //   width: double.infinity,
          //   height: double.infinity,
          // ),
          Container(
            alignment: Alignment.bottomCenter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // reserved for elements on the left side
                const SizedBox(),

                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.66),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(5)),
                  ),
                  child: Obx(() => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Text('  ${(index + 1)}  ', style: TextStyle(fontSize: 10, color: Colors.white)),

                      if (item.isFavourite.value == null) const Text('.'),

                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        crossFadeState: (item.isFavourite.value == true || isLoved) ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                        firstChild: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            item.isFavourite.value == true ? Icons.favorite : Icons.star,
                            color: item.isFavourite.value == true ? Colors.red : Colors.grey,
                            key: ValueKey<Color>(item.isFavourite.value == true ? Colors.red : Colors.grey),
                            size: 14,
                          ),
                        ),
                        secondChild: const SizedBox(),
                      ),

                      if (item.isSnatched.value == true)
                        const Icon(
                          Icons.save_alt,
                          color: Colors.white,
                          size: 14,
                        ),

                      if (isSound)
                        const Icon(
                          Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 14,
                        ),

                      if (isNoted)
                        const Icon(
                          Icons.note_add,
                          color: Colors.white,
                          size: 14,
                        ),

                      Icon(
                        itemIcon,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}