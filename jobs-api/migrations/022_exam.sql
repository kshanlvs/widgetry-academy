-- Exam Center: every submitted attempt (signed in or not) and the badges people earn.
-- A guest who passes can claim the badge after signing up; the attempt row then gets their uid.
CREATE TABLE IF NOT EXISTS exam_attempts (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nonce       CHAR(24)        NOT NULL,             -- from the signed attempt token: each attempt can be submitted once
  uid         VARCHAR(128)    NULL,                 -- null for guests until they claim
  ip_hash     CHAR(64)        NULL,
  level       VARCHAR(10)     NOT NULL,
  correct     SMALLINT        NOT NULL,
  total       SMALLINT        NOT NULL,
  score       TINYINT         NOT NULL,             -- percent
  passed      TINYINT(1)      NOT NULL DEFAULT 0,
  seconds     INT             NOT NULL DEFAULT 0,   -- time taken
  claimed_at  TIMESTAMP       NULL,
  created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_exam_attempt_nonce (nonce),
  KEY idx_exam_attempts_uid (uid, level, created_at),
  KEY idx_exam_attempts_ip (ip_hash, level, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS exam_badges (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id   VARCHAR(12)     NOT NULL,             -- in the shareable badge link
  uid         VARCHAR(128)    NOT NULL,
  name        VARCHAR(80)     NOT NULL,
  level       VARCHAR(10)     NOT NULL,
  score       TINYINT         NOT NULL,             -- best score, percent
  correct     SMALLINT        NOT NULL,
  total       SMALLINT        NOT NULL,
  attempt_id  BIGINT UNSIGNED NOT NULL,
  issued_at   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_exam_badge_public (public_id),
  UNIQUE KEY uq_exam_badge_user_level (uid, level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
