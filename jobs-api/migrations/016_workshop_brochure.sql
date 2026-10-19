-- Syllabus / brochure PDF for each short course (a path on the website or an https link)
ALTER TABLE workshops ADD COLUMN brochure VARCHAR(300) NULL;
UPDATE workshops SET brochure = 'brochures/bloc-crash-course.pdf' WHERE slug = 'bloc-crash-course' AND brochure IS NULL;
UPDATE workshops SET brochure = 'brochures/flutter-clean-architecture-course.pdf' WHERE slug = 'flutter-clean-architecture-course' AND brochure IS NULL;
