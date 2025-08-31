For years, our website ran on Squarespace. It was simple, fast to deploy, and easy to manage—everything we needed in the early days. But as Augustwenty grew, so did our expectations. What once felt like a time-saving solution began to feel like a limitation, particularly for our engineering team.

Squarespace offered attractive templates and a streamlined editing experience, but it didn’t offer the flexibility or control we needed to evolve the site in lockstep with our business. Every time we wanted to introduce a new feature, preview changes before they went live, or align a release with a specific milestone, we found ourselves working against the platform instead of with it. Over time, these limitations became friction points that interrupted our ability to move quickly and confidently.

Eventually, the decision became clear: if we wanted a site that could grow with us, we needed to build it ourselves.

### Building Like We Consult

At Augustwenty, we’re consultants and engineers. We build thoughtful, scalable software systems for our clients every day—and it was time to apply that same level of intention and discipline to our own platform.

We chose to roll our own web application, not because it was the easiest route, but because it gave us the foundation we needed to work the way we’re used to. From day one, we designed our new site with environments in mind. We stood up separate development and production environments, allowing us to test features, preview content, and stage updates without affecting the public-facing site. This made our iteration cycles faster and more confident—exactly what we aim to deliver for the businesses we work with.

We also gained complete control over deployments. We could release updates based on business timing, not platform limitations. Whether it was launching a new article, refining copy, or introducing new content modules, we now had the freedom to coordinate technical changes with strategic intent.

### The Technology Behind the Site

Our rebuilt site is powered by the tools and frameworks that align with our engineering philosophy—modern, composable, and maintainable.

At the core is **Elixir**, with the **Phoenix LiveView** framework providing a dynamic, real-time experience without the complexity of frontend JavaScript frameworks.

When we decided to rebuild augustwenty.com, we didn’t just want a flexible content platform—we wanted a system that reflected how we think about engineering: efficient, maintainable, and fast to evolve.

Elixir has long been a go-to language for us, thanks to its functional style, strong concurrency model, and battle-tested runtime on the Erlang VM. It excels in reliability and performance, which made it a natural choice for our core backend.

But the standout was **Phoenix LiveView**—a framework that lets us build real-time, interactive user interfaces without the complexity of traditional frontend JavaScript frameworks. Instead of pushing logic to the browser, LiveView handles state and rendering on the server and syncs with clients over lightweight WebSockets.

This approach gave us:

- Real-time interactivity without relying on React or Vue
- A simplified architecture with no separate frontend codebase
- Faster iteration cycles with everything managed in Elixir
- A smaller surface area for bugs and security issues
- Faster performance on both modern and lower-powered devices

By choosing Elixir and LiveView, we weren’t chasing novelty—we were embracing a toolset that lets us move quickly, build confidently, and maintain quality over time. It’s the same mindset we bring to every client project, now reflected in our own platform.

As the backbone of our data layer, PostgreSQL plays a critical role in powering the dynamic content and structured metadata that make up our site. Its mature feature set, proven reliability, and compatibility with Elixir make it a natural fit for projects where data integrity and performance are non-negotiable.

With PostgreSQL, we get:

- Strong support for complex queries and relational data models
- Built-in features like full-text search and JSON support
- Rock-solid stability and transactional safety
- A massive ecosystem of tools and extensions

PostgreSQL also integrates seamlessly with Ecto, the Elixir database wrapper and query builder we use, enabling readable, maintainable, and composable data interactions across our application. It’s a foundation we trust—and one that gives us room to grow.

**Oban** manages background processing for asynchronous tasks like email and scheduled publishing.

### Content, the Database Way

We’ve always believed that content should be easy to write, manage, and ship—without sacrificing performance or adding unnecessary complexity. In the early days, NimblePublisher gave us a lightweight way to version-control posts in Git and compile them into the site at build time. It was simple, transparent, and blazingly fast.

But as our needs evolved, so did our approach. We’ve since moved to a database-backed system for managing both employee lists and posts. While we lose Git-based version control, nightly database backups ensure we never lose content. Instead of tying content updates to compile-time rendering, we can now make changes instantly, without waiting for a build.

