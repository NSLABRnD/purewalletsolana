import 'dart:typed_data';
import 'package:bs58/bs58.dart';
import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';
import 'package:mnemonic/mnemonic.dart' as ibip39;
import 'package:wallet/wallet.dart' as wallet;
import 'package:solana/solana.dart';
import 'dart:convert';
import 'dart:async';

/// Utility class for Solana-related cryptographic operations
class SolanaUtils {
  /// Derives a Solana private key from a mnemonic phrase
  /// 
  /// [entropyString] - Either the entropy or mnemonic phrase
  /// [depth] - The account index to derive
  /// [isEntropy] - Whether the entropyString is entropy (true) or mnemonic (false)
  static Uint8List getSolPrivateKeyFromMnemonic(String entropyString, int depth, {
    bool isEntropy = true,
  }) {
    String mnemonic = '';
    if (isEntropy) {
      mnemonic = ibip39.entropyToMnemonic(entropyString);
    } else {
      mnemonic = entropyString;
    }
    const passphrase = '';
    final seed = wallet.mnemonicToSeed(mnemonic.split(' '), passphrase: passphrase);
    
    // Solana uses m/44'/501'/0'/0' derivation path
    // 501 is Solana's coin type according to SLIP-0044
    final master = wallet.ExtendedPrivateKey.master(seed, wallet.xprv);
    final root = master.forPath("m/44'/501'/$depth'/0'");
    final privateKey = (root as wallet.ExtendedPrivateKey).key;
    
    return _bigIntToUint8List(privateKey);
  }
  
  /// Creates a Solana account from a private key
  /// 
  /// [privateKey] - The private key as a Uint8List
  /// Returns a Map containing the private key (as base58) and the public address
  static Future<Map<String, String>> createSolanaAccountFromPrivateKey(Uint8List privateKey) async {
    // For Solana, the public key is derived using Ed25519 curve
    // Using the proper Solana SDK implementation
    
    // Create a keypair from the private key
    final keyPair = await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: privateKey);
    
    // Get the public key (address) in base58 format
    final address = keyPair.address;
    final privateKeyBase58 = base58EncodePrivateKey(privateKey);
    
    return {
      'privateKey': privateKeyBase58,
      'address': address,
    };
  }
  
  /// Converts a private key from hex string to Uint8List
  static Uint8List hexToPrivateKey(String hexPrivateKey) {
    // Remove '0x' prefix if present
    if (hexPrivateKey.startsWith('0x')) {
      hexPrivateKey = hexPrivateKey.substring(2);
    }
    
    // Decode hex string to bytes
    return Uint8List.fromList(HEX.decode(hexPrivateKey));
  }
  
  /// Encodes a private key as base58 string
  static String base58EncodePrivateKey(Uint8List privateKey) {
    return base58.encode(privateKey);
  }
  
  /// Encodes a public key as base58 string (Solana address format)
  static String base58EncodePublicKey(Uint8List publicKey) {
    return base58.encode(publicKey);
  }
  
  /// Decodes a base58 encoded private key
  static Uint8List base58DecodePrivateKey(String base58PrivateKey) {
    return base58.decode(base58PrivateKey);
  }
  
  /// Derives a public key from a private key using Ed25519
  /// Uses the proper Solana SDK implementation
  static Future<Uint8List> derivePublicKeyEd25519(Uint8List privateKey) async {
    // Create a keypair from the private key using Solana SDK
    final keyPair = await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: privateKey);
    
    // Get the public key bytes
    return base58.decode(keyPair.address);
  }
  
  /// Gets the Solana account information (balance, etc.)
  /// 
  /// [address] - The Solana address to query
  /// [useMainnet] - Whether to use mainnet (true) or devnet (false)
  static Future<Map<String, dynamic>> getAccountInfo(String address, {bool useMainnet = false}) async {
    try {
      final rpcUrl = useMainnet ? 'https://api.mainnet-beta.solana.com' : 'https://api.devnet.solana.com';
      
      // Initialize Solana client
      final client = SolanaClient(
        rpcUrl: Uri.parse(rpcUrl),
        websocketUrl: Uri.parse(rpcUrl.replaceFirst('https', 'wss')),
      );
      
      // Get account info
      final publicKey = Ed25519HDPublicKey.fromBase58(address);
      final account = await client.rpcClient.getAccountInfo(publicKey.toBase58());
      
      // Get balance
      final balanceResult = await client.rpcClient.getBalance(publicKey.toBase58());
      
      // Properly extract the balance value from BalanceResult
      final balanceInLamports = balanceResult.value;
      final balanceInSol = balanceInLamports / 1000000000; // Convert lamports to SOL
      
      // Properly extract account data and executable flag from AccountResult
      final accountData = account?.value?.data;
      final isExecutable = account?.value?.executable ?? false;
      
      return {
        'success': true,
        'address': address,
        'balance': balanceInSol,
        'account': accountData,
        'executable': isExecutable,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get account info',
      };
    }
  }
  
  /// Converts a BigInt to Uint8List
  static Uint8List _bigIntToUint8List(BigInt bigInt) {
    var hexString = bigInt.toRadixString(16);
    if (hexString.length % 2 != 0) {
      hexString = '0$hexString';
    }
    return Uint8List.fromList(HEX.decode(hexString));
  }
}