-- Short live courses (workshops) such as the Bloc crash course, each paid separately through Razorpay.
CREATE TABLE IF NOT EXISTS workshops (
  id            INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  slug          VARCHAR(60)   NOT NULL,
  title         VARCHAR(140)  NOT NULL,
  starts_at     DATETIME      NULL,                -- first session (UTC); NULL until dates are announced
  schedule      VARCHAR(200)  NULL,                -- shown as written, e.g. "Sat 1 & Sun 2 Nov · 11 AM–1:30 PM IST"
  duration_min  INT UNSIGNED  NOT NULL DEFAULT 300,
  price         INT UNSIGNED  NOT NULL,            -- paise
  early_price   INT UNSIGNED  NULL,                -- paise; offered until early_until or until early_seats are taken
  early_until   DATETIME      NULL,
  early_seats   INT UNSIGNED  NULL,
  seats         INT UNSIGNED  NOT NULL DEFAULT 40,
  meeting_link  VARCHAR(500)  NULL,                -- shown only to people who paid
  status        ENUM('draft','open','closed','done') NOT NULL DEFAULT 'draft',
  created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_workshops_slug (slug)
);

CREATE TABLE IF NOT EXISTS workshop_enrollments (
  id            INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  workshop_id   INT UNSIGNED  NOT NULL,
  uid           VARCHAR(128)  NOT NULL,
  email         VARCHAR(190)  NULL,
  name          VARCHAR(120)  NULL,
  phone         VARCHAR(20)   NULL,
  amount        INT UNSIGNED  NOT NULL,            -- paise
  early         TINYINT(1)    NOT NULL DEFAULT 0,
  status        ENUM('created','confirmed','cancelled','refunded') NOT NULL DEFAULT 'created',
  order_id      VARCHAR(64)   NULL,
  payment_id    VARCHAR(64)   NULL,
  method        VARCHAR(30)   NULL,
  paid_at       TIMESTAMP     NULL,
  created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_we_order (order_id),
  KEY ix_we_workshop (workshop_id, status),
  KEY ix_we_uid (uid),
  CONSTRAINT fk_we_workshop FOREIGN KEY (workshop_id) REFERENCES workshops (id) ON DELETE CASCADE
);

-- The first one. Dates stay empty (draft) until set in Admin → Courses.
INSERT IGNORE INTO workshops (slug, title, duration_min, price, early_price, early_seats, seats, status)
VALUES ('bloc-crash-course', 'Bloc State Management Crash Course', 300, 99900, 79900, 15, 40, 'draft');
