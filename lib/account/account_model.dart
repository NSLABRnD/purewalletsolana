
import 'dart:developer';
import 'dart:typed_data';

import 'package:pure_wallet_2/static/constant.dart';
import 'package:wallet/wallet.dart' as wallet;
import 'package:mnemonic/mnemonic.dart' as ibip39;

import 'Mnemonic_utils.dart';
import 'solana_utils.dart';

getAccountBasedOnMnemonic(String entropyString, int depth, {BLOCKCHAIN_NETWORK network = BLOCKCHAIN_NETWORK.ETH}) async {
  switch (network) {
    case BLOCKCHAIN_NETWORK.ETH:
      wallet.PrivateKey privateKey =
          MnemonicUtils.getEthPrivateKeyFromMnemonic(ibip39.mnemonicToEntropy(entropyString), depth);
      String privateKeyHex = MnemonicUtils.bigIntPrivateKeyToHex(privateKey.value);
      final publicKey = wallet.ethereum.createPublicKey(privateKey);
      final address = wallet.ethereum.createAddress(publicKey);
      log('ETH storeNewAccountFromMnemonic: $address, $privateKeyHex');
      globalVar.account_address = address;
      return {
        ACCOUNT_ASSET.PRIV_KEY: '0x$privateKeyHex',
        ACCOUNT_ASSET.ADDRESS: address
      };
    case BLOCKCHAIN_NETWORK.SOL:
      Uint8List privateKey = SolanaUtils.getSolPrivateKeyFromMnemonic(
          ibip39.mnemonicToEntropy(entropyString), depth);
      final accountInfo = SolanaUtils.createSolanaAccountFromPrivateKey(privateKey);
      log('SOL storeNewAccountFromMnemonic: ${accountInfo['address']}, ${accountInfo['privateKey']}');
      globalVar.account_address = accountInfo['address'];
      return {
        ACCOUNT_ASSET.PRIV_KEY: accountInfo['privateKey'],
        ACCOUNT_ASSET.ADDRESS: accountInfo['address']
      };
    default:
      throw Exception('Unsupported blockchain network');
  }
}

getAccountFromPrivateKey(String privateKey, {BLOCKCHAIN_NETWORK network = BLOCKCHAIN_NETWORK.ETH}) async {
  switch (network) {
    case BLOCKCHAIN_NETWORK.ETH:
      // Remove '0x' prefix if present
      String cleanPrivateKey = privateKey.startsWith('0x') ? privateKey.substring(2) : privateKey;
      
      // Create wallet from private key
      final ethPrivateKey = wallet.PrivateKey(BigInt.parse(cleanPrivateKey, radix: 16));
      final publicKey = wallet.ethereum.createPublicKey(ethPrivateKey);
      final address = wallet.ethereum.createAddress(publicKey);
      
      log('ETH account from private key: $address');
      globalVar.account_address = address;
      return {
        ACCOUNT_ASSET.PRIV_KEY: '0x$cleanPrivateKey',
        ACCOUNT_ASSET.ADDRESS: address
      };
    case BLOCKCHAIN_NETWORK.SOL:
      // For Solana, private key can be in base58 or hex format
      Uint8List solPrivateKey;
      if (privateKey.startsWith('0x')) {
        // Handle hex format
        solPrivateKey = SolanaUtils.hexToPrivateKey(privateKey);
      } else {
        // Handle base58 format
        solPrivateKey = SolanaUtils.base58DecodePrivateKey(privateKey);
      }
      
      final accountInfo = SolanaUtils.createSolanaAccountFromPrivateKey(solPrivateKey);
      log('SOL account from private key: ${accountInfo['address']}');
      globalVar.account_address = accountInfo['address'];
      return {
        ACCOUNT_ASSET.PRIV_KEY: accountInfo['privateKey'],
        ACCOUNT_ASSET.ADDRESS: accountInfo['address']
      };
    default:
      throw Exception('Unsupported blockchain network');
  }
}

