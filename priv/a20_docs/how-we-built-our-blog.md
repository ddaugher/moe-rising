
# Building Our Blog with NimblePublisher

A few weeks ago, we decided to revamp our website and add a blog. In our search for the simplest-yet-powerful approach, we came across a fantastic [blog post from Dashbit](https://dashbit.co/blog){:target="\_blank"}, which explained how they built their own blog without relying on a database. Instead, they used a compile-time approach and then wrapped up much of this functionality into a library called [NimblePublisher](https://github.com/dashbitco/nimble_publisher){:target="\_blank"}.

Their solution aligned perfectly with our goals:

1. **Keep content in Markdown files** so our developer-focused team could manage everything via Git.
2. **Compile posts into memory** at build time, keeping runtime overhead low while retaining dynamic capabilities in our Phoenix app.
3. **Use minimal dependencies** for Markdown parsing and syntax highlighting.

Below is a summary of how we implemented these ideas on our own project. While the logic follows closely to Dashbit’s original post, we’ll focus on how it fits into an augustwenty workflow.

---

## Off-the-shelf or roll our own?

We asked ourselves the same question Dashbit did: do we grab an off-the-shelf CMS (like WordPress or Ghost) or roll our own? Since most of our site is static, the main question was how to best power the blog.

In past projects, we used static site generators and various publishing platforms. Static site generators fit a developer-friendly workflow nicely—blog posts sit as files in a Git repo, so it’s easy to version, review, and merge via pull requests. However, purely static solutions can limit dynamic features. Meanwhile, database-powered platforms are great for more complex or interactive needs, but we didn’t really want to maintain a database.

Thanks to Dashbit’s post, we realized we could “have the best of both worlds”: keep blog posts as Markdown files, yet still serve them dynamically inside a Phoenix app. The secret sauce? Precompile those posts, store them in memory, and skip the database layer altogether.

---

## Precompiling our blog posts

Our website is a regular Phoenix application. But instead of fetching data from a database, we load and parse Markdown files at compile time using [NimblePublisher](https://github.com/dashbitco/nimble_publisher){:target="\_blank"}.

Here’s the gist: when the project compiles, we scan the filesystem for blog posts, process them, and embed them into a module attribute. For example, if you’ve got a module like `Website.Journals`, calling `Website.Journals.list_posts()` returns all blog posts already baked into memory. We added a little bit of wizardry in order to allow us to have “DRAFT” posts that are not viewable to the public. This allows us to create hidden posts that a group of friendlies can review before they go live.

Here is the main guts of the `Website.Journals` module:

```elixir
defmodule Website.Journals do
  @moduledoc """
  The `Website.Journals` module is responsible for managing and retrieving journal posts.
  It uses the NimblePublisher library to build posts from markdown files and provides various functions
  to list, filter, and retrieve posts and tags.
  """

  alias Website.Journals.Post

  use NimblePublisher,
    build: Post,
    from: Application.app_dir(:website, "priv/posts/**/*.md"),
    as: :posts,
    highlighters: [:makeup_elixir, :makeup_erlang]

  @posts Enum.sort_by(@posts, & &1.date, {:desc, Date})

  @spec list_posts() :: [Post]
  def list_posts do
    @posts
    |> Enum.reject(fn post ->
      Enum.any?(post.tags, fn tag -> String.equivalent?(tag, "draft") end)
    end)
  end

  @spec get_post_by_id!(String.t()) :: Post | no_return()
  def get_post_by_id!(id) do
    Enum.find(@posts, &(&1.id == id)) ||
      raise NotFoundError, "post with id=#{id} not found"
  end

  defp check_prev_index(index) when index in [nil, 0], do: :error
  defp check_prev_index(index), do: {:ok, index - 1}
  defp check_next_index(index) when index in [nil, length(@posts)], do: :error
  defp check_next_index(index), do: {:ok, index + 1}

  @spec get_previous_post(String.t()) :: Post | nil
  def get_previous_post(id) do
    with {:ok, index} <-
           Enum.find_index(@posts, fn post -> post.id == id end) |> check_prev_index(),
         {:ok, post} <- Enum.fetch(@posts, index) do
      post
    else
      _ -> nil
    end
  end

  @spec get_next_post(String.t()) :: Post | nil
  def get_next_post(id) do
    with {:ok, index} <-
           Enum.find_index(@posts, fn post -> post.id == id end) |> check_next_index(),
         {:ok, post} <- Enum.fetch(@posts, index) do
      post
    else
      _ -> nil
    end
  end

  @spec list_posts_by_tag!(String.t()) :: [Post] | no_return()
  def list_posts_by_tag!(tag) do
    case Enum.filter(@posts, &(tag in &1.tags)) do
      [] -> raise NotFoundError, "posts with tag=#{tag} not found"
      posts -> posts
    end
  end
end
```

We name each blog post file with a structure like `/posts/YEAR/MONTH-DAY-ID.md`. During compilation, our code grabs all those files, parses them, and stores them in a module attribute. At runtime, `list_posts/0` simply returns what’s already in memory—no database call required.

---

## Parsing blog posts

Each Markdown file includes metadata at the top—title, author, tags, etc.—along with the body content. We leveraged Dashbit’s approach for extracting metadata, plus the file’s path, to build a complete `Post` struct. Here’s a simplified version:

```elixir
defmodule Website.Journals.Post do
  @enforce_keys [
    :author,
    :avatar,
    :body,
    :date,
    :description,
    :id,
    :img_url,
    :read_time,
    :tags,
    :title
  ]
  defstruct [
    :author,
    :avatar,
    :body,
    :date,
    :description,
    :id,
    :img_url,
    :read_time,
    :tags,
    :title
  ]

  def build(filename, attrs, body) do
    {year, month, day, id} = parse_filename(filename)
    date = build_date(year, month, day)

    build_struct(id, date, attrs, body)
  end

  defp parse_filename(filename) do
    [year, month_day_id] =
      filename
      |> Path.rootname()
      |> Path.split()
      |> Enum.take(-2)

    [month, day, id] = String.split(month_day_id, "-", parts: 3)

    {year, month, day, id}
  end

  defp build_date(year, month, day) do
    Date.from_iso8601!("#{year}-#{month}-#{day}")
  end

  defp build_struct(id, date, attrs, body) do
    struct!(__MODULE__, [id: id, date: date, body: body] ++ Map.to_list(attrs))
  end
end
```

This converts each file into a structured Elixir `%Post{}`. All you have to do then is call `Website.Journals.list_posts()` in your controllers or LiveViews to render the posts.

---

## Writing posts in Markdown

By default, our post body contains the raw text.

A typical blog post will look like this:

```elixir
# /posts/2020/04-17-hello-world.md
%{
  title: "Hello world!",
  author: "Mickey Mouse",
  tags: ~w(hello),
  description: "Let's learn how to say hello world"
}
---
This is the post.
```

Thanks to this, we write our blog posts in plain Markdown, and the content compiles to HTML **before** our site goes live. This keeps our runtime footprint small and eliminates the need for front-end JS syntax highlighting.

---

## Summary of the approach

With this system in place:

* **We write posts in Markdown** and push them to our Git repo.
* **Posts get compiled** into memory when we deploy or run our app locally.
* **Serving posts is lightning-fast** because everything lives in memory—no database queries or heavy transformations at runtime.
* **We can still build dynamic features**, like filtering, pagination, or tag-based searches, since all the data is accessible as a list of structs.

Just as Dashbit mentioned, this method provides the “best of both worlds.” We get the simplicity and version control benefits of static site generators while retaining the dynamic power of Phoenix.

---

## Bonus Features

### 1. Tag Filtering

Because all posts are in-memory, filtering by tag is straightforward. For instance:

```elixir
  @tags @posts |> Enum.flat_map(& &1.tags) |> Enum.uniq() |> Enum.sort()

  @spec list_tags() :: [String.t()]
  def list_tags, do: @tags

  @spec list_tags_tuple() :: [{String.t(), boolean()}]
  def list_tags_tuple do
    @tags
    |> Enum.reject(&String.equivalent?(&1, "draft"))
    |> Enum.map(fn tag -> {tag, false} end)
  end

  defmodule NotFoundError do
    @moduledoc """
    Exception raised when a post or tag is not found.
    """
    defexception [:message, plug_status: 404]
  end
```

Then just wire up routes and views to display posts for a given tag.

### 2. Live Reloading

While developing locally, it’s nice to see new posts appear immediately. Since we marked our posts as `@external_resource`, Phoenix can recompile changes if we include the `/posts` directory in `live_reload` config:

```elixir
# Watch static and templates for browser reloading.
config :website, WebsiteWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/website_web/(controllers|live|components)/.*(ex|heex)$",
      ~r"posts/*/.*(md)$"
    ]
  ]
```

Now, edit a Markdown file and watch it update in your browser—no manual refresh needed.

---

## Wrapping Up

For us, building our blog this way has been a fun, low-maintenance alternative to typical databases or external CMS tools. We owe a big thanks to Dashbit for sharing their original approach and for open-sourcing [NimblePublisher](https://github.com/dashbitco/nimble_publisher){:target="\_blank"}, which conveniently packages up this entire workflow.

If you’re looking to create a blog or similar content-driven feature for your Phoenix app—without reaching for a separate CMS—consider NimblePublisher or rolling your own similar approach.

**Happy blogging!**