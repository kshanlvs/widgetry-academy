-- Building a resume no longer means joining the Talent Network: joining is a separate opt-in.
-- Everyone who has a profile today agreed to the network when they saved it, so they stay in (default 1);
-- new profiles say yes or no explicitly.
ALTER TABLE candidates ADD COLUMN talent_network TINYINT(1) NOT NULL DEFAULT 1;
