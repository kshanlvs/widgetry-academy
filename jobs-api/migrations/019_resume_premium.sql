-- Resume Premium: a one-time payment that unlocks AI writing help and pro templates for a number of days.
-- Buying again while active adds the days on top of the current expiry.
CREATE TABLE IF NOT EXISTS resume_premium (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  uid         VARCHAR(128)    NOT NULL,
  email       VARCHAR(254)    NULL,
  amount      INT UNSIGNED    NOT NULL,                 -- paise
  days        INT UNSIGNED    NOT NULL DEFAULT 90,
  status      ENUM('created','paid','failed','refunded') NOT NULL DEFAULT 'created',
  order_id    VARCHAR(40)     NULL,
  payment_id  VARCHAR(40)     NULL,
  method      VARCHAR(30)     NULL,
  paid_at     TIMESTAMP       NULL,
  starts_at   TIMESTAMP       NULL,
  expires_at  TIMESTAMP       NULL,
  created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_resume_premium_order (order_id),
  KEY idx_resume_premium_uid (uid, status, expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- One row per AI request, for the daily cap and cost tracking
CREATE TABLE IF NOT EXISTS resume_ai_usage (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  uid            VARCHAR(128)    NOT NULL,
  action         VARCHAR(20)     NOT NULL,
  input_tokens   INT UNSIGNED    NULL,
  output_tokens  INT UNSIGNED    NULL,
  created_at     TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_resume_ai_uid (uid, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
