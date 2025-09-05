# MoeRising Technical Architecture

## Overview

MoeRising is a Phoenix LiveView application that implements a Mixture of Experts (MoE) system with attention-based routing. The system analyzes user prompts and intelligently routes them to specialized AI experts, then aggregates their responses using an LLM judge.

## System Architecture

### High-Level Architecture

```
┌──────────────────┐    ┌───────────────────┐    ┌─────────────────┐
│   Web Browser    │◄──►│  Phoenix LiveView │◄──►│    MoE System   │
│                  │    │                   │    │                 │
│ - User Interface │    │ - Real-time UI    │    │ - Gate (Router) │
│ - Form Input     │    │ - Logging         │    │ - Experts       │
│ - Results        │    │ - State Mgmt      │    │ - Aggregation   │
└──────────────────┘    └───────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌────────────────────┐
                       │     OpenAI API     │
                       │                    │
                       │ - Chat Completions │
                       │ - Embeddings       │
                       └────────────────────┘
```

## Core Components

### 1. Application Layer (`lib/moe_rising/`)

#### MoeRising.Application
- **Purpose**: OTP application supervisor
- **Responsibilities**: 
  - Starts Phoenix endpoint
  - Manages PubSub for real-time communication
  - Handles DNS clustering for production deployment

#### MoeRising.Expert (Behaviour)
- **Purpose**: Defines the contract for all expert implementations
- **Interface**:
  ```elixir
  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback call(prompt :: String.t(), opts :: Keyword.t()) ::
    {:ok, %{output: String.t(), tokens: non_neg_integer}} | {:error, term}
  ```

### 2. Attention Mechanism (`MoeRising.Gate`)

The Gate module implements a lightweight attention mechanism that determines which experts should handle a given prompt.

#### Algorithm:
1. **Keyword Matching**: Counts expert-specific keywords in the prompt using word boundary regex
2. **Score Calculation**: Applies formula: `base_weight × (1 + keyword_matches)`
3. **Softmax Normalization**: Converts raw scores to probabilities that sum to 1.0
4. **Ranking**: Orders experts by probability for selection

#### Expert Keywords:
```elixir
@experts [
  {"RAG", ~w(augustwenty a20 journal policy splashlight dmx nimblepublisher docs business)},
  {"Writing", ~w(explain summary outline write tone prose paragraph blog doc clarify)},
  {"Code", ~w(elixir phoenix liveview mix ecto code bug compile error module function)},
  {"Math", ~w(sum add subtract multiply divide integral derivative probability matrix)},
  {"DataViz", ~w(chart plot graph visualization data visual encoding)}
]
```

#### Softmax Implementation:
```elixir
defp softmax(map) do
  vals = Map.values(map)
  maxv = Enum.max(vals)  # Numerical stability
  exps = for v <- vals, do: :math.exp(v - maxv)
  z = Enum.sum(exps)
  
  map
  |> Map.keys()
  |> Enum.zip(exps)
  |> Enum.into(%{}, fn {k, e} -> {k, e / z} end)
end
```

### 3. Expert Router (`MoeRising.Router`)

The Router orchestrates the entire MoE process:

#### Process Flow:
1. **Gate Analysis**: Uses `MoeRising.Gate.score/1` to get expert probabilities
2. **Expert Selection**: Selects top-k experts (default: 2) based on probabilities
3. **Parallel Execution**: Runs selected experts concurrently using `Task.async_stream/3`
4. **Result Aggregation**: Uses LLM judge to intelligently combine results

#### Aggregation Strategies:
- **Single Expert**: Returns the expert's output directly
- **Multiple Experts**: Uses an LLM judge with system prompt:
  ```
  "You are a helpful judge. Combine the best parts concisely."
  ```

#### Error Handling:
- Individual expert failures don't crash the system
- Failed experts return error messages in the result
- Timeout protection (120 seconds per expert)

### 4. Expert Implementations

#### RAG Expert (`MoeRising.Experts.RAG`)
- **Purpose**: Retrieval-Augmented Generation using augustwenty documentation
- **Process**:
  1. Embeds user query using OpenAI embeddings
  2. Performs semantic search against document chunks
  3. Retrieves top 6 most relevant chunks
  4. Constructs context with citations
  5. Generates response with inline citations and sources list

