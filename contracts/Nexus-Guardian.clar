;; Nexus Guardian - Secure Digital Asset Management with Delegation
;; A comprehensive smart contract for secure asset management with multi-signature capabilities and delegation

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_INVALID_RECIPIENT (err u103))
(define-constant ERR_INVALID_THRESHOLD (err u104))
(define-constant ERR_ALREADY_SIGNED (err u105))
(define-constant ERR_TRANSACTION_NOT_FOUND (err u106))
(define-constant ERR_INSUFFICIENT_SIGNATURES (err u107))
(define-constant ERR_TRANSACTION_EXPIRED (err u108))
(define-constant ERR_INVALID_GUARDIAN (err u109))
(define-constant ERR_GUARDIAN_LIMIT_REACHED (err u110))
(define-constant ERR_INVALID_ASSET_TYPE (err u111))
(define-constant ERR_RECOVERY_NOT_INITIATED (err u112))
(define-constant ERR_RECOVERY_ALREADY_INITIATED (err u113))
(define-constant ERR_RECOVERY_TOO_EARLY (err u114))
(define-constant ERR_RECOVERY_EXPIRED (err u115))
(define-constant ERR_INVALID_RECOVERY_ADDRESS (err u116))
(define-constant ERR_DELEGATION_EXISTS (err u117))
(define-constant ERR_DELEGATION_NOT_FOUND (err u118))
(define-constant ERR_DELEGATION_EXPIRED (err u119))
(define-constant ERR_INVALID_DELEGATE (err u120))
(define-constant ERR_DELEGATION_LIMIT_EXCEEDED (err u121))
(define-constant ERR_INVALID_EXPIRY (err u122))

;; Emergency Recovery Constants
(define-constant RECOVERY_DELAY_BLOCKS u1008) ;; ~1 week in blocks
(define-constant RECOVERY_WINDOW_BLOCKS u1440) ;; ~10 days window after delay

;; Delegation Constants
(define-constant MAX_DELEGATION_DURATION u144000) ;; ~100 days maximum delegation
(define-constant MIN_DELEGATION_DURATION u144) ;; ~1 day minimum delegation

;; Data Variables
(define-data-var next-tx-id uint u0)
(define-data-var next-delegation-id uint u0)
(define-data-var signature-threshold uint u2)
(define-data-var transaction-timeout uint u144) ;; ~24 hours in blocks
(define-data-var recovery-address (optional principal) none)
(define-data-var recovery-initiated-block (optional uint) none)

;; Data Maps
(define-map guardians principal bool)
(define-map guardian-count principal uint)
(define-map asset-balances {owner: principal, asset-type: (string-ascii 20)} uint)
(define-map pending-transactions 
  uint 
  {
    initiator: principal,
    recipient: principal,
    amount: uint,
    asset-type: (string-ascii 20),
    signatures: (list 10 principal),
    signature-count: uint,
    expiry-block: uint,
    executed: bool
  }
)
(define-map transaction-signatures {tx-id: uint, guardian: principal} bool)

;; Delegation Maps
(define-map delegations
  uint
  {
    delegator: principal,
    delegate: principal,
    asset-type: (string-ascii 20),
    max-amount: uint,
    expiry-block: uint,
    active: bool
  }
)
(define-map delegation-usage {delegation-id: uint} uint)
(define-map user-delegations {delegator: principal, delegate: principal, asset-type: (string-ascii 20)} uint)

;; Read-only functions
(define-read-only (get-guardian-status (guardian principal))
  (default-to false (map-get? guardians guardian))
)

(define-read-only (get-asset-balance (owner principal) (asset-type (string-ascii 20)))
  (default-to u0 (map-get? asset-balances {owner: owner, asset-type: asset-type}))
)

(define-read-only (get-transaction-details (tx-id uint))
  (map-get? pending-transactions tx-id)
)

(define-read-only (get-signature-threshold)
  (var-get signature-threshold)
)

(define-read-only (get-transaction-timeout)
  (var-get transaction-timeout)
)

(define-read-only (has-guardian-signed (tx-id uint) (guardian principal))
  (default-to false (map-get? transaction-signatures {tx-id: tx-id, guardian: guardian}))
)

(define-read-only (get-next-transaction-id)
  (var-get next-tx-id)
)

(define-read-only (get-recovery-address)
  (var-get recovery-address)
)

