(define-constant err-unauthorized (err u100))
(define-constant err-invalid-args (err u101))
(define-constant err-overflow (err u102))

(define-data-var counter uint u0)
(define-data-var name (string-ascii 256) "")
(define-data-var total-increments uint u0)
(define-data-var multiplier uint u1)
(define-data-var max-value uint u1000000)
(define-data-var is-paused bool false)
(define-data-var owner principal tx-sender)

(define-map milestones uint { name: (string-ascii 64), reward-multiplier: uint, unlock-feature: (string-ascii 32) })
(define-map achieved-milestones uint bool)
(define-data-var next-milestone-id uint u1)
(define-data-var total-milestones-achieved uint u0)

(define-map user-cooldowns principal uint)
(define-map scheduled-operations uint { operation: (string-ascii 32), target-block: uint, amount: uint, requester: principal })
(define-data-var global-cooldown-period uint u10)
(define-data-var next-scheduled-id uint u1)
(define-data-var time-lock-enabled bool false)
(define-data-var time-lock-duration uint u144)

(define-read-only (get-counter)
    (var-get counter)
)

(define-read-only (get-name)
    (var-get name)
)

(define-read-only (get-total-increments)
    (var-get total-increments)
)

(define-read-only (get-multiplier)
    (let ((mult (var-get multiplier)))
        (if (> mult u0) mult u1)
    )
)

(define-read-only (get-max-value)
    (let ((max-val (var-get max-value)))
        (if (> max-val u0) max-val u1000000)
    )
)

(define-read-only (get-is-paused)
    (var-get is-paused)
)

(define-read-only (get-owner)
    (var-get owner)
)

(define-read-only (get-version)
    "2.0.0"
)

(define-private (is-authorized)
    (is-eq tx-sender (var-get owner))
)

(define-public (set-owner (new-owner principal))
    (begin
        (asserts! (is-authorized) err-unauthorized)
        (var-set owner new-owner)
        (print { event: "owner-changed", old-owner: (var-get owner), new-owner: new-owner })
        (ok new-owner)
    )
)

(define-public (increment)
    (let ((current-value (get-counter))
          (current-increments (get-total-increments))
          (current-multiplier (get-multiplier))
          (current-max-value (get-max-value))
          (new-value (+ current-value current-multiplier)))
        (asserts! (not (get-is-paused)) err-unauthorized)
        (asserts! (<= new-value current-max-value) err-overflow)
        (var-set counter new-value)
        (var-set total-increments (+ current-increments u1))
        (check-and-trigger-milestones new-value)
        (print { event: "counter-incremented", old-value: current-value, new-value: new-value, multiplier: current-multiplier })
        (ok new-value)
    )
)

(define-public (decrement)
    (let ((current-value (get-counter))
          (current-multiplier (get-multiplier)))
        (asserts! (not (get-is-paused)) err-unauthorized)
        (asserts! (>= current-value current-multiplier) err-invalid-args)
        (var-set counter (- current-value current-multiplier))
        (print { event: "counter-decremented", old-value: current-value, new-value: (- current-value current-multiplier), multiplier: current-multiplier })
        (ok (- current-value current-multiplier))
    )
)

(define-public (reset)
    (begin
        (asserts! (not (get-is-paused)) err-unauthorized)
        (var-set counter u0)
        (print { event: "counter-reset", value: u0 })
        (ok u0)
    )
)

(define-public (set-name (new-name (string-ascii 256)))
    (begin
        (asserts! (not (get-is-paused)) err-unauthorized)
        (var-set name new-name)
        (print { event: "name-updated", new-name: new-name })
        (ok new-name)
    )
)

(define-public (add-to-counter (amount uint))
    (let ((current-value (get-counter))
          (current-increments (get-total-increments))
          (current-max-value (get-max-value))
          (new-value (+ current-value amount)))
        (asserts! (not (get-is-paused)) err-unauthorized)
        (asserts! (<= new-value current-max-value) err-overflow)
        (var-set counter new-value)
        (var-set total-increments (+ current-increments u1))
        (check-and-trigger-milestones new-value)
        (print { event: "counter-increased", amount: amount, old-value: current-value, new-value: new-value })
        (ok new-value)
    )
)

(define-public (set-multiplier (new-multiplier uint))
    (begin
        (asserts! (is-authorized) err-unauthorized)
        (asserts! (> new-multiplier u0) err-invalid-args)
        (var-set multiplier new-multiplier)
        (print { event: "multiplier-updated", new-multiplier: new-multiplier })
        (ok new-multiplier)
    )
)

