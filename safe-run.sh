#!/bin/bash
# safe-run.sh - Generic Safe Build and Run Script with Anti-Freeze Pattern
# Supports Crystal, Nim, Elixir, Gleam, and Elm projects
# Usage: ./safe-run.sh [options]

set -e

# Default configuration
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_OUTPUT=""
LOG_FILE="server.log"
READY_STRING="Listening on"
MAX_WAIT_SECONDS=30
BUILD_ENV="production"
BUILD_FLAGS=""
LANGUAGE=""

# Configuration file path
CONFIG_FILE=".safe-run.conf"

# Parse command-line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -n|--name)
        PROJECT_NAME="$2"
        shift 2
        ;;
      -s|--source)
        SOURCE_FILE="$2"
        shift 2
        ;;
      -o|--output)
        BUILD_OUTPUT="$2"
        shift 2
        ;;
      -l|--log)
        LOG_FILE="$2"
        shift 2
        ;;
      -r|--ready)
        READY_STRING="$2"
        shift 2
        ;;
      -w|--wait)
        MAX_WAIT_SECONDS="$2"
        shift 2
        ;;
      -e|--env)
        BUILD_ENV="$2"
        shift 2
        ;;
      -f|--flags)
        BUILD_FLAGS="$2"
        shift 2
        ;;
      -L|--language)
        LANGUAGE="$2"
        shift 2
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      -v|--version)
        echo "safe-run.sh version 2.0.0"
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

# Show help message
show_help() {
  cat << EOF
safe-run.sh - Generic Safe Build and Run Script

Usage: $0 [options]

Options:
  -n, --name NAME          Project name (auto-detected if not specified)
  -s, --source FILE        Source file path (auto-detected if not specified)
  -o, --output PATH        Build output path (auto-detected if not specified)
  -l, --log FILE           Log file path (default: server.log)
  -r, --ready STRING       Ready string to grep (default: Listening on)
  -w, --wait SECONDS       Max wait time (default: 30)
  -e, --env ENV           Build environment (default: production)
  -f, --flags FLAGS       Additional build flags
  -L, --language LANG     Language (crystal, nim, elixir, gleam, elm)
  -h, --help              Show this help message
  -v, --version           Show version

Configuration File:
  A .safe-run.conf file in project root can set these options:
  PROJECT_NAME, SOURCE_FILE, BUILD_OUTPUT, LOG_FILE, READY_STRING,
  MAX_WAIT_SECONDS, BUILD_ENV, BUILD_FLAGS, LANGUAGE

Examples:
  $0                           # Auto-detect and run
  $0 -n myapp                  # Specify project name
  $0 -s src/main.cr            # Specify source file
  $0 -L crystal -n myapp       # Force Crystal language
  $0 -L elm -n myapp           # Build Elm application
  $0 -w 30 -r "Server ready"   # Custom wait time and ready string

EOF
}

# Load configuration from file
load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    echo "Loading configuration from $CONFIG_FILE..."
    # shellcheck disable=SC1091
    source "$CONFIG_FILE"
    echo "[OK] Configuration loaded"
  fi
}

# Detect project language and settings
detect_language() {
  if [[ -n "$LANGUAGE" ]]; then
    echo "Language specified: $LANGUAGE"
    return
  fi

  if [[ -f "shard.yml" ]]; then
    LANGUAGE="crystal"
  elif [[ -f "gleam.toml" ]]; then
    LANGUAGE="gleam"
  elif [[ -f "mix.exs" ]]; then
    LANGUAGE="elixir"
  elif ls *.nimble &>/dev/null 2>&1; then
    LANGUAGE="nim"
  elif [[ -f "elm.json" ]]; then
    LANGUAGE="elm"
  else
    # Default to Crystal for backward compatibility
    LANGUAGE="crystal"
  fi

  echo "Detected language: $LANGUAGE"
}

