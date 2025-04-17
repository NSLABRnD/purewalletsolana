import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pure_wallet_2/account/solana_transaction.dart';
import 'package:pure_wallet_2/static/constant.dart';
import 'package:pure_wallet_2/static/scaled_size_custom.dart';
import 'package:url_launcher/url_launcher.dart';

class SendTransactionPage extends StatefulWidget {
  final String senderAddress;
  final String privateKey;
  final BLOCKCHAIN_NETWORK network;

  const SendTransactionPage({
    Key? key,
    required this.senderAddress,
    required this.privateKey,
    required this.network,
  }) : super(key: key);

  @override
  State<SendTransactionPage> createState() => _SendTransactionPageState();
}

class _SendTransactionPageState extends State<SendTransactionPage> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  
  bool _isLoading = false;
  String _transactionStatus = '';
  Map<String, dynamic>? _transactionResult;
  bool _useMainnet = false; // Default to devnet for testing
  double _accountBalance = 0.0;
  bool _isLoadingBalance = false;

  @override
  void initState() {
    super.initState();
    // Load account balance when page initializes
    _loadAccountBalance();
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }
  
  // Load the current account balance
  Future<void> _loadAccountBalance() async {
    if (widget.network != BLOCKCHAIN_NETWORK.SOL) return;
    
    setState(() {
      _isLoadingBalance = true;
    });
    
    try {
      final accountInfo = await SolanaTransaction.getAccountBalance(
        address: widget.senderAddress,
        useMainnet: _useMainnet,
      );
      
      setState(() {
        _isLoadingBalance = false;
        if (accountInfo['success']) {
          _accountBalance = accountInfo['balance'];
        } else {
          _showErrorSnackBar('Failed to load balance: ${accountInfo['message']}');
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingBalance = false;
        _showErrorSnackBar('Error loading balance: ${e.toString()}');
      });
    }
  }
  
  // Check account balance before sending transaction
  Future<bool> _checkSufficientBalance(double amount) async {
    if (widget.network != BLOCKCHAIN_NETWORK.SOL) return true;
    
    try {
      final accountInfo = await SolanaTransaction.getAccountBalance(
        address: widget.senderAddress,
        useMainnet: _useMainnet,
      );
      
      if (!accountInfo['success']) {
        _showErrorSnackBar('Failed to check balance: ${accountInfo['message']}');
        return false;
      }
      
      final double balance = accountInfo['balance'];
      final double requiredAmount = amount + 0.000005; // Amount + estimated fee
      
      if (balance < requiredAmount) {
        _showFaucetDialog(accountInfo['faucetUrl'] ?? 'https://solfaucet.com');
        _showErrorSnackBar('Insufficient balance: ${balance.toStringAsFixed(6)} SOL (required: ${requiredAmount.toStringAsFixed(6)} SOL)');
        return false;
      }
      
      return true;
    } catch (e) {
      _showErrorSnackBar('Error checking balance: ${e.toString()}');
      return false;
    }
  }

  Future<void> _sendTransaction() async {
    if (_recipientController.text.isEmpty) {
      _showErrorSnackBar('Please enter a recipient address');
      return;
    }

    if (_amountController.text.isEmpty) {
      _showErrorSnackBar('Please enter an amount');
      return;
    }

    double amount;
    try {
      amount = double.parse(_amountController.text);
      if (amount <= 0) {
        _showErrorSnackBar('Amount must be greater than 0');
        return;
      }
    } catch (e) {
      _showErrorSnackBar('Invalid amount format');
      return;
    }

    setState(() {
      _isLoading = true;
      _transactionStatus = 'Sending transaction...';
      _transactionResult = null;
    });

    try {
      if (widget.network == BLOCKCHAIN_NETWORK.SOL) {
        // First check if the account has sufficient balance
        final hasSufficientBalance = await _checkSufficientBalance(amount);
        if (!hasSufficientBalance) {
          setState(() {
            _isLoading = false;
            _transactionStatus = 'Transaction cancelled: Insufficient balance';
          });
          return;
        }
        
        final lamports = SolanaTransaction.solToLamports(amount);
        final result = await SolanaTransaction.sendSol(
          senderPrivateKey: widget.privateKey,
          recipientAddress: _recipientController.text,
          amountLamports: lamports,
          useMainnet: _useMainnet,
        );

        setState(() {
          _transactionResult = result;
          _isLoading = false;
          if (result['success']) {
            _transactionStatus = 'Transaction submitted successfully!';
          } else {
            _transactionStatus = 'Transaction failed: ${result['message']}';
            // Show a more detailed error message in a snackbar
            _showErrorSnackBar(result['message']);
          }
        });
        
        // If there's a faucet URL and transaction failed due to insufficient funds, offer to open it
        if (!result['success'] && result['faucetUrl'] != null && result['faucetUrl'].isNotEmpty) {
          _showFaucetDialog(result['faucetUrl']);
        }
      } else {
        setState(() {
          _isLoading = false;
          _transactionStatus = 'Only Solana transactions are supported currently';
        });
      }
    } catch (e) {
      log('Error sending transaction: $e');
      setState(() {
        _isLoading = false;
        _transactionStatus = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _checkTransactionStatus() async {
    if (_transactionResult == null || _transactionResult!['txHash'] == null) {
      _showErrorSnackBar('No transaction to check');
      return;
    }

    setState(() {
      _isLoading = true;
      _transactionStatus = 'Checking transaction status...';
    });

    try {
      final result = await SolanaTransaction.getTransactionStatus(
        txHash: _transactionResult!['txHash'],
        useMainnet: _useMainnet,
      );

      setState(() {
        _transactionResult = result;
        _isLoading = false;
        _transactionStatus = 'Status: ${result['status']} - ${result['message']}';
      });
    } catch (e) {
      log('Error checking transaction: $e');
      setState(() {
        _isLoading = false;
        _transactionStatus = 'Error checking status: ${e.toString()}';
      });
    }
  }

  Future<void> _openExplorerLink() async {
    if (_transactionResult == null || _transactionResult!['explorerUrl'] == null) {
      _showErrorSnackBar('No transaction explorer link available');
      return;
    }

    final url = Uri.parse(_transactionResult!['explorerUrl']);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar('Could not open explorer link');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  void _showFaucetDialog(String faucetUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Insufficient Funds'),
          content: const Text(
            'Your account needs SOL to perform transactions. For testing on devnet, you can get free SOL from a faucet.'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final url = Uri.parse(faucetUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  _showErrorSnackBar('Could not open faucet website');
                }
              },
              child: const Text('Get SOL from Faucet'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Transaction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.popUntil(context, ModalRoute.withName('/'));
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
                Container(
                  padding: EdgeInsets.all(12.rw),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Network: ${widget.network.toString().split('.').last}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8.rh),
                      Row(
                        children: [
                          const Text(
                            "Balance: ",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _isLoadingBalance
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(
                                  "${_accountBalance.toStringAsFixed(6)} SOL",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _accountBalance > 0 ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          if (_accountBalance <= 0 && widget.network == BLOCKCHAIN_NETWORK.SOL)
                            TextButton(
                              onPressed: () => _showFaucetDialog('https://solfaucet.com'),
                              child: const Text("Get SOL"),
                            ),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            onPressed: _loadAccountBalance,
                            tooltip: "Refresh balance",
                          ),
                        ],
                      ),
                      SizedBox(height: 8.rh),
                      Row(
                        children: [
                          const Text(
                            "Environment: ",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Switch(
                            value: _useMainnet,
                            onChanged: (value) {
                              setState(() {
                                _useMainnet = value;
                              });
                            },
                          ),
                          Text(_useMainnet ? "Mainnet" : "Devnet"),
                        ],
                      ),
                      SizedBox(height: 8.rh),
                      Text(
                        "From: ${widget.senderAddress}",
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.rh),
                Text(
                  "Recipient Address:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.rh),
                TextFormField(
                  controller: _recipientController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter recipient address',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data != null && data.text != null) {
                          _recipientController.text = data.text!;
                        }
                      },
                    ),
                  ),
                ),
                SizedBox(height: 16.rh),
                Text(
                  "Amount (SOL):",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.rh),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter amount',
                  ),
                ),
                SizedBox(height: 24.rh),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendTransaction,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.rh),
                    ),
                    child: Text(
                      'Send Transaction',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                SizedBox(height: 16.rh),
                if (_transactionStatus.isNotEmpty) ...[
                  Container(
                    padding: EdgeInsets.all(12.rw),
                    decoration: BoxDecoration(
                      color: _transactionResult != null && _transactionResult!['success'] == true
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transaction Status:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8.rh),
                        Text(_transactionStatus),
                        if (_transactionResult != null && _transactionResult!['txHash'] != null) ...[                          
                          SizedBox(height: 8.rh),
                          Text(
                            'Transaction Hash:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4.rh),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _transactionResult!['txHash'],
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                    text: _transactionResult!['txHash'],
                                  ));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Transaction hash copied to clipboard')),
                                  );
                                },
                              ),
                            ],
                          ),
                          if (_transactionResult!['amount'] != null && _transactionResult!['recipient'] != null) ...[                          
                            SizedBox(height: 8.rh),
                            Text(
                              "Amount: ${_transactionResult!['amount']} SOL",
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: 4.rh),
                            Text(
                              "Recipient: ${_transactionResult!['recipient']}",
                              style: TextStyle(fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          SizedBox(height: 16.rh),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _checkTransactionStatus,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Check Status'),
                                ),
                              ),
                              SizedBox(width: 8.rw),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _openExplorerLink,
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('View in Explorer'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 24.rh),
              ],
            ),
          ),
        ),
      ),
    );
  }
}