;; Nexus Guardian - Secure Digital Asset Management
;; A comprehensive smart contract for secure asset management with multi-signature capabilities

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

;; Data Variables
(define-data-var next-tx-id uint u0)
(define-data-var signature-threshold uint u2)
(define-data-var transaction-timeout uint u144) ;; ~24 hours in blocks

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