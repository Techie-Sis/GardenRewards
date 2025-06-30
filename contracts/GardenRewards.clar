;; Constants
(define-constant GARDEN_CAPACITY u1800000)
(define-constant BASE_HARVEST_REWARD u22)
(define-constant CULTIVATION_BONUS u8)
(define-constant MAX_GARDENING_LEVEL u12)
(define-constant ERR_INVALID_GARDEN_ACTIVITY u1)
(define-constant ERR_NO_HARVEST_TOKENS u2)
(define-constant ERR_GARDEN_CAPACITY_EXCEEDED u3)
(define-constant BLOCKS_PER_GROWING_SEASON u1728)
(define-constant SEED_PRESERVATION_MULTIPLIER u4)
(define-constant MIN_PRESERVATION_PERIOD u864)
(define-constant EARLY_HARVEST_PENALTY u15)

;; Data Variables
(define-data-var total-harvest-tokens-distributed uint u0)
(define-data-var total-garden-activities uint u0)
(define-data-var garden-supervisor principal tx-sender)

;; Data Maps
(define-map gardener-activities principal uint)
(define-map gardener-harvest-tokens principal uint)
(define-map garden-activity-start-time principal uint)
(define-map gardener-cultivation-level principal uint)
(define-map gardener-last-activity principal uint)
(define-map gardener-preserved-seeds principal uint)
(define-map gardener-preservation-start-block principal uint)

;; Public Functions
(define-public (start-garden-activity (cultivation-effort uint))
  (let
    (
      (gardener tx-sender)
    )
    (asserts! (> cultivation-effort u0) (err ERR_INVALID_GARDEN_ACTIVITY))
    (map-set garden-activity-start-time gardener burn-block-height)
    (ok true)
  )
)

(define-public (complete-garden-harvest (cultivation-effort uint))
  (let
    (
      (gardener tx-sender)
      (start-block (default-to u0 (map-get? garden-activity-start-time gardener)))
      (blocks-cultivating (- burn-block-height start-block))
      (last-activity-block (default-to u0 (map-get? gardener-last-activity gardener)))
      (cultivation-level (default-to u0 (map-get? gardener-cultivation-level gardener)))
      (capped-cultivation (if (<= cultivation-level MAX_GARDENING_LEVEL) cultivation-level MAX_GARDENING_LEVEL))
      (harvest-reward (+ BASE_HARVEST_REWARD (* capped-cultivation CULTIVATION_BONUS)))
    )
    (asserts! (and (> start-block u0) (>= blocks-cultivating cultivation-effort)) (err ERR_INVALID_GARDEN_ACTIVITY))
    
    (map-set gardener-activities gardener (+ (default-to u0 (map-get? gardener-activities gardener)) u1))
    (map-set gardener-harvest-tokens gardener (+ (default-to u0 (map-get? gardener-harvest-tokens gardener)) harvest-reward))
    
    (if (< (- burn-block-height last-activity-block) BLOCKS_PER_GROWING_SEASON)
      (map-set gardener-cultivation-level gardener (+ cultivation-level u1))
      (map-set gardener-cultivation-level gardener u1)
    )
    
    (map-set gardener-last-activity gardener burn-block-height)
    (var-set total-garden-activities (+ (var-get total-garden-activities) u1))
    (var-set total-harvest-tokens-distributed (+ (var-get total-harvest-tokens-distributed) harvest-reward))
    
    (asserts! (<= (var-get total-harvest-tokens-distributed) GARDEN_CAPACITY) (err ERR_GARDEN_CAPACITY_EXCEEDED))
    (ok harvest-reward)
  )
)

(define-public (claim-harvest-rewards)
  (let
    (
      (gardener tx-sender)
      (token-balance (default-to u0 (map-get? gardener-harvest-tokens gardener)))
    )
    (asserts! (> token-balance u0) (err ERR_NO_HARVEST_TOKENS))
    (map-set gardener-harvest-tokens gardener u0)
    (ok token-balance)
  )
)

;; Seed Preservation Features
(define-public (preserve-seeds (amount uint))
  (let
    (
      (gardener tx-sender)
    )
    (asserts! (> amount u0) (err ERR_INVALID_GARDEN_ACTIVITY))
    (asserts! (>= (var-get total-harvest-tokens-distributed) amount) (err ERR_GARDEN_CAPACITY_EXCEEDED))
    
    (map-set gardener-preserved-seeds gardener amount)
    (map-set gardener-preservation-start-block gardener burn-block-height)
    (var-set total-harvest-tokens-distributed (- (var-get total-harvest-tokens-distributed) amount))
    (ok amount)
  )
)

(define-public (release-preserved-seeds)
  (let
    (
      (gardener tx-sender)
      (preserved-amount (default-to u0 (map-get? gardener-preserved-seeds gardener)))
      (preservation-start-block (default-to u0 (map-get? gardener-preservation-start-block gardener)))
      (blocks-preserved (- burn-block-height preservation-start-block))
      (penalty (if (< blocks-preserved MIN_PRESERVATION_PERIOD) (/ (* preserved-amount EARLY_HARVEST_PENALTY) u100) u0))
      (final-amount (- preserved-amount penalty))
    )
    (asserts! (> preserved-amount u0) (err ERR_NO_HARVEST_TOKENS))
    
    (map-set gardener-preserved-seeds gardener u0)
    (map-set gardener-preservation-start-block gardener u0)
    (var-set total-harvest-tokens-distributed (+ (var-get total-harvest-tokens-distributed) final-amount))
    (ok final-amount)
  )
)

;; Read-Only Functions
(define-read-only (get-garden-activity-count (user principal))
  (default-to u0 (map-get? gardener-activities user))
)

(define-read-only (get-harvest-token-balance (user principal))
  (default-to u0 (map-get? gardener-harvest-tokens user))
)

(define-read-only (get-cultivation-level (user principal))
  (default-to u0 (map-get? gardener-cultivation-level user))
)

(define-read-only (get-garden-stats)
  {
    total-garden-activities: (var-get total-garden-activities),
    total-harvest-tokens-distributed: (var-get total-harvest-tokens-distributed)
  }
)

;; Private Functions
(define-private (is-garden-supervisor)
  (is-eq tx-sender (var-get garden-supervisor))
)