
// String ganacheLocalHost = "http://10.0.2.2:7545"; //unused
// String ganacheWS = "ws://10.0.2.2:7545"; //unused
// String privateNetworkrpc = "http://192.168.137.156:8545"; //unused
// String contractAddress_uniswap = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"; //unused
// String contractAddress_uniswapV3R2 = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45"; //unused

String ethRpcUrl = "https://eth.llamarpc.com";
String bnbRpcUrl = "https://bsc-pokt.nodies.app";
// String apiMempoolBitcoin = 'https://mempool.space/api/tx/';
// String apiXrpLedger = 'https://s1.ripple.com:51234/';

String ethRpcUrl_test = "https://1rpc.io/sepolia";
String bnbRpcUrl_test = "https://data-seed-prebsc-1-s1.bnbchain.org:8545";

enum NETWORK {TEST, MAIN}

GlobalVariable globalVar = GlobalVariable();

class GlobalVariable {
  init() {
    account_address = '';
  }
  var account_address;
}