import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'package:LoliSnatcher/getPerms.dart';
import 'package:LoliSnatcher/SnatchHandler.dart';
import 'package:LoliSnatcher/SettingsHandler.dart';
import 'package:LoliSnatcher/libBooru/Booru.dart';
import 'package:LoliSnatcher/SearchGlobals.dart';
import 'package:LoliSnatcher/widgets/FlashElements.dart';
import 'package:LoliSnatcher/widgets/SettingsWidgets.dart';


/**
 * This is the page which allows the user to batch download images
 */
class SnatcherPage extends StatefulWidget {
  SnatcherPage();
  @override
  _SnatcherPageState createState() => _SnatcherPageState();
}

class _SnatcherPageState extends State<SnatcherPage> {
  final SearchHandler searchHandler = Get.find<SearchHandler>();
  final SettingsHandler settingsHandler = Get.find<SettingsHandler>();
  final SnatchHandler snatchHandler = Get.find<SnatchHandler>();

  final snatcherTagsController = TextEditingController();
  final snatcherAmountController = TextEditingController();
  final snatcherSleepController = TextEditingController();

  late Booru? selectedBooru;

  @override
  void initState() {
    super.initState();
    getPerms();
    //If the user has searched tags on the main window they will be loaded into the tags field
    snatcherTagsController.text = searchHandler.currentTab.tags;
    snatcherAmountController.text = 10.toString();
    selectedBooru = searchHandler.currentTab.selectedBooru.value;
    snatcherSleepController.text = settingsHandler.snatchCooldown.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Snatcher")
      ),
      resizeToAvoidBottomInset: true,
      body: Center(
        child: ListView(
          children: <Widget>[
            SettingsTextInput(
              controller: snatcherTagsController,
              title: 'Tags',
              hintText: "Enter Tags",
              inputType: TextInputType.text,
              clearable: true,
            ),
            SettingsTextInput(
              controller: snatcherAmountController,
              title: 'Amount',
              hintText: "Amount of Files to Snatch",
              inputType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly
              ],
              resetText: () => 10.toString(),
              numberButtons: true,
              numberStep: 10,
              numberMin: 10,
              numberMax: double.infinity,
            ),
            SettingsTextInput(
              controller: snatcherSleepController,
              title: 'Delay (in ms)',
              hintText: "Delay between each download",
              inputType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly
              ],
              resetText: () => settingsHandler.snatchCooldown.toString(),
              numberButtons: true,
              numberStep: 50,
              numberMin: 100,
              numberMax: double.infinity,
            ),
            SettingsBooruDropdown(
              selected: selectedBooru,
              onChanged: (Booru? newValue) {
                setState(() {
                  selectedBooru = newValue;
                });
              },
              title: 'Booru',
            ),

            SettingsButton(name: '', enabled: false),
            SettingsButton(
              name: 'Snatch Files',
              icon: Icon(Icons.download),
              action: () {
                if (snatcherSleepController.text.isEmpty){
                  snatcherSleepController.text = 0.toString();
                }
                if(selectedBooru == null) {
                  FlashElements.showSnackbar(
                    context: context,
                    title: Text(
                      "No Booru Selected!",
                      style: TextStyle(fontSize: 18)
                    ),
                    leadingIcon: Icons.error_outline,
                    leadingIconColor: Colors.red,
                    sideColor: Colors.red,
                  );
                  return;
                }

                snatchHandler.searchSnatch(
                  snatcherTagsController.text,
                  snatcherAmountController.text,
                  int.parse(snatcherSleepController.text),
                  selectedBooru!,
                );
                Get.back();
                //Get.off(SnatcherProgressPage(snatcherTagsController.text,snatcherAmountController.text,snatcherTimeoutController.text));
              },
            ),
          ],
        ),
      ),
    );
  }
}
