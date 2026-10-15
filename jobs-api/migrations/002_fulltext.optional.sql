-- Optional: MySQL full-text search index. Hosts without MySQL FULLTEXT support (e.g. TiDB) skip this
-- automatically and the API falls back to normal LIKE matching, which is fine for thousands of jobs.
ALTER TABLE jobs ADD FULLTEXT KEY ft_jobs_text (title, description);