#### Writing Expert (`MoeRising.Experts.Writing`)
- **Purpose**: Content creation and explanation
- **System Prompt**: "You are a precise technical writer. Explain clearly, add structure, and avoid code unless asked."

#### Code Expert (`MoeRising.Experts.Code`)
- **Purpose**: Programming and technical assistance
- **System Prompt**: "You are an expert Elixir/Phoenix engineer. Prefer runnable snippets and short explanations."

#### Math Expert (`MoeRising.Experts.Math`)
- **Purpose**: Mathematical reasoning and calculations
- **System Prompt**: "You are a careful math tutor. Solve step by step. If ambiguous, state assumptions."

#### DataViz Expert (`MoeRising.Experts.DataViz`)
- **Purpose**: Data visualization and charting
- **System Prompt**: "You create precise data visualizations and explain how to build them in Elixir/Phoenix + Vega-Lite."

### 5. RAG System

#### Document Processing Pipeline:
```
Markdown Files → Chunker → Embeddings → ETS Store → Semantic Search
```

#### Components:

**MoeRising.RAG.Chunker**:
- Splits documents into overlapping chunks (1200 chars, 200 overlap)
- Preserves document structure and context

**MoeRising.RAG.Indexer**:
- Processes all markdown files in `priv/a20_docs/`
- Generates embeddings in batches of 64
- Creates searchable index stored in `priv/a20_index.json`

**MoeRising.RAG.Store**:
- In-memory ETS table for fast retrieval
- Cosine similarity search implementation
- Automatic index loading on startup

#### Search Algorithm:
```elixir
def search(query_vec, k \\ 6) do
  :ets.tab2list(@table)
  |> Enum.map(fn {_id, c} -> {cos_sim(query_vec, c.embedding), c} end)
  |> Enum.sort_by(fn {s, _} -> -s end)
  |> Enum.take(k)
end
```

### 6. LLM Client (`MoeRising.LLMClient`)

Unified interface for OpenAI API interactions:

#### Chat Completions:
- Uses configurable model (default: "gpt-5")
- 120-second timeout for long responses
- Returns content and token usage

#### Embeddings:
- Batch processing support (up to 64 texts)
- Configurable model (default: "text-embedding-3-small")
- 30-second timeout

### 7. Logging System (`MoeRising.Logging`)

Real-time logging that sends messages to LiveView processes:

#### Features:
- Process-aware logging (only sends to alive processes)
- Multiple log levels: simple messages, labeled data, metadata
- Console logging for debugging
- Automatic timestamping in UI

#### Usage:
```elixir
MoeRising.Logging.log(pid, "Expert", "Processing started", "prompt length: #{length}")
```

## Web Layer (`lib/moe_rising_web/`)

### 1. LiveView Interface (`MoeRisingWeb.MoeLive`)

#### State Management:
- **Query State**: Current user input and results
- **Loading State**: Processing phases and progress
- **Log Messages**: Real-time activity log
- **Attention Analysis**: Gate scoring visualization

#### Processing Phases:
1. `:input_analysis` - Parse and analyze input
2. `:gate_analysis_complete` - Gate scoring finished
3. `:routing_experts` - Expert selection and routing
4. `:expert_processing` - Experts running in parallel
5. `:aggregating_results` - LLM judge combining results
6. `:complete` - Final result ready

#### Real-time Updates:
- WebSocket connection for live updates
- Automatic log scrolling
- Phase progression visualization
- Expert selection highlighting

### 2. UI Components

#### Attention Process Flow:
- Visual representation of the 6-step attention process
- Color-coded phases with progress indicators
- Responsive design for mobile and desktop

#### Expert Analysis Display:
- Keyword highlighting in user input
- Probability scores and rankings
- Matched keywords visualization
- Source citations for RAG results

#### Activity Logging:
- Real-time log messages with timestamps
- Color-coded log levels
- Automatic scrolling to latest entries
- Process monitoring information

## Data Flow

### Complete Request Lifecycle:

```
1. User Input
   ↓
2. LiveView Event Handler
   ↓
3. Attention Analysis (Gate.scoring)
   ↓
4. Expert Selection (Router.route)
   ↓
5. Parallel Expert Execution
   ├── RAG Expert (if selected)
   │   ├── Query Embedding
   │   ├── Semantic Search
   │   └── Context Generation
   ├── Writing Expert (if selected)
   ├── Code Expert (if selected)
   ├── Math Expert (if selected)
   └── DataViz Expert (if selected)
   ↓
6. Result Aggregation (LLM Judge)
   ↓
7. LiveView Update
   ↓
8. UI Rendering
```

