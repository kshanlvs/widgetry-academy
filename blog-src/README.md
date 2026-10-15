# Widgetry blog

Posts are Markdown files in `posts/`. To publish a new one:

1. Create `posts/your-post-slug.md` (the file name becomes the URL: `/blog/your-post-slug.html`).
2. Start it with front matter:
   ```
   ---
   title: Android Developer Jobs in India (2026): Skills, Salary and Where to Apply
   description: One or two sentences, under 155 characters, that make people want to click.
   date: 2026-11-02
   tag: Jobs
   keywords: android developer jobs, android jobs in india
   cta: jobs        # jobs | resume | course
   ---
   ```
3. Write the post with `##` section headings. A `## Frequently asked questions` section with `###` questions becomes FAQ data for Google.
4. Run `python3 blog-src/build.py` (needs `pip install markdown`), then commit and push to `main`.

The build writes the post page, the blog index, the RSS feed and the sitemap entries. Change `updated:` in the front matter when you revise a post.
