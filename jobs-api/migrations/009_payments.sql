-- Course fee payments made in the app through Razorpay Checkout (orders API).
-- One row per Razorpay order. Amounts are in paise. The student's registration in Firestore is updated when paid.
CREATE TABLE payments (
  order_id    VARCHAR(40)  NOT NULL,
  uid         VARCHAR(128) NOT NULL,
  email       VARCHAR(254) NULL,
  plan        VARCHAR(20)  NOT NULL,
  amount      INT          NOT NULL,
  currency    CHAR(3)      NOT NULL DEFAULT 'INR',
  status      ENUM('created','paid','failed') NOT NULL DEFAULT 'created',
  payment_id  VARCHAR(40)  NULL,
  method      VARCHAR(30)  NULL,
  source      VARCHAR(20)  NOT NULL DEFAULT 'app',
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  paid_at     TIMESTAMP    NULL,
  PRIMARY KEY (order_id),
  UNIQUE KEY uq_payments_payment (payment_id),
  KEY idx_payments_uid (uid, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
