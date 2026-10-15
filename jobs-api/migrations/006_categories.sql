-- Job categories (Flutter, Android, iOS, ...). New categories are added as rows here, no code change needed.
CREATE TABLE job_categories (
  slug             VARCHAR(30)  NOT NULL,
  name             VARCHAR(60)  NOT NULL,
  sort_order       SMALLINT     NOT NULL DEFAULT 100,
  active           TINYINT(1)   NOT NULL DEFAULT 1,
  suggested_skills JSON         NULL,
  PRIMARY KEY (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
INSERT INTO job_categories (slug, name, sort_order, suggested_skills) VALUES
  ('flutter', 'Flutter', 10, '["Flutter","Dart","Firebase","Bloc","Provider","Riverpod","GetX","REST APIs","Clean Architecture","Testing","CI/CD","Google Maps","Push Notifications","Animations","Flame","Git"]'),
  ('android', 'Android', 20, '["Kotlin","Java","Jetpack Compose","Android SDK","Coroutines","MVVM","Room","Hilt","Retrofit","Firebase","REST APIs","Clean Architecture","Testing","Espresso","Gradle","Git"]'),
  ('ios',     'iOS',     30, '["Swift","SwiftUI","UIKit","Combine","Objective-C","Core Data","MVVM","Xcode","XCTest","REST APIs","Firebase","Clean Architecture","Testing","CI/CD","Git"]');
ALTER TABLE jobs ADD COLUMN category VARCHAR(30) NOT NULL DEFAULT 'flutter';
CREATE INDEX idx_jobs_category_live ON jobs (category, status, expires_at);
-- Which kinds of roles a job seeker wants (a seeker can pick several)
CREATE TABLE candidate_categories (
  candidate_id INT UNSIGNED NOT NULL,
  category     VARCHAR(30)  NOT NULL,
  PRIMARY KEY (candidate_id, category),
  KEY idx_candidate_categories_category (category),
  CONSTRAINT fk_cc_candidate FOREIGN KEY (candidate_id) REFERENCES candidates (id) ON DELETE CASCADE,
  CONSTRAINT fk_cc_category  FOREIGN KEY (category) REFERENCES job_categories (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
INSERT INTO candidate_categories (candidate_id, category) SELECT id, 'flutter' FROM candidates;
