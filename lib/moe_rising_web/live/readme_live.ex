defmodule MoeRisingWeb.ReadmeLive do
  use MoeRisingWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    readme_content = load_readme_content()
    {:ok, assign(socket, readme_content: readme_content)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="w-full p-6 max-w-6xl mx-auto">
        <div class="mb-6">
          <h1 class="text-3xl font-bold mb-2">MoeRising Documentation</h1>
          <p class="text-gray-600">Complete setup and usage guide</p>
        </div>

        <div class="bg-white border border-gray-200 rounded-lg p-6 shadow-sm">
          <div class="prose prose-lg max-w-none">
            {Phoenix.HTML.raw(@readme_content)}
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp load_readme_content do
    # Try multiple possible paths for the README file
    possible_paths = [
      # Current working directory
      Path.join(File.cwd!(), "README.md"),
      # Relative to app dir
      Path.join(Application.app_dir(:moe_rising), "../README.md"),
      # One level up
      Path.join(Application.app_dir(:moe_rising), "../../README.md"),
      # Just the filename in case we're in the right directory
      "README.md"
    ]

    readme_path = Enum.find(possible_paths, &File.exists?/1)

    case readme_path && File.read(readme_path) do
      {:ok, content} ->
        # Ensure Earmark is loaded before using it
        Code.ensure_loaded(Earmark)

        content
        |> String.replace("# MoeRising - Mixture of Experts Demo", "")
        |> String.replace(~r/^## /, "### ")
        |> String.replace(~r/^### /, "#### ")
        |> String.replace(~r/^#### /, "##### ")
        |> String.replace(~r/^##### /, "###### ")
        |> Earmark.as_html!()

      {:error, _} ->
        """
        <h2>README Not Found</h2>
        <p>The README.md file could not be loaded. Please check the file exists in the project root.</p>
        """
    end
  end
end
