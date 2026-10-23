-- AI tutor (RAG): the pages each answer was based on, so a reopened chat still shows its sources.
-- JSON array of {"title": "...", "url": "..."}; NULL for questions answered without Widgetry material.
ALTER TABLE chat_messages ADD COLUMN sources JSON NULL;
