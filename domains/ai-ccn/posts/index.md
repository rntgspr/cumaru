---
human_revised: false
targets: [meta]
summary: Defines where to plan posts and how to identify them by creator prefix and post number.
---

# Posts

Plan each post in its own directory under `.cumaru/posts/`. Keep the plan in that directory's `index.md` and place supporting planning documents alongside it.

Name the directory after the post ID, such as `CRE-1234`. Use the `post-prefix` from the [creator's profile](../creator/index.md), a hyphen, and the four-digit post number. The post number is unique within that creator's prefix.

## Post standard

Copy the [post template](../templates/post.md) to the post directory as `index.md`. Use the same ID in the title and directory name. Replace the template instructions with the post's actual plan and content.

- **Required for planning.** Creator profile, status, channel, format, language, audience, objective, and main message.
- **Required before publication.** Final content in the publication language and a reference for each asset it uses. Use a separate subsection for each channel when the copy or format changes.
- **When applicable.** Call to action, collaborators and credits, source links for factual claims, disclosures, accessibility text, and campaign or product references.
- **Optional.** A success metric with a target and measurement window.
- **By channel.** Record the date, time, and time zone when scheduled. Add the live URL and actual publication date after publication.

Use `draft`, `in-production`, `ready`, `scheduled`, `published`, or `canceled` for status. Use `ready` when the copy and assets are ready to publish.

Run `cumaru tree posts` to list post plans.