(define-read-only (get-recovery-status)
  (let ((initiated-block (var-get recovery-initiated-block)))
    (if (is-none initiated-block)
      {initiated: false, can-execute: false, blocks-remaining: u0}
      (let ((blocks-since-init (- stacks-block-height (unwrap-panic initiated-block)))
            (can-execute (and 
                          (>= blocks-since-init RECOVERY_DELAY_BLOCKS)
                          (<= blocks-since-init (+ RECOVERY_DELAY_BLOCKS RECOVERY_WINDOW_BLOCKS)))))
        {
          initiated: true, 
          can-execute: can-execute,
          blocks-remaining: (if (< blocks-since-init RECOVERY_DELAY_BLOCKS)
                             (- RECOVERY_DELAY_BLOCKS blocks-since-init)
                             u0)
        })
    )
  )
)

;; Delegation read-only functions
(define-read-only (get-delegation-details (delegation-id uint))
  (map-get? delegations delegation-id)
)

(define-read-only (get-delegation-usage (delegation-id uint))
  (default-to u0 (map-get? delegation-usage {delegation-id: delegation-id}))
)

(define-read-only (get-active-delegation (delegator principal) (delegate principal) (asset-type (string-ascii 20)))
  (let ((delegation-id (map-get? user-delegations {delegator: delegator, delegate: delegate, asset-type: asset-type})))
    (match delegation-id
      id (let ((delegation (map-get? delegations id)))
           (match delegation
             del (if (and (get active del) (< stacks-block-height (get expiry-block del)))
                    (some del)
                    none)
             none))
      none)
  )
)

(define-read-only (get-delegation-remaining-amount (delegation-id uint))
  (match (get-delegation-details delegation-id)
    delegation (let ((used-amount (get-delegation-usage delegation-id))
                     (max-amount (get max-amount delegation)))
                 (if (> max-amount used-amount)
                    (- max-amount used-amount)
                    u0))
    u0)
)

;; Private functions
(define-private (is-valid-amount (amount uint))
  (> amount u0)
)

(define-private (is-valid-recipient (recipient principal))
  (not (is-eq recipient tx-sender))
)

(define-private (is-transaction-expired (expiry-block uint))
  (> stacks-block-height expiry-block)
)

(define-private (is-valid-asset-type (asset-type (string-ascii 20)))
  (and 
    (> (len asset-type) u0)
    (<= (len asset-type) u20)
  )
)

(define-private (increment-tx-id)
  (let ((current-id (var-get next-tx-id)))
    (var-set next-tx-id (+ current-id u1))
    current-id
  )
)

(define-private (increment-delegation-id)
  (let ((current-id (var-get next-delegation-id)))
    (var-set next-delegation-id (+ current-id u1))
    current-id
  )
)

(define-private (is-recovery-window-active)
  (match (var-get recovery-initiated-block)
    initiated-block (let ((blocks-elapsed (- stacks-block-height initiated-block)))
                     (and 
                       (>= blocks-elapsed RECOVERY_DELAY_BLOCKS)
                       (<= blocks-elapsed (+ RECOVERY_DELAY_BLOCKS RECOVERY_WINDOW_BLOCKS))))
    false
  )
)

(define-private (is-valid-delegation-duration (expiry-block uint))
  (let ((duration (- expiry-block stacks-block-height)))
    (and 
      (>= duration MIN_DELEGATION_DURATION)
      (<= duration MAX_DELEGATION_DURATION)
      (> expiry-block stacks-block-height)
    )
  )
)

(define-private (has-permission-for-asset (user principal) (owner principal) (asset-type (string-ascii 20)) (amount uint))
  (or 
    (is-eq user owner)
    (match (get-active-delegation owner user asset-type)
      delegation (let ((delegation-id (unwrap-panic (map-get? user-delegations {delegator: owner, delegate: user, asset-type: asset-type})))
                       (used-amount (get-delegation-usage delegation-id))
                       (max-amount (get max-amount delegation)))
                   (>= (- max-amount used-amount) amount))
      false)
  )
)

;; Public functions
(define-public (add-guardian (new-guardian principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (get-guardian-status new-guardian)) ERR_INVALID_GUARDIAN)
    (map-set guardians new-guardian true)
    (ok true)
  )
)

(define-public (remove-guardian (guardian principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (get-guardian-status guardian) ERR_INVALID_GUARDIAN)
    (map-delete guardians guardian)
    (ok true)
  )
)

(define-public (set-signature-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (and (> new-threshold u0) (<= new-threshold u10)) ERR_INVALID_THRESHOLD)
    (var-set signature-threshold new-threshold)
    (ok true)
  )
)

(define-public (set-recovery-address (new-recovery-address principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq new-recovery-address CONTRACT_OWNER)) ERR_INVALID_RECOVERY_ADDRESS)
    (var-set recovery-address (some new-recovery-address))
    (ok true)
  )
)

