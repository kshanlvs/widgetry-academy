-- Resume builder: work history and education on Talent Network profiles
ALTER TABLE candidates ADD COLUMN experience JSON NULL;
ALTER TABLE candidates ADD COLUMN education JSON NULL;