# Detect project name from configuration files
detect_project_name() {
  if [[ -n "$PROJECT_NAME" ]]; then
    echo "Project name specified: $PROJECT_NAME"
    return
  fi

  case $LANGUAGE in
    crystal)
      if [[ -f "shard.yml" ]]; then
        PROJECT_NAME=$(grep "^name:" shard.yml | awk '{print $2}' | tr -d ' ')
        echo "Project name from shard.yml: $PROJECT_NAME"
      fi
      ;;
    gleam)
      if [[ -f "gleam.toml" ]]; then
        PROJECT_NAME=$(grep "^name" gleam.toml | awk -F'"' '{print $2}')
        echo "Project name from gleam.toml: $PROJECT_NAME"
      fi
      ;;
    elixir)
      if [[ -f "mix.exs" ]]; then
        PROJECT_NAME=$(grep -E "@app\s+:" mix.exs | awk -F'"' '{print $2}')
        echo "Project name from mix.exs: $PROJECT_NAME"
      fi
      ;;
    nim)
      NIMBLE_FILE=$(ls *.nimble 2>/dev/null | head -1)
      if [[ -n "$NIMBLE_FILE" ]]; then
        PROJECT_NAME=$(grep -E "^package" "$NIMBLE_FILE" | head -1 | awk '{print $2}')
        echo "Project name from $NIMBLE_FILE: $PROJECT_NAME"
      fi
      ;;
    elm)
      if [[ -f "elm.json" ]]; then
        PROJECT_NAME=$(grep -E '"name"' elm.json | head -1 | awk -F'"' '{print $4}')
        echo "Project name from elm.json: $PROJECT_NAME"
      fi
      ;;
  esac

  # Fallback to directory name
  if [[ -z "$PROJECT_NAME" ]]; then
    PROJECT_NAME=$(basename "$PROJECT_DIR")
    echo "Using directory name as project name: $PROJECT_NAME"
  fi
}

# Detect source file
detect_source_file() {
  if [[ -n "$SOURCE_FILE" ]]; then
    echo "Source file specified: $SOURCE_FILE"
    return
  fi

  case $LANGUAGE in
    crystal)
      if [[ -f "src/main.cr" ]]; then
        SOURCE_FILE="src/main.cr"
      elif [[ -f "src/${PROJECT_NAME}.cr" ]]; then
        SOURCE_FILE="src/${PROJECT_NAME}.cr"
      else
        SOURCE_FILE="src/main.cr"
      fi
      echo "Source file: $SOURCE_FILE"
      ;;
    gleam)
      if [[ -f "src/${PROJECT_NAME}.gleam" ]]; then
        SOURCE_FILE="src/${PROJECT_NAME}.gleam"
      else
        SOURCE_FILE="src/main.gleam"
      fi
      echo "Source file: $SOURCE_FILE"
      ;;
    nim)
      if [[ -f "src/${PROJECT_NAME}.nim" ]]; then
        SOURCE_FILE="src/${PROJECT_NAME}.nim"
      else
        SOURCE_FILE="src/main.nim"
      fi
      echo "Source file: $SOURCE_FILE"
      ;;
    elixir)
      # Elixir uses mix release, no single source file
      SOURCE_FILE="mix.exs"
      echo "Source file: mix.exs (Elixir release)"
      ;;
    elm)
      if [[ -f "src/Main.elm" ]]; then
        SOURCE_FILE="src/Main.elm"
      elif [[ -f "src/${PROJECT_NAME}.elm" ]]; then
        SOURCE_FILE="src/${PROJECT_NAME}.elm"
      else
        SOURCE_FILE="src/Main.elm"
      fi
      echo "Source file: $SOURCE_FILE"
      ;;
  esac
}

# Detect build output path
detect_build_output() {
  if [[ -n "$BUILD_OUTPUT" ]]; then
    echo "Build output specified: $BUILD_OUTPUT"
    return
  fi

  case $LANGUAGE in
    crystal)
      BUILD_OUTPUT="bin/${PROJECT_NAME}"
      ;;
    gleam)
      BUILD_OUTPUT="build/dev/javascript/${PROJECT_NAME}"
      ;;
    nim)
      BUILD_OUTPUT="bin/${PROJECT_NAME}"
      ;;
    elixir)
      BUILD_OUTPUT="_build/${BUILD_ENV}/rel/${PROJECT_NAME}"
      ;;
    elm)
      if [[ -d "public" ]]; then
        BUILD_OUTPUT="public/elm.js"
      elif [[ -d "dist" ]]; then
        BUILD_OUTPUT="dist/elm.js"
      else
        BUILD_OUTPUT="elm.js"
      fi
      ;;
  esac

  echo "Build output: $BUILD_OUTPUT"
}

# Get build command based on language
get_build_command() {
  case $LANGUAGE in
    crystal)
      echo "crystal build \"$SOURCE_FILE\" -o \"$BUILD_OUTPUT\" $BUILD_FLAGS"
      ;;
    gleam)
      echo "gleam build --target javascript"
      ;;
    nim)
      echo "nim c -o:\"$BUILD_OUTPUT\" $BUILD_FLAGS \"$SOURCE_FILE\""
      ;;
    elixir)
      echo "MIX_ENV=$BUILD_ENV mix release"
      ;;
    elm)
      if [[ "$BUILD_ENV" == "development" ]]; then
        echo "elm make \"$SOURCE_FILE\" --output=\"$BUILD_OUTPUT\" --debug"
      else
        echo "elm make \"$SOURCE_FILE\" --output=\"$BUILD_OUTPUT\" --optimize"
      fi
      ;;
  esac
}

