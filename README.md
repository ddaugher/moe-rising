# MoeRising - Mixture of Experts Demo

A Phoenix LiveView application that demonstrates a Mixture of Experts (MoE) system with attention-based routing. The system analyzes user prompts and routes them to specialized experts (RAG, Writing, Code, Math, DataViz) based on keyword matching and probability scoring.

## Features

- **Attention-based Expert Routing**: Uses keyword matching and softmax normalization to route queries to the most relevant experts
- **Real-time Processing Visualization**: Shows the 6-step attention process flow with live updates
- **Multiple Expert Types**: 
  - **RAG**: Retrieval-Augmented Generation using augustwenty documentation with semantic search and citations
  - **Writing**: Content creation and explanation
  - **Code**: Programming and technical assistance
  - **Math**: Mathematical reasoning and calculations
  - **DataViz**: Data visualization and charting
- **Interactive UI**: Phoenix LiveView interface with real-time updates and activity logging
- **Real-time Logging System**: File-based logging system that captures expert processing steps and displays them in the activity log
- **Advanced Aggregation**: Uses an LLM judge to intelligently combine results from multiple experts

## Prerequisites

Before you begin, ensure you have the following installed:

### Required Software

1. **Elixir** (version 1.17 or later)
2. **Erlang/OTP** (version 26 or later)
3. **Node.js** (version 18 or later) - for asset compilation
4. **Git** - for cloning the repository

