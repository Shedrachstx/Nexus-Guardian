# Nexus Guardian

A comprehensive secure digital asset management smart contract built on the Stacks blockchain using Clarity.

## Overview

Nexus Guardian provides a robust, multi-signature enabled platform for managing digital assets with enhanced security features. The contract implements guardian-based access control, multi-signature transaction approvals, and comprehensive asset management capabilities.

## Features

- **Multi-Signature Security**: Configurable signature thresholds for transaction approvals
- **Guardian Management**: Add/remove trusted guardians with administrative controls
- **Asset Tracking**: Comprehensive tracking of different asset types per user
- **Transaction Timeouts**: Automatic expiration of pending transactions for security
- **Comprehensive Validation**: Full input validation and error handling
- **Transparent Operations**: All transactions are fully auditable and traceable

## Contract Functions

### Guardian Management
- `add-guardian(principal)` - Add a new guardian (owner only)
- `remove-guardian(principal)` - Remove a guardian (owner only)
- `get-guardian-status(principal)` - Check if a principal is a guardian

### Asset Management
- `deposit-asset(amount, asset-type)` - Deposit assets into the contract
- `withdraw-asset(amount, asset-type)` - Withdraw assets from the contract
- `get-asset-balance(owner, asset-type)` - Check asset balance

### Transaction Management
- `initiate-transfer(recipient, amount, asset-type)` - Start a new transfer
- `sign-transaction(tx-id)` - Sign a pending transaction
- `execute-transaction(tx-id)` - Execute a fully signed transaction
- `get-transaction-details(tx-id)` - Get details of a transaction

### Configuration
- `set-signature-threshold(threshold)` - Set required signatures for transactions
- `get-signature-threshold()` - Get current signature threshold
- `get-transaction-timeout()` - Get transaction timeout in blocks

## Security Features

1. **Multi-Signature Approval**: All transfers require multiple guardian signatures
2. **Time-Based Expiry**: Transactions expire after a configurable timeout
3. **Guardian Validation**: Only approved guardians can initiate and sign transactions
4. **Balance Verification**: Comprehensive balance checks before execution
5. **Replay Protection**: Prevents double-signing and re-execution

## Error Codes

- `u100` - Unauthorized access
- `u101` - Invalid amount
- `u102` - Insufficient balance
- `u103` - Invalid recipient
- `u104` - Invalid threshold
- `u105` - Already signed
- `u106` - Transaction not found
- `u107` - Insufficient signatures
- `u108` - Transaction expired
- `u109` - Invalid guardian
- `u110` - Guardian limit reached
- `u111` - Invalid asset type

## Usage Example

```clarity
;; Add a guardian
(contract-call? .nexus-guardian add-guardian 'SP1234567890)

;; Deposit assets
(contract-call? .nexus-guardian deposit-asset u1000 "STX")

;; Initiate transfer
(contract-call? .nexus-guardian initiate-transfer 'SP0987654321 u100 "STX")

;; Sign transaction
(contract-call? .nexus-guardian sign-transaction u1)

;; Execute transaction
(contract-call? .nexus-guardian execute-transaction u1)
```

## Development

### Prerequisites
- Clarinet CLI
- Stacks blockchain environment

### Testing
```bash
clarinet check
clarinet test
```

