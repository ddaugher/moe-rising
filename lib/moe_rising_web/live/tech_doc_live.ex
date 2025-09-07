defmodule MoeRisingWeb.TechDocLive do
  use MoeRisingWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    tech_doc_content = load_tech_doc_content()
    {:ok, assign(socket, tech_doc_content: tech_doc_content)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="w-full p-6 max-w-6xl mx-auto">
        <div class="mb-6">
          <h1 class="text-3xl font-bold mb-2">MoeRising Technical Architecture</h1>
          <p class="text-gray-600">Complete technical documentation and system architecture</p>
        </div>

        <div class="bg-white border border-gray-200 rounded-lg p-6 shadow-sm">
          <div class="prose prose-lg max-w-none">
            {Phoenix.HTML.raw(@tech_doc_content)}
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp load_tech_doc_content do
    # Try multiple possible paths for the technical architecture file
    possible_paths = [
      # Current working directory
      Path.join(File.cwd!(), "TECHNICAL_ARCHITECTURE.md"),
      # Relative to app dir
      Path.join(Application.app_dir(:moe_rising), "../TECHNICAL_ARCHITECTURE.md"),
      # One level up
      Path.join(Application.app_dir(:moe_rising), "../../TECHNICAL_ARCHITECTURE.md"),
      # Just the filename in case we're in the right directory
      "TECHNICAL_ARCHITECTURE.md"
    ]

    tech_doc_path = Enum.find(possible_paths, &File.exists?/1)

    case tech_doc_path && File.read(tech_doc_path) do
      {:ok, content} ->
        # Ensure Earmark is loaded before using it
        Code.ensure_loaded(Earmark)

        content
        |> String.replace("# MoeRising Technical Architecture", "")
        |> String.replace(~r/^## /, "### ")
        |> String.replace(~r/^### /, "#### ")
        |> String.replace(~r/^#### /, "##### ")
        |> String.replace(~r/^##### /, "###### ")
        |> Earmark.as_html!()

      {:error, _} ->
        """
        <h2>Technical Documentation Not Found</h2>
        <p>The TECHNICAL_ARCHITECTURE.md file could not be loaded. Please check the file exists in the project root.</p>
        """
    end
  end
end