**Recommended**: Use [asdf](https://asdf-vm.com/) for version management. This allows you to easily switch between different versions of Elixir, Erlang, and Node.js for different projects.

### Installation Instructions

#### macOS (using asdf)

```bash
# Install asdf using Homebrew (macOS-specific)
brew install asdf

# Add asdf to your shell profile (macOS uses zsh by default)
echo -e '\n. $(brew --prefix asdf)/libexec/asdf.sh' >> ~/.zshrc
source ~/.zshrc

# Install required plugins
asdf plugin add erlang
asdf plugin add elixir
asdf plugin add nodejs

# Install specific versions (or use 'asdf install' after cloning the repo)
asdf install erlang 26.2.2
asdf install elixir 1.17.2-otp-26
asdf install nodejs 18.20.4

# Set global versions
asdf global erlang 26.2.2
asdf global elixir 1.17.2-otp-26
asdf global nodejs 18.20.4

# Verify installations
elixir --version
node --version
```

**macOS Notes:**
- Uses Homebrew for asdf installation
- Default shell is zsh (add to `~/.zshrc`)
- May need Xcode Command Line Tools: `xcode-select --install`

#### Ubuntu/Debian (using asdf)

```bash
# Install system dependencies for asdf and Erlang compilation
sudo apt-get update
sudo apt-get install curl git build-essential autoconf m4 libncurses5-dev \
  libwxgtk3.2-dev libwxgtk-webview3.2-dev libgl1-mesa-dev libglu1-mesa-dev \
  libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils \
  libncurses-dev openjdk-11-jdk

# Install asdf from source (Linux-specific)
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0

# Add asdf to your shell profile (Linux typically uses bash)
echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bashrc
echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc
source ~/.bashrc

# Install required plugins
asdf plugin add erlang
asdf plugin add elixir
asdf plugin add nodejs

# Install specific versions (or use 'asdf install' after cloning the repo)
asdf install erlang 26.2.2
asdf install elixir 1.17.2-otp-26
asdf install nodejs 18.20.4

# Set global versions
asdf global erlang 26.2.2
asdf global elixir 1.17.2-otp-26
asdf global nodejs 18.20.4

# Verify installations
elixir --version
node --version
```

**Linux Notes:**
- Installs asdf from source (no package manager)
- Default shell is bash (add to `~/.bashrc`)
- Requires additional build dependencies for Erlang compilation
- May need to install Java for some Erlang dependencies

#### Windows

1. **Elixir**: Download and install from [elixir-lang.org](https://elixir-lang.org/install.html#windows)
2. **Node.js**: Download and install from [nodejs.org](https://nodejs.org/)

## Environment Variables

The application requires the following environment variables:

### Required

- `OPENAI_API_KEY`: Your OpenAI API key for LLM and embedding services

### Optional

- `MOE_LLM_MODEL`: OpenAI model for chat completions (default: "gpt-5")
- `MOE_EMBED_MODEL`: OpenAI model for embeddings (default: "text-embedding-3-small")
- `PORT`: Port for the web server (default: 4000)

### Setting Environment Variables

#### Development (macOS/Linux)

Create a `.env` file in the project root:

```bash
# .env
export OPENAI_API_KEY="your-openai-api-key-here"
export MOE_LLM_MODEL="gpt-4"  # Optional
export MOE_EMBED_MODEL="text-embedding-3-small"  # Optional
export PORT="4000"  # Optional
```

Then source it before running the application:

```bash
source .env
```

#### Windows

Set environment variables in PowerShell:

```powershell
$env:OPENAI_API_KEY="your-openai-api-key-here"
$env:MOE_LLM_MODEL="gpt-4"  # Optional
$env:MOE_EMBED_MODEL="text-embedding-3-small"  # Optional
$env:PORT="4000"  # Optional
```

## Installation and Setup

1. **Clone the repository**

```bash
git clone https://github.com/ddaugher/moe-rising.git
cd moe-rising
```

2. **Install dependencies**

```bash
# If using asdf, install the correct versions automatically
# This will read the .tool-versions file and install the specified versions
asdf install

# Install Elixir dependencies
mix deps.get

# Install and setup assets (Node.js dependencies)
mix assets.setup
```

**Note**: This project includes a `.tool-versions` file that specifies the exact versions of Elixir, Erlang, and Node.js. If you're using asdf, it will automatically install these versions when you run `asdf install`.

3. **Build assets**

```bash
mix assets.build
```

4. **Build the RAG index**

The RAG expert requires a pre-built index of the augustwenty documentation:

```bash
mix moe.rag.build
```

This will process all markdown files in `priv/a20_docs/` and create a searchable index at `priv/a20_index.json`.

5. **Set up environment variables**

Create your `.env` file with the required environment variables (see Environment Variables section above).

6. **Verify setup**

```bash
# Run tests to ensure everything is working
mix test

# Run precommit checks (formatting, linting, tests)
mix precommit
```

## Running the Application

### Development Mode

1. **Start the Phoenix server**

```bash
# Option 1: Start with console output logging (recommended for demos)
./start_with_console_log.sh

# Option 2: Start with mix (standard development)
mix phx.server

# Option 3: Start with IEx (Interactive Elixir) for debugging
iex -S mix phx.server
```

**Note**: The `start_with_console_log.sh` script redirects all console output to `console_output.log`, which allows the activity log to display real-time console output. This is particularly useful for live demos to show that the system is actively processing.

#### Console Output Logging

For live demos or when you want to see all console output in the activity log:

```bash
# Make the script executable (first time only)
chmod +x start_with_console_log.sh

# Start with console output logging
./start_with_console_log.sh
```

This script:
- Redirects all Phoenix server output to `console_output.log`
- Uses `tee` to display output in the terminal AND save to file
- Allows the activity log to show real-time console output
- Perfect for demonstrating that the system is actively processing

2. **Access the application**

Open your browser and navigate to: [http://localhost:4000](http://localhost:4000)

The application will be available at the root path (`/`) and the MoE demo at `/moe`.

### Production Mode

1. **Generate a secret key**

```bash
mix phx.gen.secret
```

2. **Set production environment variables**

```bash
export SECRET_KEY_BASE="your-generated-secret-key"
export PHX_HOST="your-domain.com"
export OPENAI_API_KEY="your-openai-api-key"
```

3. **Build for production**

```bash
# Build assets for production
mix assets.deploy

# Create a release
MIX_ENV=prod mix release
```

4. **Run the production release**

```bash
# Start the server
PHX_SERVER=true bin/moe_rising start
```

## Project Structure

```
moe-rising/
├── lib/
│   ├── moe_rising/           # Core application logic
│   │   ├── gate.ex          # Attention mechanism and expert scoring
│   │   ├── router.ex        # Expert routing logic with LLM aggregation
│   │   ├── llm_client.ex    # OpenAI API client
│   │   ├── logging.ex       # File-based logging system
│   │   ├── console_watcher.ex # Console output file monitoring
│   │   ├── experts/         # Expert implementations
│   │   │   ├── rag.ex       # RAG expert with semantic search
│   │   │   ├── writing.ex   # Writing expert
│   │   │   ├── code.ex      # Code expert
│   │   │   ├── math.ex      # Math expert
│   │   │   └── dataviz.ex   # Data visualization expert
│   │   └── rag/             # RAG system components
│   │       ├── store.ex     # In-memory ETS store for chunks
│   │       ├── indexer.ex   # Document indexing and chunking
│   │       └── chunker.ex   # Text chunking utilities
│   ├── mix/tasks/           # Custom Mix tasks
│   │   └── moe_rag_build.ex # RAG index building task
│   └── moe_rising_web/      # Web layer
│       ├── live/            # LiveView components
│       └── components/      # Reusable components
├── assets/                  # Frontend assets
│   ├── css/                # Stylesheets
│   └── js/                 # JavaScript
├── config/                 # Configuration files
├── priv/                   # Private assets
│   ├── a20_docs/          # Documentation for RAG (markdown files)
│   ├── a20_index.json     # Built RAG index
│   └── static/            # Static assets
└── test/                  # Test files
```

## How It Works

### Attention Mechanism

The system uses a 6-step attention process:

1. **Input Analysis**: Parse and tokenize the user's prompt
2. **Keyword Matching**: Count expert-specific keywords in the prompt
3. **Score Calculation**: Apply formula: `base_weight × (1 + keyword_matches)`
4. **Softmax Normalization**: Convert raw scores to probabilities
5. **Expert Selection**: Route to top-k experts based on probabilities
6. **Aggregate Results**: Use LLM judge to intelligently combine expert results

### Expert Types

- **RAG**: Specialized in augustwenty documentation and business queries with semantic search and source citations
- **Writing**: Content creation, explanations, and prose
- **Code**: Programming, technical assistance, and development
- **Math**: Mathematical reasoning, calculations, and analysis
- **DataViz**: Data visualization, charts, and visual encoding

### RAG System

The RAG (Retrieval-Augmented Generation) expert uses a sophisticated document indexing and search system:

1. **Document Processing**: All markdown files in `priv/a20_docs/` are processed and chunked
2. **Embedding Generation**: Each chunk is converted to a vector embedding using OpenAI's embedding model
3. **Index Storage**: Chunks and embeddings are stored in an in-memory ETS table for fast retrieval
4. **Semantic Search**: User queries are embedded and matched against document chunks using cosine similarity
5. **Source Citations**: Results include inline citations and a sources list for transparency

### Logging System

The application includes a file-based logging system that:
- Writes all log messages to `console_output.log`
- Uses a `ConsoleWatcher` GenServer to monitor the log file
- Sends new log content to LiveView processes in real-time
- Tracks token usage, processing times, and error states
- Provides detailed debugging information for development
- Works with the `start_with_console_log.sh` script to capture all console output

## Development

### Running Tests

```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover

# Run specific test file
mix test test/moe_rising_web/live/rising_live_test.exs
```

### Code Quality

```bash
# Format code
mix format

# Run precommit checks (format, test, compile)
mix precommit

# Check for unused dependencies
mix deps.unlock --unused
```

### Adding New Experts

1. Create a new expert module in `lib/moe_rising/experts/`
2. Implement the `MoeRising.Expert` behaviour
3. Add the expert to the `@experts` list in `lib/moe_rising/gate.ex`
4. Add the expert to the router in `lib/moe_rising/router.ex`

### Building the RAG Index

To rebuild the RAG index after adding or modifying documents:

```bash
# Build the index from scratch
mix moe.rag.build

# The index will be saved to priv/a20_index.json
```

The RAG system will automatically load the index when the application starts.

## Troubleshooting

### Common Issues

1. **"OPENAI_API_KEY is missing" error**
   - Ensure you've set the `OPENAI_API_KEY` environment variable
   - Verify the API key is valid and has sufficient credits

2. **Asset compilation errors**
   - Ensure Node.js is installed and up to date
   - Run `mix assets.setup` to reinstall asset dependencies

3. **Port already in use**
   - Change the port using `export PORT=4001` (or another available port)
   - Or kill the process using the port: `lsof -ti:4000 | xargs kill -9`

4. **Dependencies issues**
   - Run `mix deps.clean --all` and `mix deps.get` to reinstall dependencies
   - Ensure you're using the correct Elixir/Erlang versions

5. **RAG index not found**
   - Run `mix moe.rag.build` to build the RAG index
   - Ensure the `priv/a20_docs/` directory contains markdown files
   - Check that `priv/a20_index.json` exists after building

6. **RAG expert not working**
   - Verify the RAG index is built and loaded
   - Check that the `MOE_EMBED_MODEL` environment variable is set correctly
   - Ensure OpenAI API key has sufficient credits for embedding requests

7. **Activity log not showing console output**
   - Ensure you're using `./start_with_console_log.sh` to start the server
   - Check that `console_output.log` file exists and has content
   - Verify that you have an active LiveView session (visit `/moe` page)
   - The ConsoleWatcher polls every 500ms, so there may be a slight delay

### Getting Help

- Check the [Phoenix documentation](https://hexdocs.pm/phoenix/overview.html)
- Visit the [Elixir Forum](https://elixirforum.com/c/phoenix-forum)
- Review the [LiveView documentation](https://hexdocs.pm/phoenix_live_view/)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Acknowledgments

- Built with [Phoenix Framework](https://www.phoenixframework.org/)
- Uses [OpenAI API](https://openai.com/api/) for LLM services
- Styled with [Tailwind CSS](https://tailwindcss.com/)
- Icons from [Heroicons](https://heroicons.com/)