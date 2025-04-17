# PureWallet Solana

A multi-chain cryptocurrency wallet with support for Ethereum and Solana blockchains.

## Features

### Multi-Chain Support
- **Ethereum (ETH)** - Create and manage Ethereum wallets
- **Solana (SOL)** - Create and manage Solana wallets with full transaction support

### Wallet Management
- Import wallets using mnemonic phrases
- Import wallets using private keys
- View wallet addresses and private keys
- Switch between different blockchain networks

### Solana Features
- Send SOL to any Solana address
- Check account balances in real-time
- View transaction status and details
- Toggle between Devnet (testing) and Mainnet environments
- Get test SOL from faucets for Devnet testing
- View transactions in Solana Explorer

## How to Test

1. **Launch the application** and navigate to the homepage

2. **Test Mnemonic Import**:
   - Select your desired network (Ethereum or Solana) from the dropdown
   - Click on "Import Wallet from Mnemonic" to auto-fill a test mnemonic
   - Click the wallet icon button to generate the wallet
   - View the generated private key and address

3. **Test Private Key Import**:
   - Enter a private key in the Private Key field
   - Click the login icon button to import the wallet
   - View the wallet address associated with the private key

4. **Test Wallet Page**:
   - After importing a wallet, click the "Open Wallet Test Page" button
   - Explore additional wallet functionality on the test page

5. **Test Solana Transactions**:
   - Import a Solana wallet using either method
   - Navigate to the Send Transaction page
   - For testing, ensure the environment is set to "Devnet"
   - If your balance is 0, use the "Get SOL" button to open a faucet website
   - Enter a recipient address and amount
   - Send the transaction and view its status
   - Use the "Check Status" button to refresh transaction status
   - View transaction details in Solana Explorer with the "View in Explorer" button

## Development

This project is built with Flutter and supports both Ethereum and Solana blockchain interactions.

### Key Components
- `account_model.dart` - Core wallet functionality
- `solana_utils.dart` - Solana-specific utilities
- `solana_transaction.dart` - Solana transaction handling
- `hompage.dart` - Main wallet interface
- `test_wallet_page.dart` - Testing interface for wallet features
- `send_transaction_page.dart` - Solana transaction interface