# Kill existing processes for project
cleanup_processes() {
  echo "Cleaning up existing processes..."
  
  # Kill by project name
  if [[ -n "$PROJECT_NAME" ]]; then
    pkill -9 -f "$PROJECT_NAME" 2>/dev/null || true
  fi
  
  # Kill by build output
  if [[ -n "$BUILD_OUTPUT" ]]; then
    pkill -9 -f "$BUILD_OUTPUT" 2>/dev/null || true
  fi
  
  # Kill by source file
  if [[ -n "$SOURCE_FILE" ]]; then
    pkill -9 -f "crystal run.*$SOURCE_FILE" 2>/dev/null || true
    pkill -9 -f "nim.*$SOURCE_FILE" 2>/dev/null || true
  fi
  
  # Language-specific process cleanup
  case $LANGUAGE in
    crystal)
      pkill -9 -f "crystal run" 2>/dev/null || true
      ;;
    nim)
      pkill -9 -f "nim.*c" 2>/dev/null || true
      ;;
    elixir)
      pkill -9 -f "beam" 2>/dev/null || true
      ;;
  esac
  
  sleep 1
  echo "Cleanup complete"
}

# Clean up old artifacts
cleanup_artifacts() {
  echo "Cleaning up old artifacts..."
  rm -f "$LOG_FILE" 2>/dev/null || true
  rm -f "$BUILD_OUTPUT" 2>/dev/null || true
  rm -f "erl_crash.dump" 2>/dev/null || true
  echo "Cleanup complete"
}

# Build application
build_app() {
  echo "Building ${PROJECT_NAME}..."
  
  BUILD_CMD=$(get_build_command)
  echo "Build command: $BUILD_CMD"
  
  cd "$PROJECT_DIR"
  
  if eval "$BUILD_CMD" > /tmp/build_output.log 2>&1; then
    echo "Build completed successfully"
  else
    echo "Build failed!"
    echo "Build output:"
    cat /tmp/build_output.log
    exit 1
  fi
}

# Start application with Anti-Freeze pattern
start_app() {
  # Elm doesn't have a server process - it runs in browser
  if [[ "$LANGUAGE" == "elm" ]]; then
    echo "Elm build complete: $BUILD_OUTPUT"
    echo "Open this file in your browser to view the application."
    return 0
  fi
  
  echo "Starting ${PROJECT_NAME} with Anti-Freeze pattern..."
  
  cd "$PROJECT_DIR"
  
  # Double-fork pattern to prevent zombie processes
  (
    (nohup "$BUILD_OUTPUT" > "$LOG_FILE" 2>&1 &)
  ) &
  
  echo "Application started in background"
}

# Wait for server to be ready
wait_for_ready() {
  # Elm doesn't have a server to wait for
  if [[ "$LANGUAGE" == "elm" ]]; then
    return 0
  fi
  
  echo "Waiting for server to start (max ${MAX_WAIT_SECONDS} seconds)..."
  
  ATTEMPT=0
  while [[ $ATTEMPT -lt $MAX_WAIT_SECONDS ]]; do
    if grep -q "$READY_STRING" "$LOG_FILE" 2>/dev/null; then
      echo "✓ Server started successfully!"
      echo ""
      echo "Server log:"
      tail -n 5 "$LOG_FILE"
      return 0
    fi
    
    sleep 1
    ATTEMPT=$((ATTEMPT + 1))
    echo "  Attempt ${ATTEMPT}/${MAX_WAIT_SECONDS}..."
  done
  
  # Timeout reached
  echo "✗ ERROR: Server failed to start within ${MAX_WAIT_SECONDS} seconds"
  echo ""
  echo "Last 20 lines of log:"
  tail -n 20 "$LOG_FILE" 2>/dev/null || echo "(no log available)"
  exit 1
}

# Main execution
main() {
  echo "=== Safe Run Script v2.0 ==="
  echo "Project directory: $PROJECT_DIR"
  echo ""
  
  # Parse command-line arguments
  parse_args "$@"
  
  # Load configuration
  load_config
  
  # Detect project settings
  detect_language
  detect_project_name
  detect_source_file
  detect_build_output
  
  echo ""
  
  # Cleanup
  cleanup_processes
  cleanup_artifacts
  
  echo ""
  
  # Build
  build_app
  
  echo ""
  
  # Start
  start_app
  
  echo ""
  
  # Wait for ready
  wait_for_ready
  
  echo ""
  echo "=== Ready to serve! ==="
}

# Run main function
main "$@"
