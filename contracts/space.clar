;; Space Station Command Center Smart Contract
;; Controls space station modules and crew authorization system

;; Define trait for station modules
(define-trait station-module-trait
    (
        (run-operation ((list 128 uint)) (response bool uint))
    )
)

;; Constants
(define-constant station-commander tx-sender)
(define-constant empty-space 'ST000000000000000000002AMW42H)
(define-constant err-commander-only (err u300))
(define-constant err-station-offline (err u301))
(define-constant err-station-online (err u302))
(define-constant err-invalid-coordinates (err u303))
(define-constant err-crew-unauthorized (err u304))
(define-constant err-operation-restricted (err u305))
(define-constant err-mission-log-error (err u306))
(define-constant err-invalid-crew-member (err u307))
(define-constant err-invalid-operation-code (err u308))
(define-constant err-invalid-station-module (err u309))

;; Data Variables
(define-data-var primary-module principal empty-space)
(define-data-var station-operational bool false)

;; Data Maps
(define-map crew-roster principal bool)
(define-map operation-clearance (string-ascii 64) bool)
(define-map mission-logs principal uint)

;; Read-only functions
(define-read-only (get-primary-module)
    (ok (var-get primary-module))
)

(define-read-only (is-crew-authorized (crew-member principal))
    (default-to false (map-get? crew-roster crew-member))
)

(define-read-only (is-operation-cleared (operation-code (string-ascii 64)))
    (default-to false (map-get? operation-clearance operation-code))
)

(define-read-only (get-mission-count (crew-member principal))
    (default-to u0 (map-get? mission-logs crew-member))
)

;; Private functions
(define-private (assert-station-commander)
    (if (is-eq tx-sender station-commander)
        (ok true)
        err-commander-only
    )
)

(define-private (assert-station-operational)
    (if (var-get station-operational)
        (ok true)
        err-station-offline
    )
)

(define-private (is-valid-crew-member (crew-member principal)) 
    (and
        (not (is-eq crew-member station-commander))
        (not (is-eq crew-member empty-space))
    )
)

(define-private (is-valid-operation-code (operation-code (string-ascii 64)))
    (and 
        (> (len operation-code) u0)
        (< (len operation-code) u64)
    )
)

(define-private (is-valid-station-module (module <station-module-trait>))
    (let ((module-principal (contract-of module)))
        (and
            (not (is-eq module-principal empty-space))
            (not (is-eq module-principal (as-contract tx-sender)))
        )
    )
)

(define-private (update-mission-logs (crew-member principal))
    (begin
        (map-set mission-logs 
            crew-member 
            (+ (get-mission-count crew-member) u1)
        )
        true
    )
)

;; Public functions
(define-public (boot-station (initial-module principal))
    (begin
        (asserts! (not (var-get station-operational)) err-station-online)
        (asserts! (not (is-eq initial-module empty-space)) err-invalid-coordinates)
        (var-set primary-module initial-module)
        (var-set station-operational true)
        (ok true)
    )
)

(define-public (swap-primary-module (new-module principal))
    (begin
        (try! (assert-station-commander))
        (try! (assert-station-operational))
        (asserts! (not (is-eq new-module empty-space)) err-invalid-coordinates)
        (var-set primary-module new-module)
        (ok true)
    )
)

(define-public (update-crew-roster (crew-member principal) (authorized bool))
    (begin
        (try! (assert-station-commander))
        (asserts! (is-valid-crew-member crew-member) err-invalid-crew-member)
        (let
            ((safe-crew-member crew-member)
             (safe-authorization authorized))
            (map-set crew-roster safe-crew-member safe-authorization)
            (ok true)
        )
    )
)

(define-public (set-operation-clearance (operation-code (string-ascii 64)) (cleared bool))
    (begin
        (try! (assert-station-commander))
        (asserts! (is-valid-operation-code operation-code) err-invalid-operation-code)
        (let
            ((safe-operation-code operation-code)
             (safe-clearance cleared))
            (map-set operation-clearance safe-operation-code safe-clearance)
            (ok true)
        )
    )
)

(define-public (initiate-operation (module <station-module-trait>) (operation-code (string-ascii 64)) (parameters (list 128 uint)))
    (begin
        (try! (assert-station-operational))
        (asserts! (is-valid-station-module module) err-invalid-station-module)
        (asserts! (is-crew-authorized tx-sender) err-crew-unauthorized)
        (asserts! (is-operation-cleared operation-code) err-operation-restricted)
        
        (asserts! (update-mission-logs tx-sender) err-mission-log-error)
        
        (contract-call? module run-operation parameters)
    )
)

;; Fallback function
(define-public (dock-at-station)
    (begin
        (try! (assert-station-operational))
        (ok true)
    )
)

;; Emergency functions
(define-public (shutdown-station)
    (begin
        (try! (assert-station-commander))
        (var-set station-operational false)
        (ok true)
    )
)

(define-public (restart-station)
    (begin
        (try! (assert-station-commander))
        (var-set station-operational true)
        (ok true)
    )
)