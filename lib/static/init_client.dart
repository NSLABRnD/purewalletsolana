import 'package:http/http.dart' as http;
import 'package:pure_wallet_2/static/constant.dart';
import 'package:web3dart/web3dart.dart';

InitClient web3Client = InitClient();

class InitClient {
  InitClient();
  Web3Client? ethClient;
  Web3Client? bnbClient;

  Web3Client? ethClient_test;
  Web3Client? bnbClient_test;

  void setClient() {
    ethClient = Web3Client(ethRpcUrl, http.Client());
    bnbClient = Web3Client(bnbRpcUrl, http.Client());
    // ethClient = _client;

    ethClient_test = Web3Client(ethRpcUrl_test, http.Client());
    bnbClient_test = Web3Client(bnbRpcUrl_test, http.Client());
  }

  Web3Client? getClient(NETWORK_MODE selcNet) {
    Web3Client? selectedWebclient;
    selectedWebclient = selcNet==NETWORK_MODE.MAIN ? ethClient: ethClient_test;
    return selectedWebclient;
  }

  Web3Client? getClientBnb(NETWORK_MODE selcNet) {
    Web3Client? selectedWebclient;
    selectedWebclient = selcNet==NETWORK_MODE.MAIN ? bnbClient: bnbClient_test;
    return selectedWebclient;
  }
}