(define-public (set-max-value (new-max-value uint))
    (begin
        (asserts! (is-authorized) err-unauthorized)
        (asserts! (> new-max-value u0) err-invalid-args)
        (var-set max-value new-max-value)
        (print { event: "max-value-updated", new-max-value: new-max-value })
        (ok new-max-value)
    )
)

(define-public (pause)
    (begin
        (asserts! (is-authorized) err-unauthorized)
        (var-set is-paused true)
        (print { event: "contract-paused" })
        (ok true)
    )
)

(define-public (unpause)
    (begin
        (asserts! (is-authorized) err-unauthorized)
        (var-set is-paused false)
        (print { event: "contract-unpaused" })
        (ok true)
    )
)

(define-public (multiply-counter (factor uint))
    (let ((current-value (get-counter))
          (current-max-value (get-max-value)))
        (asserts! (not (get-is-paused)) err-unauthorized)
        (asserts! (> factor u0) err-invalid-args)
        (asserts! (<= (* current-value factor) current-max-value) err-overflow)
        (var-set counter (* current-value factor))
        (print { event: "counter-multiplied", factor: factor, old-value: current-value, new-value: (* current-value factor) })
        (ok (* current-value factor))
    )
)

(define-public (divide-counter (divisor uint))
    (let ((current-value (get-counter)))
        (asserts! (not (get-is-paused)) err-unauthorized)
        (asserts! (> divisor u0) err-invalid-args)
        (var-set counter (/ current-value divisor))
        (print { event: "counter-divided", divisor: divisor, old-value: current-value, new-value: (/ current-value divisor) })
        (ok (/ current-value divisor))
    )
)

(define-public (square-counter)
    (let ((current-value (get-counter))
          (current-max-value (get-max-value)))
        (asserts! (not (get-is-paused)) err-unauthorized)
        (asserts! (<= (* current-value current-value) current-max-value) err-overflow)
        (var-set counter (* current-value current-value))
        (print { event: "counter-squared", old-value: current-value, new-value: (* current-value current-value) })
        (ok (* current-value current-value))
    )
)

(define-public (power-counter (exponent uint))
    (let ((current-value (get-counter))
          (current-max-value (get-max-value)))
        (asserts! (not (get-is-paused)) err-unauthorized)
        (asserts! (> exponent u0) err-invalid-args)
        (asserts! (<= (pow current-value exponent) current-max-value) err-overflow)
        (var-set counter (pow current-value exponent))
        (print { event: "counter-powered", exponent: exponent, old-value: current-value, new-value: (pow current-value exponent) })
        (ok (pow current-value exponent))
    )
)

(define-public (batch-increment (times uint))
    (let ((current-value (get-counter))
          (current-multiplier (get-multiplier))
          (current-max-value (get-max-value))
          (total-increase (* times current-multiplier))
          (new-value (+ current-value total-increase)))
        (asserts! (not (get-is-paused)) err-unauthorized)
        (asserts! (> times u0) err-invalid-args)
        (asserts! (<= new-value current-max-value) err-overflow)
        (var-set counter new-value)
        (var-set total-increments (+ (get-total-increments) times))
        (check-and-trigger-milestones new-value)
        (print { event: "batch-increment", times: times, old-value: current-value, new-value: new-value })
        (ok new-value)
    )
)

(define-read-only (get-contract-info)
    {
        version: (get-version),
        counter: (get-counter),
        name: (get-name),
        total-increments: (get-total-increments),
        multiplier: (get-multiplier),
        max-value: (get-max-value),
        is-paused: (get-is-paused),
        owner: (get-owner),
        milestones-achieved: (get-total-milestones-achieved),
        next-milestone: (get-next-milestone),
        milestone-progress: (get-milestone-progress),
        current-block: stacks-block-height,
        global-cooldown: (var-get global-cooldown-period),
        time-lock-enabled: (var-get time-lock-enabled)
    }
)

(define-read-only (preview-increment)
    (let ((current-value (get-counter))
          (current-multiplier (get-multiplier)))
        (+ current-value current-multiplier)
    )
)

(define-read-only (preview-multiply (factor uint))
    (let ((current-value (get-counter)))
        (* current-value factor)
    )
)

