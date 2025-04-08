
import 'dart:developer';

import 'package:wallet/wallet.dart' as wallet;

import 'Mnemonic_utils.dart';



getAccountBasedOnMnemonic(String entropyString, int depth) async {
  wallet.PrivateKey privateKey =
      MnemonicUtils.getEthPrivateKeyFromMnemonic(entropyString, depth);
  String privateKeyHex = MnemonicUtils.bigIntPrivateKeyToHex(privateKey.value);
  final publicKey = wallet.ethereum.createPublicKey(privateKey);
  final address = wallet.ethereum.createAddress(publicKey);
  log('ETH storeNewAccountFromMnemonic: $address, $privateKeyHex');
}