(define-public (initiate-emergency-recovery)
  (let ((recovery-addr (unwrap! (var-get recovery-address) ERR_INVALID_RECOVERY_ADDRESS)))
    (asserts! (is-eq tx-sender recovery-addr) ERR_UNAUTHORIZED)
    (asserts! (is-none (var-get recovery-initiated-block)) ERR_RECOVERY_ALREADY_INITIATED)
    (var-set recovery-initiated-block (some stacks-block-height))
    (ok stacks-block-height)
  )
)

(define-public (cancel-emergency-recovery)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (var-get recovery-initiated-block)) ERR_RECOVERY_NOT_INITIATED)
    (var-set recovery-initiated-block none)
    (ok true)
  )
)

(define-public (execute-emergency-recovery (new-owner principal))
  (let ((recovery-addr (unwrap! (var-get recovery-address) ERR_INVALID_RECOVERY_ADDRESS))
        (initiated-block (unwrap! (var-get recovery-initiated-block) ERR_RECOVERY_NOT_INITIATED)))
    (asserts! (is-eq tx-sender recovery-addr) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq new-owner recovery-addr)) ERR_INVALID_RECOVERY_ADDRESS)
    (asserts! (is-recovery-window-active) ERR_RECOVERY_TOO_EARLY)
    
    ;; Clear all existing guardians
    (map-delete guardians CONTRACT_OWNER)
    
    ;; Set new owner as guardian
    (map-set guardians new-owner true)
    
    ;; Reset recovery state
    (var-set recovery-initiated-block none)
    (var-set recovery-address none)
    
    (ok new-owner)
  )
)

;; Delegation functions
(define-public (create-delegation (delegate principal) (asset-type (string-ascii 20)) (max-amount uint) (expiry-block uint))
  (let ((delegation-id (increment-delegation-id))
        (current-balance (get-asset-balance tx-sender asset-type)))
    (asserts! (is-valid-amount max-amount) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-asset-type asset-type) ERR_INVALID_ASSET_TYPE)
    (asserts! (not (is-eq delegate tx-sender)) ERR_INVALID_DELEGATE)
    (asserts! (is-valid-delegation-duration expiry-block) ERR_INVALID_EXPIRY)
    (asserts! (>= current-balance max-amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (is-none (get-active-delegation tx-sender delegate asset-type)) ERR_DELEGATION_EXISTS)
    
    (map-set delegations delegation-id {
      delegator: tx-sender,
      delegate: delegate,
      asset-type: asset-type,
      max-amount: max-amount,
      expiry-block: expiry-block,
      active: true
    })
    
    (map-set delegation-usage {delegation-id: delegation-id} u0)
    (map-set user-delegations {delegator: tx-sender, delegate: delegate, asset-type: asset-type} delegation-id)
    
    (ok delegation-id)
  )
)

(define-public (revoke-delegation (delegate principal) (asset-type (string-ascii 20)))
  (let ((delegation-id (unwrap! (map-get? user-delegations {delegator: tx-sender, delegate: delegate, asset-type: asset-type}) ERR_DELEGATION_NOT_FOUND))
        (delegation (unwrap! (get-delegation-details delegation-id) ERR_DELEGATION_NOT_FOUND)))
    (asserts! (is-valid-asset-type asset-type) ERR_INVALID_ASSET_TYPE)
    (asserts! (not (is-eq delegate tx-sender)) ERR_INVALID_DELEGATE)
    (asserts! (is-eq tx-sender (get delegator delegation)) ERR_UNAUTHORIZED)
    (asserts! (get active delegation) ERR_DELEGATION_NOT_FOUND)
    
    (map-set delegations delegation-id (merge delegation {active: false}))
    (map-delete user-delegations {delegator: tx-sender, delegate: delegate, asset-type: asset-type})
    
    (ok true)
  )
)

(define-public (use-delegation (delegator principal) (recipient principal) (amount uint) (asset-type (string-ascii 20)))
  (let ((delegation (unwrap! (get-active-delegation delegator tx-sender asset-type) ERR_DELEGATION_NOT_FOUND))
        (delegation-id (unwrap! (map-get? user-delegations {delegator: delegator, delegate: tx-sender, asset-type: asset-type}) ERR_DELEGATION_NOT_FOUND))
        (used-amount (get-delegation-usage delegation-id))
        (delegator-balance (get-asset-balance delegator asset-type))
        (recipient-balance (get-asset-balance recipient asset-type)))
    
    (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-asset-type asset-type) ERR_INVALID_ASSET_TYPE)
    (asserts! (not (is-eq recipient tx-sender)) ERR_INVALID_RECIPIENT)
    (asserts! (not (is-eq recipient delegator)) ERR_INVALID_RECIPIENT)
    (asserts! (>= delegator-balance amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (>= (- (get max-amount delegation) used-amount) amount) ERR_DELEGATION_LIMIT_EXCEEDED)
    (asserts! (< stacks-block-height (get expiry-block delegation)) ERR_DELEGATION_EXPIRED)
    
    ;; Update balances
    (map-set asset-balances {owner: delegator, asset-type: asset-type} (- delegator-balance amount))
    (map-set asset-balances {owner: recipient, asset-type: asset-type} (+ recipient-balance amount))
    
    ;; Update delegation usage
    (map-set delegation-usage {delegation-id: delegation-id} (+ used-amount amount))
    
    (ok true)
  )
)

