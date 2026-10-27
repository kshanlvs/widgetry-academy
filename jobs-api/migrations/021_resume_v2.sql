-- Resume v2: achievements and languages sections, saved copies of a resume per job (Resume Premium),
-- Resume Premium bought in the Android app (Google Play or Razorpay from Google's choice screen),
-- and a reminder before Premium ends.
ALTER TABLE candidates ADD COLUMN achievements JSON NULL;
ALTER TABLE candidates ADD COLUMN languages JSON NULL;

CREATE TABLE IF NOT EXISTS resume_versions (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  uid         VARCHAR(128)    NOT NULL,
  name        VARCHAR(80)     NOT NULL,
  job_id      VARCHAR(20)     NULL,
  job_title   VARCHAR(140)    NULL,
  company     VARCHAR(120)    NULL,
  data        JSON            NOT NULL,           -- { title, about, skills, points: [{ index, points }] }: what differs from the main resume
  settings    JSON            NULL,               -- template, accent, density… (null = same as the main resume)
  created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_resume_versions_uid (uid, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE resume_premium ADD COLUMN channel VARCHAR(20) NOT NULL DEFAULT 'razorpay';
ALTER TABLE resume_premium ADD COLUMN purchase_token VARCHAR(500) NULL;
ALTER TABLE resume_premium ADD COLUMN ext_token VARCHAR(4000) NULL;
ALTER TABLE resume_premium ADD COLUMN tax_state VARCHAR(60) NULL;
ALTER TABLE resume_premium ADD COLUMN reported_at TIMESTAMP NULL;
ALTER TABLE resume_premium ADD COLUMN reminded_at TIMESTAMP NULL;
