import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pure_wallet_2/static/constant.dart';
import 'package:pure_wallet_2/static/scaled_size_custom.dart';

import '../account/account_model.dart';
import '../static/test_accounts.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePage();
}

class _HomePage extends State<HomePage> {

  final TextEditingController _inputPhraseController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _inputPhraseController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16.rw,
          ),
          child: SingleChildScrollView( // Added SingleChildScrollView
            child: Column(
              children: [
                // Start Size
                SizedBox(
                  height: 14.rh,
                ),
                // Start Upper
                SizedBox(
                  height: 400.rh, // Adjust height as needed
                  child: Column( // Use Column directly as the parent of Flexible
                    children: [
                      Flexible( // Correct placement of Flexible
                        child: SizedBox(
                          width: 343.rw,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: (){
                                      log("debug _ take from hardcode data");
                                      _inputPhraseController.text = TESTMNEMONIC[0];
                                    },
                                    child: const Text(
                                      "Import Wallet from Mnemonic",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.account_balance_wallet),
                                    onPressed: () {
                                      log("generate wallet");
                                      try {
                                        getAccountBasedOnMnemonic(_inputPhraseController.text,0);
                                        setState(() {
                                        });
                                      } catch (e, s) {
                                        log("Error : generate wallet : $e");
                                      }
                                    },
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.rh),
                              TextFormField(
                                autovalidateMode: AutovalidateMode.disabled,
                                controller: _inputPhraseController,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(10.0)),
                                    borderSide: BorderSide(color: Colors.blue),
                                  ),
                                  enabledBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(width: 1, color: Colors.grey),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                minLines: 8,
                                maxLines: 8,
                                textAlignVertical: TextAlignVertical.top,
                                onChanged: (value) {
                                  _inputPhraseController.text = value.trim();
                                },
                              ),
                              const Divider(),
                              Text("account: ${globalVar.account_address}"),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}