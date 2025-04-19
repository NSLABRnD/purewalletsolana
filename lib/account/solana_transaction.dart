import 'package:bs58/bs58.dart';
import 'package:solana/solana.dart';
import 'package:solana/encoder.dart' as encoder;
import 'package:solana/dto.dart';
import 'dart:typed_data';
import 'package:solana/src/encoder/byte_array.dart' show ByteArray;
import 'package:solana/solana.dart' show TokenProgram, AssociatedTokenAccountProgram, TokenInstruction;


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

  /// Sends SPL tokens from one account to another
  /// 
  /// [senderPrivateKey] - The sender's private key in base58 format
  /// [recipientAddress] - The recipient's Solana address
  /// [tokenMintAddress] - The SPL token mint address
  /// [amount] - The amount of tokens to send (in the smallest denomination)
  /// [useMainnet] - Whether to use mainnet (true) or devnet (false)
  static Future<Map<String, dynamic>> sendToken({
    required String senderPrivateKey,
    required String recipientAddress,
    required String tokenMintAddress,
    required int amount,
    bool useMainnet = false,
  }) async {
    try {
      final rpcUrl = getRpcUrl(useMainnet: useMainnet);
      
      final client = SolanaClient(
        rpcUrl: Uri.parse(rpcUrl),
        websocketUrl: Uri.parse(rpcUrl.replaceFirst('https', 'wss')),
      );
      
      // Decode private key and create keypair
      final privateKeyBytes = base58.decode(senderPrivateKey);
      final keyPair = await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: privateKeyBytes);
      final senderPublicKey = keyPair.publicKey;

      // Find the sender's associated token account
      final senderTokenAccount = await findAssociatedTokenAccount(
        owner: senderPublicKey.toBase58(),
        mint: tokenMintAddress,
        client: client,
      );
      
      // If sender token account doesn't exist, create it
      String actualSenderTokenAccount;
      if (senderTokenAccount == null) {
        try {
          // Create the token account for the sender
          actualSenderTokenAccount = await getOrCreateAssociatedTokenAccount(
            owner: senderPublicKey.toBase58(),
            mint: tokenMintAddress,
            payer: senderPublicKey.toBase58(),
            client: client,
          );
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to create token account',
            'message': 'Failed to create token account: ${e.toString()}. You need SOL to create a token account.',
            'needsTokenAccount': true,
          };
        }
      } else {
        actualSenderTokenAccount = senderTokenAccount;
      }
      
      // Get token account balance
      final tokenBalance = await getTokenAccountBalance(
        tokenAccountAddress: actualSenderTokenAccount,
        useMainnet: useMainnet,
      );
      
      if (tokenBalance < amount) {
        return {
          'success': false,
          'error': 'Insufficient token balance',
          'message': 'Insufficient token balance. You have $tokenBalance tokens, but you need at least $amount.',
          'balance': tokenBalance,
          'required': amount,
        };
      }
      
      // Check SOL balance for transaction fees
      final balanceResult = await client.rpcClient.getBalance(senderPublicKey.toBase58());
      final solBalanceInLamports = balanceResult.value;
      
      // Estimated fee for token transfer is around 10000 lamports
      if (solBalanceInLamports < 10000) {
        return {
          'success': false,
          'error': 'Insufficient SOL for fees',
          'message': 'Insufficient SOL for transaction fees. You need at least ${lamportsToSol(10000)} SOL for fees.',
          'balance': lamportsToSol(solBalanceInLamports),
          'required': lamportsToSol(10000),
          'faucetUrl': useMainnet ? '' : 'https://solfaucet.com',
        };
      }

      final recipientTokenAccount = await getOrCreateAssociatedTokenAccount(
        owner: recipientAddress,
        mint: tokenMintAddress,
        payer: senderPublicKey.toBase58(),
        client: client,
        ownerPrivateKey: senderPrivateKey,
      );
      
      // Create token transfer instruction
      final transferInstruction = TokenInstruction.transfer(
        source: Ed25519HDPublicKey.fromBase58(actualSenderTokenAccount),
        destination: Ed25519HDPublicKey.fromBase58(recipientTokenAccount),
        owner: senderPublicKey,
        amount: amount,
      );
      
      // Create and send transaction
      final message = Message.only(transferInstruction);
      final signature = await client.sendAndConfirmTransaction(
        message: message,
        signers: [keyPair],
        commitment: Commitment.confirmed,
      );
      
      return {
        'success': true,
        'txHash': signature,
        'explorerUrl': getExplorerUrl(signature, useMainnet: useMainnet),
        'message': 'Token transfer submitted successfully',
        'amount': amount,
        'recipient': recipientAddress,
        'tokenMint': tokenMintAddress,
      };
    } catch (e) {
      String errorMessage = 'Failed to send token transaction';
      
      if (e.toString().contains('AccountNotFound')) {
        errorMessage = 'Account not found. Please check the addresses and try again.';
      } else if (e.toString().contains('insufficient funds')) {
        errorMessage = 'Insufficient funds for transaction fees';
      } else if (e.toString().contains('blockhash not found')) {
        errorMessage = 'Network error: blockhash not found. Please try again later';
      }
      
      return {
        'success': false,
        'error': e.toString(),
        'message': errorMessage,
      };
    }
  }
  
  /// Derive the associated token account address for a wallet and token mint
  static Future<Ed25519HDPublicKey> _deriveAssociatedTokenAccount({
    required Ed25519HDPublicKey owner,
    required Ed25519HDPublicKey mint,
  }) async {
    final tokenProgramId = Ed25519HDPublicKey.fromBase58(TokenProgram.programId);
    final associatedTokenProgramId = Ed25519HDPublicKey.fromBase58(AssociatedTokenAccountProgram.programId);

    final seeds = [
      owner.bytes,
      tokenProgramId.bytes,
      mint.bytes,
    ];
    
    final result = await Ed25519HDPublicKey.findProgramAddress(
      seeds: seeds,
      programId: associatedTokenProgramId,
    );

    return result;
  }

  /// Find the associated token account for a wallet
  static Future<String?> findAssociatedTokenAccount({
    required String owner,
    required String mint,
    required SolanaClient client,
  }) async {
    try {
      // Get the associated token account address
      final ownerPubkey = Ed25519HDPublicKey.fromBase58(owner);
      final mintPubkey = Ed25519HDPublicKey.fromBase58(mint);

      final Ed25519HDPublicKey associatedAddress = await _deriveAssociatedTokenAccount(
        owner: ownerPubkey,
        mint: mintPubkey,
      );
      
      final address = associatedAddress.toBase58();
      
      // Check if the account exists and has valid data
      try {
        final accountInfo = await client.rpcClient.getAccountInfo(
          address,
          encoding: Encoding.base64,
        );
        if (accountInfo != null && accountInfo.value != null) {
          return address;
        }
      } catch (e) {
        print('Error checking token account: ${e.toString()}');
        return null;
      }
      
      return null;
    } catch (e) {
      print('Error in findAssociatedTokenAccount: ${e.toString()}');
      return null;
    }
  }
  
  /// Get or create an associated token account
  static Future<String> getOrCreateAssociatedTokenAccount({
    required String owner,
    required String mint,
    required String payer,
    required SolanaClient client,
    String? ownerPrivateKey,
  }) async {
    // First check if the account already exists
    final existingAccount = await findAssociatedTokenAccount(
      owner: owner,
      mint: mint,
      client: client,
    );
    
    if (existingAccount != null) {
      return existingAccount;
    }
    
    // If not, create it
    final ownerPubkey = Ed25519HDPublicKey.fromBase58(owner);
    final mintPubkey = Ed25519HDPublicKey.fromBase58(mint);
    final payerPubkey = Ed25519HDPublicKey.fromBase58(payer);
    final tokenProgramId = Ed25519HDPublicKey.fromBase58(TokenProgram.programId);
    final associatedTokenProgramId = Ed25519HDPublicKey.fromBase58(AssociatedTokenAccountProgram.programId);

    final Ed25519HDPublicKey associatedAddress = await _deriveAssociatedTokenAccount(
      owner: ownerPubkey,
      mint: mintPubkey,
    );
    final associatedTokenAddress = associatedAddress.toBase58();

    final systemProgramId = Ed25519HDPublicKey.fromBase58('11111111111111111111111111111111');
    final rentSysvarId = Ed25519HDPublicKey.fromBase58('SysvarRent111111111111111111111111111111111');

    const bool ownerNeedsToSign = false;
    
    final instruction = encoder.Instruction(
      programId: associatedTokenProgramId,
      accounts: [
        encoder.AccountMeta.writeable(pubKey: payerPubkey, isSigner: true),
        encoder.AccountMeta.writeable(pubKey: Ed25519HDPublicKey.fromBase58(associatedTokenAddress), isSigner: false),
        encoder.AccountMeta.readonly(pubKey: ownerPubkey, isSigner: ownerNeedsToSign),
        encoder.AccountMeta.readonly(pubKey: mintPubkey, isSigner: false),
        encoder.AccountMeta.readonly(pubKey: systemProgramId, isSigner: false),
        encoder.AccountMeta.readonly(pubKey: tokenProgramId, isSigner: false),
        encoder.AccountMeta.readonly(pubKey: rentSysvarId, isSigner: false),
      ],
      data: ByteArray(List<int>.filled(0, 0))
    );

    if (ownerPrivateKey == null) {
      throw Exception('Payer private key is required to create a token account');
    }

    final payerKeyBytes = base58.decode(ownerPrivateKey);
    final payerKeypair = await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: payerKeyBytes);
    
    // Prepare signers list - only the payer needs to sign
    final signers = [payerKeypair];

    // Send the transaction
    await client.sendAndConfirmTransaction(
      message: Message.only(instruction),
      signers: signers,
      commitment: Commitment.confirmed,
    );
    
    return associatedTokenAddress;
  }
  
  /// Get token account balance
  static Future<int> getTokenAccountBalance({
    required String tokenAccountAddress,
    bool useMainnet = false,
  }) async {
    try {
       final rpcUrl = getRpcUrl(useMainnet: useMainnet);
      
      final client = SolanaClient(
        rpcUrl: Uri.parse(rpcUrl),
        websocketUrl: Uri.parse(rpcUrl.replaceFirst('https', 'wss')),
      );
      final response = await  client.rpcClient.getTokenAccountBalance(tokenAccountAddress);
      
      if (response.value != null && response.value.amount != null) {
        return int.parse(response.value.amount);
        }
      
      return 0;
    } catch (e) {
      return 0;
    }
  }
}