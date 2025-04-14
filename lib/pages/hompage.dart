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
  final TextEditingController _privateKeyController = TextEditingController();
  
  BLOCKCHAIN_NETWORK _selectedNetwork = BLOCKCHAIN_NETWORK.ETH;
  Map<String, String> _accountInfo = {};
  bool _showAccountInfo = false;

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
                              // Network Selection Dropdown
                              Row(
                                children: [
                                  const Text(
                                    "Select Network: ",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  DropdownButton<BLOCKCHAIN_NETWORK>(
                                    value: _selectedNetwork,
                                    onChanged: (BLOCKCHAIN_NETWORK? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _selectedNetwork = newValue;
                                          _showAccountInfo = false;
                                        });
                                      }
                                    },
                                    items: [
                                      DropdownMenuItem(
                                        value: BLOCKCHAIN_NETWORK.ETH,
                                        child: Text('Ethereum'),
                                      ),
                                      DropdownMenuItem(
                                        value: BLOCKCHAIN_NETWORK.SOL,
                                        child: Text('Solana'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.rh),
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
                                    onPressed: () async {
                                      log("generate wallet");
                                      try {
                                        final result = await getAccountBasedOnMnemonic(
                                          _inputPhraseController.text, 
                                          0, 
                                          network: _selectedNetwork
                                        );
                                        setState(() {
                                          _accountInfo = {
                                            'privateKey': result[ACCOUNT_ASSET.PRIV_KEY],
                                            'address': result[ACCOUNT_ASSET.ADDRESS]
                                          };
                                          _showAccountInfo = true;
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
                              SizedBox(height: 16.rh),
                              // Private key input
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      autovalidateMode: AutovalidateMode.disabled,
                                      controller: _privateKeyController,
                                      decoration: InputDecoration(
                                        labelText: 'Private Key',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        focusedBorder: const OutlineInputBorder(
                                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                                          borderSide: BorderSide(color: Colors.blue),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.login),
                                    onPressed: () async {
                                      try {
                                        final result = await getAccountFromPrivateKey(
                                          _privateKeyController.text,
                                          network: _selectedNetwork
                                        );
                                        setState(() {
                                          _accountInfo = {
                                            'privateKey': result[ACCOUNT_ASSET.PRIV_KEY],
                                            'address': result[ACCOUNT_ASSET.ADDRESS]
                                          };
                                          _showAccountInfo = true;
                                        });
                                      } catch (e, s) {
                                        log("Error : import from private key : $e");
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // End Upper
                // Start Lower
                SizedBox(
                  height: 400.rh, // Adjust height as needed
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Network: ${_selectedNetwork.toString().split('.').last}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10.rh),
                      Text(
                        "Account Address: ${globalVar.account_address}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20.rh),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/test_wallet');
                        },
                        child: const Text('Open Wallet Test Page'),
                      ),
                      if (_showAccountInfo) ...[  
                        SizedBox(height: 20.rh),
                        Text(
                          "Account Details:",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10.rh),
                        Text(
                          "Private Key: ${_accountInfo['privateKey']}",
                          style: const TextStyle(fontSize: 14),
                        ),
                        SizedBox(height: 5.rh),
                        Text(
                          "Address: ${_accountInfo['address']}",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
                // End Lower
              ],
            ),
          ),
        ),
      ),
    );
  }
}