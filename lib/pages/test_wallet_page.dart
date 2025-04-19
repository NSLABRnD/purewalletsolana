import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pure_wallet_2/static/constant.dart';
import 'package:pure_wallet_2/static/scaled_size_custom.dart';

import '../account/account_model.dart';
import '../static/test_accounts.dart';
import 'send_transaction_page.dart';
import 'send_token_page.dart';

class TestWalletPage extends StatefulWidget {
  const TestWalletPage({super.key});

  @override
  State<TestWalletPage> createState() => _TestWalletPageState();
}

class _TestWalletPageState extends State<TestWalletPage> {
  final TextEditingController _mnemonicController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();
  
  BLOCKCHAIN_NETWORK _selectedNetwork = BLOCKCHAIN_NETWORK.SOL;
  Map<String, String> _accountInfo = {};
  bool _showAccountInfo = false;
  String _testResult = '';

  @override
  void initState() {
    super.initState();
    // Initialize with test mnemonic
    _mnemonicController.text = TESTMNEMONIC[0];
  }

  @override
  void dispose() {
    _mnemonicController.dispose();
    _privateKeyController.dispose();
    super.dispose();
  }

  // Test creating account from mnemonic
  Future<void> _testMnemonicToAccount() async {
    setState(() {
      _testResult = 'Testing mnemonic to account...';
    });

    try {
      final result = await getAccountBasedOnMnemonic(
        _mnemonicController.text, 
        0, 
        network: _selectedNetwork
      );
      
      setState(() {
        _accountInfo = {
          'privateKey': result[ACCOUNT_ASSET.PRIV_KEY],
          'address': result[ACCOUNT_ASSET.ADDRESS]
        };
        _showAccountInfo = true;
        _testResult = 'Successfully created account from mnemonic';
        // Set private key for next test
        _privateKeyController.text = result[ACCOUNT_ASSET.PRIV_KEY];
      });
    } catch (e) {
      setState(() {
        _testResult = 'Error creating account from mnemonic: $e';
      });
      log("Error: $_testResult");
    }
  }

  // Test creating account from private key
  Future<void> _testPrivateKeyToAccount() async {
    if (_privateKeyController.text.isEmpty) {
      setState(() {
        _testResult = 'Please enter a private key or generate one from mnemonic first';
      });
      return;
    }

    setState(() {
      _testResult = 'Testing private key to account...';
    });

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
        _testResult = 'Successfully created account from private key';
      });
    } catch (e) {
      setState(() {
        _testResult = 'Error creating account from private key: $e';
      });
      log("Error: $_testResult");
    }
  }

  // Run all tests in sequence
  Future<void> _runAllTests() async {
    await _testMnemonicToAccount();
    await Future.delayed(const Duration(seconds: 1));
    await _testPrivateKeyToAccount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Test Page'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.rw),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.rh),
                // Network selection
                Row(
                  children: [
                    const Text(
                      "Network: ",
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
                            _testResult = '';
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
                // Test buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _testMnemonicToAccount,
                        child: const Text('Test Mnemonic'),
                      ),
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _testPrivateKeyToAccount,
                        child: const Text('Test Private Key'),
                      ),
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _runAllTests,
                        child: const Text('Run All Tests'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.rh),
                // Test result display
                Container(
                  padding: EdgeInsets.all(8.rw),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Result:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4.rh),
                      Text(_testResult),
                    ],
                  ),
                ),
                SizedBox(height: 16.rh),
                // Mnemonic input
                Text(
                  "Mnemonic Phrase:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.rh),
                TextFormField(
                  controller: _mnemonicController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter mnemonic phrase',
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 16.rh),
                // Private key input
                Text(
                  "Private Key:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.rh),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _privateKeyController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Enter private key',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        if (_privateKeyController.text.isNotEmpty) {
                          Clipboard.setData(ClipboardData(text: _privateKeyController.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Private key copied to clipboard')),
                          );
                        }
                      },
                    ),
                  ],
                ),
                SizedBox(height: 16.rh),
                // Account info display
                if (_showAccountInfo) ...[                  
                  Container(
                    padding: EdgeInsets.all(16.rw),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Account Information",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.rh),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Address: ${_accountInfo['address']}",
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _accountInfo['address'] ?? ''));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Address copied to clipboard')),
                                );
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 8.rh),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Private Key: ${_accountInfo['privateKey']}",
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _accountInfo['privateKey'] ?? ''));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Private key copied to clipboard')),
                                );
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 16.rh),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SendTransactionPage(
                                    senderAddress: _accountInfo['address'] ?? '',
                                    privateKey: _accountInfo['privateKey'] ?? '',
                                    network: _selectedNetwork,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.send),
                            label: const Text('Send SOL'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12.rh),
                            ),
                          ),
                        ),
                        SizedBox(height: 8.rh),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SendTokenPage(
                                    senderAddress: _accountInfo['address'] ?? '',
                                    privateKey: _accountInfo['privateKey'] ?? '',
                                    network: _selectedNetwork,
                                    tokenMintAddress: '4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU', // Example token mint (devnet USDC)
                                    tokenSymbol: 'USDC',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.token),
                            label: const Text('Send SPL Token'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12.rh),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}