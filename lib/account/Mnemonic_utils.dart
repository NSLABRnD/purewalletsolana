import 'dart:typed_data';

import 'package:mnemonic/mnemonic.dart' as ibip39;
import 'package:wallet/wallet.dart' as wallet;
import 'package:crypto/crypto.dart';
import 'package:bs58/bs58.dart';
import 'package:hex/hex.dart';

class MnemonicUtils {
  // Entropy MUST BE transformed to Mnemonic.
  static wallet.PrivateKey getEthPrivateKeyFromMnemonic(String entropyString,
      int depth, {
        bool isEntropy = true,
      }) {
    String mnemonic = '';
    if (isEntropy) {
      mnemonic = ibip39.entropyToMnemonic(entropyString);
    } else {
      mnemonic = entropyString;
    }
    const passphrase = '';
    final seed =
    wallet.mnemonicToSeed(mnemonic.split(' '), passphrase: passphrase);
    final master = wallet.ExtendedPrivateKey.master(seed, wallet.xprv);
    final root = master.forPath("m/44'/60'/0'/0/$depth");
    final privateKey =
    wallet.PrivateKey((root as wallet.ExtendedPrivateKey).key);

    return privateKey;
  }
  static String bigIntPrivateKeyToHex(BigInt privateKey) {
    final privateKeyBytes = _bigIntToUint8List(privateKey)
        .buffer
        .asUint8List()
        .map((i) => i.toRadixString(16))
        .toList();
    var privateKeyHex = '';
    for (String val in privateKeyBytes) {
      // log(val);
      if (val.length < 2) {
        privateKeyHex += '0$val';
      } else {
        privateKeyHex += val;
      }
    }
    return privateKeyHex;
  }

  static Uint8List _bigIntToUint8List(BigInt bigInt) =>
      _bigIntToByteData(bigInt).buffer.asUint8List();

  static ByteData _bigIntToByteData(BigInt bigInt) {
    final data = ByteData((bigInt.bitLength / 8).ceil());
    var tempBigInt = bigInt;

    for (var i = 1; i <= data.lengthInBytes; i++) {
      data.setUint8(data.lengthInBytes - i, tempBigInt.toUnsigned(8).toInt());
      tempBigInt = tempBigInt >> 8;
    }
    return data;
  }

}