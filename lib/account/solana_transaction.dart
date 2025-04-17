import 'package:bs58/bs58.dart';
import 'package:solana/solana.dart';
import 'package:solana/encoder.dart';
import 'package:solana/dto.dart';


enum Cluster { mainnet, devnet, testnet }


class SolanaTransaction {
  static const String _devnetRpcUrl = 'https://api.devnet.solana.com';
  static const String _mainnetRpcUrl = 'https://api.mainnet-beta.solana.com';
  
  
  static String getRpcUrl({bool useMainnet = false}) {
    return useMainnet ? _mainnetRpcUrl : _devnetRpcUrl;
  }
  
  /// Gets the appropriate explorer URL for a transaction
  static String getExplorerUrl(String txHash, {bool useMainnet = false}) {
    final network = useMainnet ? 'mainnet-beta' : 'devnet';
    return 'https://explorer.solana.com/tx/$txHash?cluster=$network';
  }
  
  /// Converts SOL to lamports (1 SOL = 1,000,000,000 lamports)
  static int solToLamports(double sol) {
    return (sol * 1000000000).round();
  }

  /// Converts lamports to SOL (1 SOL = 1,000,000,000 lamports)
  static double lamportsToSol(int lamports) {
    return lamports / 1000000000;
  }

  
  /// [senderPrivateKey] - The sender's private key in base58 format
  /// [recipientAddress] - The recipient's Solana address
  /// [amountLamports] - The amount to send in lamports
  /// [useMainnet] - Whether to use mainnet (true) or devnet (false)
  static Future<Map<String, dynamic>> sendSol({
    required String senderPrivateKey,
    required String recipientAddress,
    required int amountLamports,
    bool useMainnet = false,
  }) async {
    try {
      final rpcUrl = getRpcUrl(useMainnet: useMainnet);
      
      final client = SolanaClient(
        rpcUrl: Uri.parse(rpcUrl),
        websocketUrl: Uri.parse(rpcUrl.replaceFirst('https', 'wss')),
      );
      
      final privateKeyBytes = base58.decode(senderPrivateKey);
      
      final keyPair = await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: privateKeyBytes);
      
      final senderPublicKey = keyPair.publicKey;
      
      // Check account balance before sending transaction
      final balanceResult = await client.rpcClient.getBalance(senderPublicKey.toBase58());
      final balanceInLamports = balanceResult.value;
      
      // Check if account has enough funds (including a small amount for transaction fee)
      if (balanceInLamports < amountLamports + 5000) { // 5000 lamports as an estimated fee
        return {
          'success': false,
          'error': 'Insufficient funds',
          'message': 'Insufficient funds. Your balance is ${lamportsToSol(balanceInLamports)} SOL, but you need at least ${lamportsToSol(amountLamports + 5000)} SOL (including fees).',
          'balance': lamportsToSol(balanceInLamports),
          'required': lamportsToSol(amountLamports + 5000),
          'faucetUrl': useMainnet ? '' : 'https://solfaucet.com',
        };
      }
      
      final instruction = SystemInstruction.transfer(
        fundingAccount: senderPublicKey,
        recipientAccount: Ed25519HDPublicKey.fromBase58(recipientAddress),
        lamports: amountLamports,
      );
      
      final message = Message.only(instruction);
      final signature = await client.sendAndConfirmTransaction(
        message: message,
        signers: [keyPair],
        commitment: Commitment.confirmed,
      );
      
      return {
        'success': true,
        'txHash': signature,
        'explorerUrl': getExplorerUrl(signature, useMainnet: useMainnet),
        'message': 'Transaction submitted successfully',
        'amount': lamportsToSol(amountLamports),
        'recipient': recipientAddress,
      };
    } catch (e) {
      String errorMessage = 'Failed to send transaction';
      
      if (e.toString().contains('AccountNotFound') || 
          e.toString().contains('found no record of a prior credit')) {
        errorMessage = 'Account not found or has no SOL. Please fund this account using a faucet: https://solfaucet.com';
      } else if (e.toString().contains('insufficient funds')) {
        errorMessage = 'Insufficient funds for transaction';
      } else if (e.toString().contains('blockhash not found')) {
        errorMessage = 'Network error: blockhash not found. Please try again later';
      }
      
      return {
        'success': false,
        'error': e.toString(),
        'message': errorMessage,
        'faucetUrl': useMainnet ? '' : 'https://solfaucet.com',
      };
    }
  }
  
  
  /// [address] - The Solana address to check
  /// [useMainnet] - Whether to use mainnet (true) or devnet (false)
  static Future<Map<String, dynamic>> getAccountBalance({
    required String address,
    bool useMainnet = false,
  }) async {
    try {
      final rpcUrl = getRpcUrl(useMainnet: useMainnet);
      
      final client = SolanaClient(
        rpcUrl: Uri.parse(rpcUrl),
        websocketUrl: Uri.parse(rpcUrl.replaceFirst('https', 'wss')),
      );
      
      // Get balance
      final balanceResult = await client.rpcClient.getBalance(address);
      final balanceInLamports = balanceResult.value;
      final balanceInSol = lamportsToSol(balanceInLamports);
      
      return {
        'success': true,
        'balance': balanceInSol,
        'balanceLamports': balanceInLamports,
        'address': address,
        'faucetUrl': useMainnet ? '' : 'https://solfaucet.com',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get account balance',
        'faucetUrl': useMainnet ? '' : 'https://solfaucet.com',
      };
    }
  }

  
  /// [txHash] - The transaction hash/signature
  /// [useMainnet] - Whether to use mainnet (true) or devnet (false)
  static Future<Map<String, dynamic>> getTransactionStatus({
    required String txHash,
    bool useMainnet = false,
  }) async {
    try {
      final rpcUrl = getRpcUrl(useMainnet: useMainnet);
      
      final client = SolanaClient(
        rpcUrl: Uri.parse(rpcUrl),
        websocketUrl: Uri.parse(rpcUrl.replaceFirst('https', 'wss')),
      );
      
      // Get transaction details
      final TransactionDetails? transactionDetails = await client.rpcClient.getTransaction(
        txHash,
        commitment: Commitment.confirmed,
      );
      
      // Check if transaction exists
      if (transactionDetails == null) {
        return {
          'success': false,
          'status': 'not_found',
          'message': 'Transaction not found',
          'explorerUrl': getExplorerUrl(txHash, useMainnet: useMainnet),
        };
      }
      
      // Check if transaction was confirmed
      final bool confirmed = transactionDetails.meta != null && 
                            transactionDetails.meta!.err == null;
      
      return {
        'success': true,
        'status': confirmed ? 'confirmed' : 'failed',
        'message': confirmed ? 'Transaction confirmed' : 'Transaction failed',
        'explorerUrl': getExplorerUrl(txHash, useMainnet: useMainnet),
        'data': transactionDetails,
      };
    } catch (e) {
      return {
        'success': false,
        'status': 'error',
        'message': 'Failed to get transaction status: ${e.toString()}',
        'explorerUrl': getExplorerUrl(txHash, useMainnet: useMainnet),
      };
    }
  }


}