(define-read-only (get-progress-percentage)
    (let ((current-value (get-counter))
          (current-max-value (get-max-value)))
        (/ (* current-value u100) current-max-value)
    )
)

(define-read-only (can-increment)
    (let ((current-value (get-counter))
          (current-multiplier (get-multiplier))
          (current-max-value (get-max-value)))
        (and (not (get-is-paused)) (<= (+ current-value current-multiplier) current-max-value))
    )
)

(define-read-only (remaining-capacity)
    (let ((current-value (get-counter))
          (current-max-value (get-max-value)))
        (- current-max-value current-value)
    )
)

(define-public (create-milestone (target-value uint) (milestone-name (string-ascii 64)) (reward-mult uint) (unlock-feat (string-ascii 32)))
    (let ((milestone-id (var-get next-milestone-id)))
        (asserts! (is-authorized) err-unauthorized)
        (asserts! (> target-value u0) err-invalid-args)
        (asserts! (> reward-mult u0) err-invalid-args)
        (map-set milestones target-value { 
            name: milestone-name, 
            reward-multiplier: reward-mult, 
            unlock-feature: unlock-feat 
        })
        (var-set next-milestone-id (+ milestone-id u1))
        (print { event: "milestone-created", target: target-value, name: milestone-name, reward: reward-mult })
        (ok target-value)
    )
)

(define-public (remove-milestone (target-value uint))
    (begin
        (asserts! (is-authorized) err-unauthorized)
        (map-delete milestones target-value)
        (map-delete achieved-milestones target-value)
        (print { event: "milestone-removed", target: target-value })
        (ok target-value)
    )
)

(define-private (check-and-trigger-milestones (new-value uint))
    (let ((milestone-data (map-get? milestones new-value)))
        (match milestone-data
            milestone-info (if (not (default-to false (map-get? achieved-milestones new-value)))
                (begin
                    (map-set achieved-milestones new-value true)
                    (var-set total-milestones-achieved (+ (var-get total-milestones-achieved) u1))
                    (var-set multiplier (get reward-multiplier milestone-info))
                    (print { 
                        event: "milestone-achieved", 
                        target: new-value, 
                        name: (get name milestone-info),
                        reward-multiplier: (get reward-multiplier milestone-info),
                        unlock-feature: (get unlock-feature milestone-info)
                    })
                    true
                )
                false
            )
            false
        )
    )
)

(define-read-only (get-milestone (target-value uint))
    (map-get? milestones target-value)
)

(define-read-only (is-milestone-achieved (target-value uint))
    (default-to false (map-get? achieved-milestones target-value))
)

(define-read-only (get-total-milestones-achieved)
    (var-get total-milestones-achieved)
)

(define-read-only (get-next-milestone)
    (let ((current-value (get-counter)))
        (fold find-next-milestone (list u1 u10 u25 u50 u100 u250 u500 u1000 u2500 u5000 u10000) none)
    )
)

(define-private (find-next-milestone (target uint) (current-best (optional uint)))
    (if (and (> target (get-counter)) (is-some (get-milestone target)) (not (is-milestone-achieved target)))
        (match current-best
            best (if (< target best) (some target) current-best)
            (some target)
        )
        current-best
    )
)

(define-read-only (get-milestone-progress)
    (let ((current-value (get-counter))
          (next-milestone (get-next-milestone)))
        (match next-milestone
            target (/ (* current-value u100) target)
            u100
        )
    )
)

(define-read-only (get-achievements-summary)
    {
        total-achieved: (get-total-milestones-achieved),
        current-counter: (get-counter),
        next-milestone: (get-next-milestone),
        progress-percentage: (get-milestone-progress)
    }
)

(define-private (check-cooldown (user principal))
    (let ((last-operation (default-to u0 (map-get? user-cooldowns user)))
          (current-block stacks-block-height)
          (cooldown-period (var-get global-cooldown-period)))
        (>= current-block (+ last-operation cooldown-period))
    )
)

(define-private (update-cooldown (user principal))
    (map-set user-cooldowns user stacks-block-height)
)

(define-public (set-cooldown-period (new-period uint))
    (begin
        (asserts! (is-authorized) err-unauthorized)
        (asserts! (> new-period u0) err-invalid-args)
        (var-set global-cooldown-period new-period)
        (print { event: "cooldown-period-updated", new-period: new-period })
        (ok new-period)
    )
)