(define-public (deposit-asset (amount uint) (asset-type (string-ascii 20)))
  (let (
    (current-balance (get-asset-balance tx-sender asset-type))
    (new-balance (+ current-balance amount))
  )
    (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-asset-type asset-type) ERR_INVALID_ASSET_TYPE)
    (map-set asset-balances {owner: tx-sender, asset-type: asset-type} new-balance)
    (ok new-balance)
  )
)

(define-public (initiate-transfer (recipient principal) (amount uint) (asset-type (string-ascii 20)))
  (let (
    (current-balance (get-asset-balance tx-sender asset-type))
    (tx-id (increment-tx-id))
    (expiry-block (+ stacks-block-height (var-get transaction-timeout)))
  )
    (asserts! (get-guardian-status tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-recipient recipient) ERR_INVALID_RECIPIENT)
    (asserts! (is-valid-asset-type asset-type) ERR_INVALID_ASSET_TYPE)
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
    
    (map-set pending-transactions tx-id {
      initiator: tx-sender,
      recipient: recipient,
      amount: amount,
      asset-type: asset-type,
      signatures: (list),
      signature-count: u0,
      expiry-block: expiry-block,
      executed: false
    })
    
    (ok tx-id)
  )
)

(define-public (sign-transaction (tx-id uint))
  (let (
    (tx-details (unwrap! (get-transaction-details tx-id) ERR_TRANSACTION_NOT_FOUND))
    (current-signatures (get signature-count tx-details))
    (has-signed (has-guardian-signed tx-id tx-sender))
  )
    (asserts! (get-guardian-status tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not has-signed) ERR_ALREADY_SIGNED)
    (asserts! (not (is-transaction-expired (get expiry-block tx-details))) ERR_TRANSACTION_EXPIRED)
    (asserts! (not (get executed tx-details)) ERR_TRANSACTION_NOT_FOUND)
    
    (map-set transaction-signatures {tx-id: tx-id, guardian: tx-sender} true)
    (map-set pending-transactions tx-id 
      (merge tx-details {
        signatures: (unwrap! (as-max-len? (append (get signatures tx-details) tx-sender) u10) ERR_INVALID_GUARDIAN),
        signature-count: (+ current-signatures u1)
      })
    )
    
    (ok true)
  )
)

(define-public (execute-transaction (tx-id uint))
  (let (
    (tx-details (unwrap! (get-transaction-details tx-id) ERR_TRANSACTION_NOT_FOUND))
    (initiator (get initiator tx-details))
    (recipient (get recipient tx-details))
    (amount (get amount tx-details))
    (asset-type (get asset-type tx-details))
    (current-balance (get-asset-balance initiator asset-type))
    (recipient-balance (get-asset-balance recipient asset-type))
  )
    (asserts! (get-guardian-status tx-sender) ERR_UNAUTHORIZED)
    (asserts! (>= (get signature-count tx-details) (var-get signature-threshold)) ERR_INSUFFICIENT_SIGNATURES)
    (asserts! (not (is-transaction-expired (get expiry-block tx-details))) ERR_TRANSACTION_EXPIRED)
    (asserts! (not (get executed tx-details)) ERR_TRANSACTION_NOT_FOUND)
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
    
    ;; Update balances
    (map-set asset-balances {owner: initiator, asset-type: asset-type} (- current-balance amount))
    (map-set asset-balances {owner: recipient, asset-type: asset-type} (+ recipient-balance amount))
    
    ;; Mark transaction as executed
    (map-set pending-transactions tx-id (merge tx-details {executed: true}))
    
    (ok true)
  )
)

(define-public (withdraw-asset (amount uint) (asset-type (string-ascii 20)))
  (let (
    (current-balance (get-asset-balance tx-sender asset-type))
    (new-balance (- current-balance amount))
  )
    (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-asset-type asset-type) ERR_INVALID_ASSET_TYPE)
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
    (map-set asset-balances {owner: tx-sender, asset-type: asset-type} new-balance)
    (ok new-balance)
  )
)

;; Initialize contract
(begin
  (map-set guardians CONTRACT_OWNER true)
)