import 'dart:typed_data';
import 'package:bs58/bs58.dart';
import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';
import 'package:mnemonic/mnemonic.dart' as ibip39;
import 'package:wallet/wallet.dart' as wallet;

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
  static Map<String, String> createSolanaAccountFromPrivateKey(Uint8List privateKey) {
    // For Solana, the public key is derived using Ed25519 curve
    // The wallet package doesn't directly support Ed25519, so we're using a simplified approach
    // In a production app, you would use a dedicated Solana library
    
    // For Ed25519, the public key is derived from the private key
    final publicKey = _derivePublicKeyEd25519(privateKey);
    
    // In Solana, the public key is also the address
    final address = base58EncodePublicKey(publicKey);
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
  /// This is a simplified implementation for demonstration
  static Uint8List _derivePublicKeyEd25519(Uint8List privateKey) {
    // In a real implementation, you would use a proper Ed25519 library
    // This is a placeholder implementation
    // The actual derivation is more complex
    
    // For demonstration, we're using a hash of the private key
    // DO NOT use this in production - use a proper Ed25519 implementation
    final hash = sha256.convert(privateKey).bytes;
    return Uint8List.fromList(hash);
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