(define-public (set-time-lock (enabled bool) (duration uint))
    (begin
        (asserts! (is-authorized) err-unauthorized)
        (var-set time-lock-enabled enabled)
        (var-set time-lock-duration duration)
        (print { event: "time-lock-updated", enabled: enabled, duration: duration })
        (ok enabled)
    )
)

(define-public (schedule-operation (operation (string-ascii 32)) (delay-blocks uint) (amount uint))
    (let ((schedule-id (var-get next-scheduled-id))
          (target-block (+ stacks-block-height delay-blocks)))
        (asserts! (check-cooldown tx-sender) err-unauthorized)
        (asserts! (> delay-blocks u0) err-invalid-args)
        (map-set scheduled-operations schedule-id {
            operation: operation,
            target-block: target-block,
            amount: amount,
            requester: tx-sender
        })
        (var-set next-scheduled-id (+ schedule-id u1))
        (update-cooldown tx-sender)
        (print { event: "operation-scheduled", id: schedule-id, operation: operation, target-block: target-block })
        (ok schedule-id)
    )
)

(define-public (execute-scheduled-operation (schedule-id uint))
    (let ((operation-data (unwrap! (map-get? scheduled-operations schedule-id) err-invalid-args)))
        (asserts! (>= stacks-block-height (get target-block operation-data)) err-unauthorized)
        (asserts! (is-eq tx-sender (get requester operation-data)) err-unauthorized)
        (map-delete scheduled-operations schedule-id)
        (if (is-eq (get operation operation-data) "increment")
            (begin
                (try! (increment))
                (ok "increment-executed")
            )
            (if (is-eq (get operation operation-data) "add")
                (begin
                    (try! (add-to-counter (get amount operation-data)))
                    (ok "add-executed")
                )
                (if (is-eq (get operation operation-data) "reset")
                    (begin
                        (try! (reset))
                        (ok "reset-executed")
                    )
                    err-invalid-args
                )
            )
        )
    )
)

(define-public (cancel-scheduled-operation (schedule-id uint))
    (let ((operation-data (unwrap! (map-get? scheduled-operations schedule-id) err-invalid-args)))
        (asserts! (is-eq tx-sender (get requester operation-data)) err-unauthorized)
        (map-delete scheduled-operations schedule-id)
        (print { event: "operation-cancelled", id: schedule-id })
        (ok schedule-id)
    )
)

(define-public (increment-with-cooldown)
    (begin
        (asserts! (check-cooldown tx-sender) err-unauthorized)
        (try! (increment))
        (update-cooldown tx-sender)
        (ok (get-counter))
    )
)

(define-public (add-with-cooldown (amount uint))
    (begin
        (asserts! (check-cooldown tx-sender) err-unauthorized)
        (try! (add-to-counter amount))
        (update-cooldown tx-sender)
        (ok (get-counter))
    )
)

(define-public (time-locked-reset)
    (let ((time-lock-active (var-get time-lock-enabled))
          (lock-duration (var-get time-lock-duration)))
        (asserts! (is-authorized) err-unauthorized)
        (if time-lock-active
            (try! (schedule-operation "reset" lock-duration u0))
            (try! (reset))
        )
        (print { event: "time-locked-reset-initiated", time-lock-active: time-lock-active })
        (ok time-lock-active)
    )
)

(define-read-only (get-cooldown-status (user principal))
    (let ((last-operation (default-to u0 (map-get? user-cooldowns user)))
          (current-block stacks-block-height)
          (cooldown-period (var-get global-cooldown-period)))
        {
            last-operation-block: last-operation,
            current-block: current-block,
            cooldown-period: cooldown-period,
            blocks-remaining: (if (> (+ last-operation cooldown-period) current-block)
                                 (- (+ last-operation cooldown-period) current-block)
                                 u0),
            can-operate: (check-cooldown user)
        }
    )
)

(define-read-only (get-scheduled-operation (schedule-id uint))
    (map-get? scheduled-operations schedule-id)
)

(define-read-only (get-time-lock-settings)
    {
        enabled: (var-get time-lock-enabled),
        duration: (var-get time-lock-duration),
        cooldown-period: (var-get global-cooldown-period)
    }
)

(define-read-only (get-operation-timing-info)
    {
        current-block: stacks-block-height,
        global-cooldown: (var-get global-cooldown-period),
        time-lock-enabled: (var-get time-lock-enabled),
        time-lock-duration: (var-get time-lock-duration),
        next-scheduled-id: (var-get next-scheduled-id)
    }
)
