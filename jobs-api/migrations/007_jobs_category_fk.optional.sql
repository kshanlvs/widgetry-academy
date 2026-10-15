-- Extra safety: a job's category must exist. Optional so hosts that handle this differently still start.
ALTER TABLE jobs ADD CONSTRAINT fk_jobs_category FOREIGN KEY (category) REFERENCES job_categories (slug);
