defmodule Mix.Tasks.Moe.Rag.Build do
  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")
    IO.puts("Building RAG index from priv/a20_docs ...")
    res = MoeRising.RAG.Indexer.build_index!()
    IO.puts("Built #{res.count} chunks. Index stored in priv/a20_index.json")
  end
end
