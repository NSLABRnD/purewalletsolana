import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pure_wallet_2/account/solana_transaction.dart';
import 'package:pure_wallet_2/static/constant.dart';
import 'package:pure_wallet_2/static/scaled_size_custom.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:solana/solana.dart';
import 'package:bs58/bs58.dart';


class SendTokenPage extends StatefulWidget {
  final String senderAddress;
  final String privateKey;
  final BLOCKCHAIN_NETWORK network;
  final String tokenMintAddress;
  final String tokenSymbol;

  const SendTokenPage({
    Key? key,
    required this.senderAddress,
    required this.privateKey,
    required this.network,
    required this.tokenMintAddress,
    required this.tokenSymbol,
  }) : super(key: key);

  @override
  State<SendTokenPage> createState() => _SendTokenPageState();
}

class _SendTokenPageState extends State<SendTokenPage> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  
  bool _isLoading = false;
  String _transactionStatus = '';
  Map<String, dynamic>? _transactionResult;
  bool _useMainnet = false; // Default to devnet for testing
  int _tokenBalance = 0;
  bool _isLoadingBalance = false;
  String? _tokenAccountAddress;

  @override
  void initState() {
    super.initState();
    // Load token balance when page initializes
    _loadTokenBalance();
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }
  
  // Load the current token balance
  Future<void> _loadTokenBalance() async {
    if (widget.network != BLOCKCHAIN_NETWORK.SOL) return;
    
    setState(() {
      _isLoadingBalance = true;
    });
    
    try {
      // First find the token account address
      final rpcUrl = SolanaTransaction.getRpcUrl(useMainnet: _useMainnet);
      final client = SolanaClient(
        rpcUrl: Uri.parse(rpcUrl),
        websocketUrl: Uri.parse(rpcUrl.replaceFirst('https', 'wss')),
      );
    
      // First check if the token account exists
      final tokenAccount = await SolanaTransaction.findAssociatedTokenAccount(
        owner: widget.senderAddress,
        mint: widget.tokenMintAddress,
        client: client,
      );
      
      String? finalTokenAccount = tokenAccount;
      
      // If token account doesn't exist, we'll need to create it
      if (tokenAccount == null ) {
        // Check if we have enough SOL to create a token account
        final solBalance = await SolanaTransaction.getAccountBalance(
          address: widget.senderAddress,
          useMainnet: _useMainnet,
        );
        
        if (solBalance['success']) { // Need ~0.002 SOL to create token account
          // Show a message that we're creating the token account
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Creating token account... This may take a moment.')),
          );
          
          try {
            // Create the token account
            finalTokenAccount = await SolanaTransaction.getOrCreateAssociatedTokenAccount(
              owner: widget.senderAddress,
              mint: widget.tokenMintAddress,
              payer: widget.senderAddress,
              client: client,
              ownerPrivateKey: widget.privateKey,
            );
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Token account created successfully!')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to create token account: ${e.toString()}')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Insufficient SOL to create token account. You need at least 0.002 SOL.')),
          );
        }
      }
      
      setState(() {
        _tokenAccountAddress = finalTokenAccount;
      });
      
      if (finalTokenAccount == null) {
        setState(() {
          _isLoadingBalance = false;
          _tokenBalance = 0;
        });
        return;
      }
      
      // Get token balance
      final balance = await SolanaTransaction.getTokenAccountBalance(
        tokenAccountAddress: finalTokenAccount,
        useMainnet: _useMainnet,
      );
      
      setState(() {
        _isLoadingBalance = false;
        _tokenBalance = balance;
      });} catch (e) {
      setState(() {
        _isLoadingBalance = false;
        _showErrorSnackBar('Error loading token balance: ${e.toString()}');
      });
    }
  }
  
  // Check SOL balance for transaction fees
  Future<bool> _checkSufficientSolBalance() async {
    if (widget.network != BLOCKCHAIN_NETWORK.SOL) return true;
    
    try {
      final accountInfo = await SolanaTransaction.getAccountBalance(
        address: widget.senderAddress,
        useMainnet: _useMainnet,
      );
      
      if (!accountInfo['success']) {
        _showErrorSnackBar('Failed to check SOL balance: ${accountInfo['message']}');
        return false;
      }
      
      final double balance = accountInfo['balance'];
      const double requiredAmount = 0.00001; // Estimated fee for token transfer
      
      if (balance < requiredAmount) {
        _showFaucetDialog(accountInfo['faucetUrl'] ?? 'https://solfaucet.com');
        _showErrorSnackBar('Insufficient SOL for transaction fees: ${balance.toStringAsFixed(6)} SOL (required: ${requiredAmount.toStringAsFixed(6)} SOL)');
        return false;
      }
      
      return true;
    } catch (e) {
      _showErrorSnackBar('Error checking SOL balance: ${e.toString()}');
      return false;
    }
  }

  Future<void> _sendTokenTransaction() async {
    if (_recipientController.text.isEmpty) {
      _showErrorSnackBar('Please enter a recipient address');
      return;
    }

    if (_amountController.text.isEmpty) {
      _showErrorSnackBar('Please enter an amount');
      return;
    }

    int amount;
    try {
      amount = int.parse(_amountController.text);
      if (amount <= 0) {
        _showErrorSnackBar('Amount must be greater than 0');
        return;
      }
      
      if (amount > _tokenBalance) {
        _showErrorSnackBar('Insufficient token balance: $_tokenBalance (required: $amount)');
        return;
      }
    } catch (e) {
      _showErrorSnackBar('Invalid amount format');
      return;
    }

    setState(() {
      _isLoading = true;
      _transactionStatus = 'Sending token transaction...';
      _transactionResult = null;
    });

    try {
      if (widget.network == BLOCKCHAIN_NETWORK.SOL) {
        final hasSufficientSolBalance = await _checkSufficientSolBalance();
        if (!hasSufficientSolBalance) {
          setState(() {
            _isLoading = false;
            _transactionStatus = 'Transaction cancelled: Insufficient SOL for fees';
          });
          return;
        }
        
        // Check if token account exists
        if (_tokenAccountAddress == null) {
          setState(() {
            _isLoading = false;
            _transactionStatus = 'Transaction cancelled: No token account found';
          });
          _showErrorSnackBar('You do not have a token account for this token. Please make sure you have enough SOL (at least 0.002 SOL) to create a token account.');
          
          // Offer to create the token account
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Token Account Required'),
                content: const Text(
                  'You need to create a token account for this token before you can send it. This requires a small amount of SOL (about 0.002 SOL) to pay for the account creation.'
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _createTokenAccount();
                    },
                    child: const Text('Create Token Account'),
                  ),
                ],
              );
            },
          );
          return;
        }
        
        final result = await SolanaTransaction.sendToken(
          senderPrivateKey: widget.privateKey,
          recipientAddress: _recipientController.text,
          tokenMintAddress: widget.tokenMintAddress,
          amount: amount,
          useMainnet: _useMainnet,
        );

        setState(() {
          _transactionResult = result;
          _isLoading = false;
          if (result['success']) {
            _transactionStatus = 'Token transaction submitted successfully!';

            _loadTokenBalance();
          } else {
            _transactionStatus = 'Transaction failed: ${result['message']}';
            _showErrorSnackBar(result['message']);
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _transactionStatus = 'Only Solana token transactions are supported currently';
        });
      }
    } catch (e) {
      log('Error sending token transaction: $e');
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
          title: const Text('Insufficient SOL for Fees'),
          content: const Text(
            'Your account needs SOL to pay for transaction fees. For testing on devnet, you can get free SOL from a faucet.'
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

  // Create a token account for the current token mint
  Future<void> _createTokenAccount() async {
    setState(() {
      _isLoading = true;
      _transactionStatus = 'Creating token account...';
    });
    
    try {
      final rpcUrl = SolanaTransaction.getRpcUrl(useMainnet: _useMainnet);
      final client = SolanaClient(
        rpcUrl: Uri.parse(rpcUrl),
        websocketUrl: Uri.parse(rpcUrl.replaceFirst('https', 'wss')),
      );
      
      final solBalance = await SolanaTransaction.getAccountBalance(
        address: widget.senderAddress,
        useMainnet: _useMainnet,
      );
      
      if (!solBalance['success'] || solBalance['balance'] < 0.002) {
        setState(() {
          _isLoading = false;
          _transactionStatus = 'Insufficient SOL to create token account';
        });
        _showErrorSnackBar('You need at least 0.002 SOL to create a token account');
        return;
      }
      
      // Create the token account
      final privateKeyBytes = base58.decode(widget.privateKey);
      final keyPair = await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: privateKeyBytes);
      
      final tokenAccount = await SolanaTransaction.getOrCreateAssociatedTokenAccount(
        owner: widget.senderAddress,
        mint: widget.tokenMintAddress,
        payer: widget.senderAddress,
        client: client,
        ownerPrivateKey: widget.privateKey,
      );
      
      setState(() {
        _isLoading = false;
        _tokenAccountAddress = tokenAccount;
        _transactionStatus = 'Token account created successfully!';
      });
      
      _loadTokenBalance();
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _transactionStatus = 'Error creating token account: ${e.toString()}';
      });
      _showErrorSnackBar('Failed to create token account: ${e.toString()}');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Token'),
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
                      Text(
                        "Token: ${widget.tokenSymbol}",
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
                                  "${double.parse(_tokenBalance.toString())} ${widget.tokenSymbol}",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _tokenBalance > 0 ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            onPressed: _loadTokenBalance,
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
                                // Refresh token balance when network changes
                                _loadTokenBalance();
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
                      if (_tokenAccountAddress != null) ...[                        
                        SizedBox(height: 4.rh),
                        Text(
                          "Token Account: $_tokenAccountAddress",
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
                  "Amount (${widget.tokenSymbol}):",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.rh),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter amount',
                  ),
                ),
                SizedBox(height: 24.rh),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendTokenTransaction,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.rh),
                    ),
                    child: Text(
                      'Send Token',
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
                              "Amount: ${_transactionResult!['amount']} ${widget.tokenSymbol}",
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