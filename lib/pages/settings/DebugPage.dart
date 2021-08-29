import 'dart:async';

import 'package:LoliSnatcher/widgets/SettingsWidgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:LoliSnatcher/SettingsHandler.dart';
import 'package:LoliSnatcher/ServiceHandler.dart';

class DebugPage extends StatefulWidget {
  DebugPage();
  @override
  _DebugPageState createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  final SettingsHandler settingsHandler = Get.find();
  ServiceHandler serviceHandler = ServiceHandler();

  @override
  void initState() {
    super.initState();
  }

  //called when page is closed, sets settingshandler variables and then writes settings to disk
  Future<bool> _onWillPop() async {
    bool result = await settingsHandler.saveSettings();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text("Debug"),
        ),
        body: Center(
          child: ListView(
            children: [
              SettingsToggle(
                value: settingsHandler.showFPS.value,
                onChanged: (newValue) {
                  setState(() {
                    settingsHandler.showFPS.value = newValue;
                  });
                },
                title: 'Show FPS Info'
              ),
              SettingsToggle(
                value: settingsHandler.showImageStats.value,
                onChanged: (newValue) {
                  setState(() {
                    settingsHandler.showImageStats.value = newValue;
                  });
                },
                title: 'Show Image Stats'
              ),
              SettingsToggle(
                value: settingsHandler.disableImageScaling.value,
                onChanged: (newValue) {
                  setState(() {
                    settingsHandler.disableImageScaling.value = newValue;
                  });
                },
                title: "Don't scale images"
              ),
              SettingsToggle(
                value: settingsHandler.showURLOnThumb.value,
                onChanged: (newValue) {
                  setState(() {
                    settingsHandler.showURLOnThumb.value = newValue;
                  });
                },
                title: 'Show URL on thumb'
              ),
              // SettingsToggle(
              //   value: settingsHandler.isMemeTheme.value,
              //   onChanged: (newValue) {
              //     setState(() {
              //       settingsHandler.isMemeTheme.value = newValue;
              //     });
              //   },
              //   title: 'Meme Theme'
              // ),
              SettingsButton(
                name: 'Load and Save Legacy Settings',
                action: () {
                  settingsHandler.debugLoadAndSaveLegacy();
                }
              ),
            ],
          ),
        ),
      ),
    );
  }
}

