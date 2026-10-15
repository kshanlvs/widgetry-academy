-- Widgetry Jobs: initial schema (MySQL 8.0+ and MySQL-compatible hosts such as TiDB Cloud)
-- Jobs board (employers post, admin approves) + Talent Network (job-seeker profiles).

CREATE TABLE companies (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name        VARCHAR(120) NOT NULL,
  website     VARCHAR(300) NULL,
  verified    TINYINT(1)   NOT NULL DEFAULT 0,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_companies_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE jobs (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(12)     NOT NULL,                 -- unguessable id used in URLs
  company_id     INT UNSIGNED NOT NULL,
  title          VARCHAR(140) NOT NULL,
  job_type       ENUM('full_time','internship','freelance','contract','part_time') NOT NULL,
  work_mode      ENUM('remote','onsite','hybrid') NOT NULL,
  level          ENUM('fresher','junior','mid','senior','lead') NOT NULL,
  city           VARCHAR(80)  NULL,
  salary_min     INT UNSIGNED NULL,                     -- rupees
  salary_max     INT UNSIGNED NULL,
  salary_period  ENUM('month','year','project') NULL,
  description    TEXT         NOT NULL,
  apply_url      VARCHAR(400) NULL,
  apply_email    VARCHAR(200) NULL,
  contact_name   VARCHAR(100) NULL,                     -- private: for admin follow-up only
  contact_email  VARCHAR(200) NOT NULL,                 -- private
  posted_by_uid  VARCHAR(128) NULL,                     -- Firebase uid of the submitter
  status         ENUM('pending','approved','rejected','filled','expired') NOT NULL DEFAULT 'pending',
  reject_reason  VARCHAR(300) NULL,
  featured       TINYINT(1)   NOT NULL DEFAULT 0,
  approved_at    DATETIME     NULL,
  expires_at     DATETIME     NULL,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_jobs_public_id (public_id),
  KEY idx_jobs_status_expires (status, expires_at),
  KEY idx_jobs_type (job_type),
  KEY idx_jobs_mode (work_mode),
  KEY idx_jobs_level (level),
  KEY idx_jobs_city (city),
  KEY idx_jobs_posted_by (posted_by_uid),
  CONSTRAINT fk_jobs_company FOREIGN KEY (company_id) REFERENCES companies (id),
  CONSTRAINT chk_jobs_salary CHECK (salary_min IS NULL OR salary_max IS NULL OR salary_min <= salary_max),
  CONSTRAINT chk_jobs_apply CHECK (apply_url IS NOT NULL OR apply_email IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE job_skills (
  job_id  INT UNSIGNED NOT NULL,
  skill   VARCHAR(40)  NOT NULL,
  PRIMARY KEY (job_id, skill),
  KEY idx_job_skills_skill (skill),
  CONSTRAINT fk_job_skills_job FOREIGN KEY (job_id) REFERENCES jobs (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE job_reports (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  job_id        INT UNSIGNED NOT NULL,
  reason        ENUM('scam','asks_fees','fake','expired','wrong_info','other') NOT NULL,
  details       VARCHAR(500) NULL,
  reporter_uid  VARCHAR(128) NULL,
  reporter_hash CHAR(64)     NOT NULL,                  -- salted hash of IP, for de-duplication only
  status        ENUM('open','closed') NOT NULL DEFAULT 'open',
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_reports_once (job_id, reporter_hash),
  KEY idx_reports_status (status),
  CONSTRAINT fk_reports_job FOREIGN KEY (job_id) REFERENCES jobs (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Talent Network: one profile per signed-in user. Private by default (not browsable by companies yet).
CREATE TABLE candidates (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id           CHAR(12)     NOT NULL,
  uid                 VARCHAR(128) NOT NULL,
  full_name           VARCHAR(100) NOT NULL,
  email               VARCHAR(200) NOT NULL,
  phone               VARCHAR(20)  NULL,
  headline            VARCHAR(140) NOT NULL,
  current_company     VARCHAR(120) NULL,
  experience_years    DECIMAL(3,1) NOT NULL DEFAULT 0,
  city                VARCHAR(80)  NULL,
  work_modes          SET('remote','onsite','hybrid') NULL,
  job_types           SET('full_time','internship','freelance','contract','part_time') NULL,
  notice_period       ENUM('immediate','15_days','30_days','60_days','90_days') NULL,
  expected_salary_lpa DECIMAL(5,2) NULL,
  github_url          VARCHAR(300) NULL,
  linkedin_url        VARCHAR(300) NULL,
  portfolio_url       VARCHAR(300) NULL,
  apps                JSON         NULL,                -- [{name, url, role}]
  about               TEXT         NULL,
  open_to_work        TINYINT(1)   NOT NULL DEFAULT 1,
  hidden_companies    VARCHAR(400) NULL,                -- companies that must never see this profile
  verification        ENUM('self','portfolio','verified') NOT NULL DEFAULT 'self',
  verified_note       VARCHAR(300) NULL,
  status              ENUM('active','hidden') NOT NULL DEFAULT 'active',
  consent_at          DATETIME     NOT NULL,
  created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_candidates_uid (uid),
  UNIQUE KEY uq_candidates_public_id (public_id),
  KEY idx_candidates_verification (verification)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE candidate_skills (
  candidate_id INT UNSIGNED NOT NULL,
  skill        VARCHAR(40)  NOT NULL,
  PRIMARY KEY (candidate_id, skill),
  KEY idx_candidate_skills_skill (skill),
  CONSTRAINT fk_candidate_skills_candidate FOREIGN KEY (candidate_id) REFERENCES candidates (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
