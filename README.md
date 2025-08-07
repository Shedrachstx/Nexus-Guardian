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

# Nexus Guardian

A comprehensive secure digital asset management smart contract built on the Stacks blockchain using Clarity.

## Overview

Nexus Guardian provides a robust, multi-signature enabled platform for managing digital assets with enhanced security features. The contract implements guardian-based access control, multi-signature transaction approvals, emergency recovery mechanisms, and comprehensive asset management capabilities.

## Features

- **Multi-Signature Security**: Configurable signature thresholds for transaction approvals
- **Guardian Management**: Add/remove trusted guardians with administrative controls
- **Emergency Recovery System**: Time-locked emergency recovery mechanisms for lost guardian access
- **Asset Tracking**: Comprehensive tracking of different asset types per user
- **Transaction Timeouts**: Automatic expiration of pending transactions for security
- **Comprehensive Validation**: Full input validation and error handling
- **Transparent Operations**: All transactions are fully auditable and traceable

## Contract Functions

### Guardian Management
- `add-guardian(principal)` - Add a new guardian (owner only)
- `remove-guardian(principal)` - Remove a guardian (owner only)
- `get-guardian-status(principal)` - Check if a principal is a guardian

### Emergency Recovery System
- `set-recovery-address(principal)` - Set emergency recovery address (owner only)
- `initiate-emergency-recovery()` - Initiate recovery process (recovery address only)
- `cancel-emergency-recovery()` - Cancel ongoing recovery (owner only)
- `execute-emergency-recovery(new-owner)` - Execute recovery after delay period
- `get-recovery-address()` - Get current recovery address
- `get-recovery-status()` - Get recovery process status and timing

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
2. **Emergency Recovery**: Time-locked recovery system with ~1 week delay and 10-day execution window
3. **Time-Based Expiry**: Transactions expire after a configurable timeout
4. **Guardian Validation**: Only approved guardians can initiate and sign transactions
5. **Balance Verification**: Comprehensive balance checks before execution
6. **Replay Protection**: Prevents double-signing and re-execution

## Emergency Recovery Process

The emergency recovery system provides a secure way to recover access if guardian keys are lost:

1. **Setup**: Owner sets a recovery address using `set-recovery-address()`
2. **Initiation**: Recovery address calls `initiate-emergency-recovery()` to start the process
3. **Delay Period**: ~1 week delay before recovery can be executed
4. **Execution Window**: 10-day window after delay to execute recovery
5. **Cancellation**: Owner can cancel recovery at any time during delay period

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
- `u112` - Recovery not initiated
- `u113` - Recovery already initiated
- `u114` - Recovery too early
- `u115` - Recovery expired
- `u116` - Invalid recovery address

## Usage Example

```clarity
;; Add a guardian
(contract-call? .nexus-guardian add-guardian 'SP1234567890)

;; Set recovery address
(contract-call? .nexus-guardian set-recovery-address 'SP0987654321)

;; Deposit assets
(contract-call? .nexus-guardian deposit-asset u1000 "STX")

;; Initiate transfer
(contract-call? .nexus-guardian initiate-transfer 'SP0987654321 u100 "STX")

;; Sign transaction
(contract-call? .nexus-guardian sign-transaction u1)

;; Execute transaction
(contract-call? .nexus-guardian execute-transaction u1)

;; Emergency recovery (from recovery address)
(contract-call? .nexus-guardian initiate-emergency-recovery)
```

## Development Roadmap

### Phase 1: Core Security Enhancements
- ✅ **Emergency Recovery System** - Implement time-locked emergency recovery mechanisms for lost guardian access

### Phase 2: Advanced Asset Management
- **Asset Delegation Framework** - Allow temporary delegation of asset management rights to other principals
- **Automated Recurring Transfers** - Schedule recurring payments with customizable intervals and conditions

### Phase 3: Stacks Ecosystem Integration
- **Integration with STX Stacking** - Direct integration with Stacks stacking for earning Bitcoin rewards
- **Multi-Chain Bridge Support** - Enable cross-chain asset transfers and management

### Phase 4: Analytics and Reporting
- **Advanced Analytics Dashboard** - Real-time analytics and reporting for asset movements and guardian activities
- **Conditional Smart Escrow** - Implement conditional escrow services with milestone-based releases

### Phase 5: Governance and Community
- **Governance Token Integration** - Add governance capabilities for decentralized decision making
- **NFT Management Module** - Extend functionality to manage and transfer NFTs with multi-signature security

### Phase 6: DeFi Integration
- **DeFi Protocol Integration** - Direct integration with lending, borrowing, and yield farming protocols

## Development

### Prerequisites
- Clarinet CLI
- Stacks blockchain environment

### Testing
```bash
clarinet check
clarinet test
```

### Deployment
```bash
clarinet deploy --network testnet
```

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Security

This contract handles valuable digital assets. Please:
- Thoroughly test any modifications
- Follow security best practices
- Report any vulnerabilities responsibly
- Use the emergency recovery system as a last resort

For security issues, please contact the maintainers privately before public disclosure.