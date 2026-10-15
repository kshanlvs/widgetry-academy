-- Seeker profile: photo (small, resized in the browser) and saved resume settings
CREATE TABLE candidate_photos (
  candidate_id INT UNSIGNED NOT NULL,
  mime         VARCHAR(20)  NOT NULL,
  data         MEDIUMBLOB   NOT NULL,
  updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (candidate_id),
  CONSTRAINT fk_photos_candidate FOREIGN KEY (candidate_id) REFERENCES candidates (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
ALTER TABLE candidates ADD COLUMN resume_settings JSON NULL;