Editorial transparency also looks a little different—commits no longer tell the whole story—but updates are traceable through our backlog, giving us context for what was written, when, and why. And with the flexibility of a database, local testing and iteration are easier than ever.

This shift reflects the same principle that guided our move away from Squarespace: use the right tool for the stage we’re in. For us, that means content workflows that are still simple and developer-friendly, but now more flexible, scalable, and aligned with how our team works today.

On the frontend, we built the interface using **Tailwind CSS** and **Tailwind UI**. This gave us a consistent, responsive design system that feels modern but remains highly customizable. It allowed us to move fast while keeping a tight handle on the visual language of the site.

When it came to designing the visual layer of the site, we wanted consistency, flexibility, and speed. Tailwind CSS gave us the utility-first foundation we needed, while Tailwind UI offered beautifully structured components that kept our design language cohesive.

Instead of bloated CSS files or rigid design frameworks, Tailwind lets us compose UIs directly in markup—focusing on structure and clarity over endless overrides. The result is a site that’s responsive, accessible, and visually aligned with our brand, without the typical friction of traditional CSS workflows.

With Tailwind, we:

- Rapidly built a design system tailored to our brand
- Ensured consistency across pages and components
- Reduced design/development handoff time
- Supported responsive layouts and mobile-first design from day one

Tailwind helped us deliver a design that feels intentional, modern, and clean—without sacrificing control or flexibility.

Deployment is handled through **Mint**, a CI/CD product from RWX that lets us define environments declaratively and deploy directly from Git. Combined with **GitHub Actions**, including the use of **`release-please`** for automated semantic versioning and changelog generation, we’ve created a deployment pipeline that’s as clean and professional as the code it ships.

A modern application needs more than clean code—it needs a clear path to production. Mint lets us define deployment workflows and environment configurations directly in Git. It abstracts away complex infrastructure management while still giving us full control over how and when changes go live. With Mint, staging and production environments are versioned, auditable, and reproducible—exactly what we want when releasing business-critical software.

We use Mint to:

- Deploy automatically from main to production after passing build and test gates
- Manage environment variables, secrets, and infrastructure config declaratively
- Integrate preview deployments directly into GitHub pull requests
- Roll back instantly, if needed, with full version traceability

The result is a deployment pipeline that’s fast, safe, and invisible when it should be—freeing our engineers to focus on delivering value instead of wrestling with infrastructure.

### Lessons Learned

Rebuilding our website from the ground up was a valuable exercise—not just technically, but strategically. As with any project, it came with its own set of challenges, decisions, and insights. Looking back, several key lessons stand out that may be helpful for others considering a similar path.

First, **owning your infrastructure creates leverage**. The ability to control our environments, deployment schedules, and content workflows gave us more than just technical flexibility—it gave us strategic agility. We could launch features on our timeline, test with confidence, and treat the site as a living part of the business, not a static artifact.

Second, **developer experience is business impact**. By using tools that align with how we work—Elixir, LiveView, Tailwind, and a Git-driven CI/CD process—we eliminated friction. Every choice we made reduced context-switching and increased momentum. It reminded us that good internal tooling isn’t a luxury; it’s a multiplier.

Third, we were reminded that **design systems matter**. Tailwind CSS and Tailwind UI provided structure without sacrificing creativity. They helped us create a cohesive visual language that reflects our brand while staying flexible enough to support future changes. Having a solid design foundation meant fewer decisions on the fly and more consistency across the experience.

Fourth, **automation pays off early and often**. Investing in CI/CD tooling from the start—especially automated versioning, changelogs, and previews—made the release process predictable and repeatable. It reduced the operational burden on our team and made it easier to bring others into the development process.

And finally, we learned that **a website is never just a website**. It’s a reflection of your priorities, your process, and your professionalism. By rebuilding ours with the same care we bring to client work, we’re not just showcasing what we do—we're living it.
