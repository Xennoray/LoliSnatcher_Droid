import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:LoliSnatcher/SettingsHandler.dart';
import 'package:LoliSnatcher/widgets/SettingsWidgets.dart';
import 'package:LoliSnatcher/utilities/Logger.dart';

class LoggerPage extends StatefulWidget {
  LoggerPage();
  @override
  _LoggerPageState createState() => _LoggerPageState();
}

class _LoggerPageState extends State<LoggerPage> {
  final SettingsHandler settingsHandler = Get.find<SettingsHandler>();
  List<LogTypes> ignoreLogTypes = [];

  @override
  void initState() {
    super.initState();
    ignoreLogTypes = settingsHandler.ignoreLogTypes;
  }

  @override
  void dispose() {
    super.dispose();
  }


  //called when page is closed, sets settingshandler variables and then writes settings to disk
  Future<bool> _onWillPop() async {
    settingsHandler.ignoreLogTypes = ignoreLogTypes;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child:Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text("Logger"),
        ),
        body: Center(
          child: ListView.builder(
            itemCount: LogTypes.values.length,
            itemBuilder: (context, index) {
              return SettingsToggle(
              value: !ignoreLogTypes.contains(LogTypes.values[index]),
                onChanged: (newValue) {
                  setState(() {
                    if (ignoreLogTypes.contains(LogTypes.values[index])){
                      ignoreLogTypes.remove(LogTypes.values[index]);
                    } else {
                      ignoreLogTypes.add(LogTypes.values[index]);
                    }
                  });
                },
              title: LogTypes.values[index].toString().split('.').last,
              );
            },
          ),
        ),
      ),
    );
  }
}