### Key Data Structures:

#### Gate Result:
```elixir
%{
  scores: %{"RAG" => 2.0, "Writing" => 1.0, ...},
  probs: %{"RAG" => 0.6, "Writing" => 0.2, ...},
  ranked: [{"RAG", 0.6}, {"Writing", 0.2}, ...]
}
```

#### Router Result:
```elixir
%{
  gate: gate_result,
  chosen: [{"RAG", 0.6}, {"Writing", 0.2}],
  results: [%{name: "RAG", prob: 0.6, output: "...", tokens: 150, sources: [...]}],
  aggregate: %{strategy: :judge_llm, output: "...", from: "RAG, Writing"}
}
```

#### RAG Chunk:
```elixir
%{
  id: "c42",
  title: "Five Years of Building Valuable Things",
  url: "file:///path/to/doc.md",
  text: "chunk content...",
  embedding: [0.1, -0.2, 0.3, ...]
}
```

## Configuration

### Environment Variables:
- `OPENAI_API_KEY`: Required for LLM and embedding services
- `MOE_LLM_MODEL`: Chat completion model (default: "gpt-5")
- `MOE_EMBED_MODEL`: Embedding model (default: "text-embedding-3-small")
- `PORT`: Web server port (default: 4000)

### Mix Tasks:
- `mix moe.rag.build`: Builds the RAG index from markdown files
- `mix precommit`: Runs formatting, tests, and compilation checks

## Performance Characteristics

### Scalability:
- **Concurrent Expert Execution**: Uses `Task.async_stream/3` for parallel processing
- **ETS Storage**: In-memory document store for fast retrieval
- **Batch Embeddings**: Processes up to 64 texts per API call
- **Connection Pooling**: Req library handles HTTP connection management

### Timeouts:
- **Expert Execution**: 120 seconds per expert
- **Chat Completions**: 120 seconds
- **Embeddings**: 30 seconds
- **WebSocket**: Phoenix default (no explicit timeout)

### Memory Usage:
- **ETS Table**: Stores all document chunks and embeddings
- **LiveView State**: Maintains session state and log messages
- **Concurrent Tasks**: Each expert runs in separate process

## Error Handling

### Expert Failures:
- Individual expert errors don't crash the system
- Error messages are included in results
- Logging captures detailed error information

### API Failures:
- OpenAI API errors are caught and logged
- Fallback behavior for missing API keys
- Graceful degradation when services are unavailable

### RAG System:
- Automatic index loading on startup
- Clear error messages for missing index
- Fallback to empty results if search fails

## Security Considerations

### API Key Management:
- Environment variable storage
- No hardcoded credentials
- Production-ready configuration

### Input Validation:
- Sanitized user input
- SQL injection protection (N/A - no database)
- XSS protection via Phoenix LiveView

### Rate Limiting:
- No built-in rate limiting
- Relies on OpenAI's API limits
- Could be added at the LiveView level

## Monitoring and Observability

### Logging:
- Real-time activity logging
- Expert execution tracking
- Token usage monitoring
- Error capture and reporting

### Metrics:
- Phoenix LiveDashboard integration
- Telemetry events for performance monitoring
- Custom metrics for expert selection and execution

### Debugging:
- LiveView state inspection
- Process monitoring via LiveDashboard
- Detailed error messages with stack traces

## Future Enhancements

### Potential Improvements:
1. **Neural Gate**: Replace keyword matching with trained neural network
2. **Dynamic Expert Loading**: Load experts from external modules
3. **Caching**: Add Redis caching for frequent queries
4. **Rate Limiting**: Implement user-based rate limiting
5. **Analytics**: Track expert usage and performance metrics
6. **Multi-modal**: Support for image and document uploads
7. **Streaming**: Real-time streaming of expert responses

### Scalability Considerations:
- **Horizontal Scaling**: Multiple Phoenix nodes with shared state
- **Database Integration**: Persistent storage for logs and metrics
- **Load Balancing**: Distribute expert execution across nodes
- **Caching Layer**: Redis for session state and results

This architecture provides a solid foundation for a production-ready MoE system while maintaining simplicity and extensibility.
