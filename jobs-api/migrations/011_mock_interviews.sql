-- Mock interviews with working engineers. Interviewers (added by an admin) publish time slots,
-- candidates book and pay with Razorpay, the interviewer fills in a scorecard afterwards.
-- Times are stored in UTC. Amounts are in paise.

CREATE TABLE interviewers (
  uid           VARCHAR(128) NOT NULL,
  email         VARCHAR(254) NOT NULL,
  name          VARCHAR(100) NOT NULL,
  title         VARCHAR(120) NOT NULL,                 -- e.g. Senior Flutter Engineer
  company       VARCHAR(120) NULL,
  years         TINYINT UNSIGNED NOT NULL DEFAULT 0,
  tracks        JSON         NOT NULL,                 -- ["flutter","android"]
  bio           VARCHAR(500) NULL,
  linkedin_url  VARCHAR(400) NULL,
  meeting_link  VARCHAR(400) NULL,                     -- their own Google Meet / Zoom room
  active        TINYINT(1)   NOT NULL DEFAULT 1,
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (uid),
  UNIQUE KEY uq_interviewers_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE interview_slots (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  interviewer_uid VARCHAR(128) NOT NULL,
  starts_at       DATETIME     NOT NULL,               -- UTC
  duration_min    SMALLINT UNSIGNED NOT NULL DEFAULT 60,
  status          ENUM('open','held','booked','cancelled') NOT NULL DEFAULT 'open',
  booking_id      BIGINT UNSIGNED NULL,                -- the booking holding or owning the slot
  held_until      DATETIME     NULL,                   -- UTC; a hold during payment expires
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_slot_time (interviewer_uid, starts_at),
  KEY idx_slots_open (status, starts_at),
  CONSTRAINT fk_slots_interviewer FOREIGN KEY (interviewer_uid) REFERENCES interviewers (uid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE mock_bookings (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  uid             VARCHAR(128) NOT NULL,
  email           VARCHAR(254) NULL,
  name            VARCHAR(100) NULL,
  slot_id         BIGINT UNSIGNED NOT NULL,
  interviewer_uid VARCHAR(128) NOT NULL,
  starts_at       DATETIME     NOT NULL,               -- copied from the slot (UTC)
  duration_min    SMALLINT UNSIGNED NOT NULL,
  track           VARCHAR(20)  NOT NULL,
  level           VARCHAR(20)  NOT NULL,
  format          VARCHAR(20)  NOT NULL,
  focus           VARCHAR(500) NULL,                   -- what the candidate wants to practise
  share_profile   TINYINT(1)   NOT NULL DEFAULT 1,     -- interviewer may see the candidate's Talent Network profile
  amount          INT          NOT NULL,               -- paise
  status          ENUM('created','confirmed','completed','cancelled','no_show','refund_due') NOT NULL DEFAULT 'created',
  order_id        VARCHAR(40)  NULL,
  payment_id      VARCHAR(40)  NULL,
  method          VARCHAR(30)  NULL,
  reminded_at     TIMESTAMP    NULL,
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  paid_at         TIMESTAMP    NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_mock_order (order_id),
  UNIQUE KEY uq_mock_payment (payment_id),
  KEY idx_mock_uid (uid, starts_at),
  KEY idx_mock_interviewer (interviewer_uid, starts_at),
  KEY idx_mock_status (status, starts_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE mock_scorecards (
  booking_id      BIGINT UNSIGNED NOT NULL,
  scores          JSON         NOT NULL,               -- {"flutter":4,"state":3,...} each 1-5
  overall         DECIMAL(2,1) NOT NULL,
  strengths       VARCHAR(1500) NOT NULL,
  improve         VARCHAR(1500) NOT NULL,
  recommendation  ENUM('strong_hire','hire','lean_no','no') NOT NULL,
  shared          TINYINT(1)   NOT NULL DEFAULT 0,     -- candidate chose to show it on their profile
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (booking_id),
  CONSTRAINT fk_scorecard_booking FOREIGN KEY (booking_id) REFERENCES mock_bookings (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
