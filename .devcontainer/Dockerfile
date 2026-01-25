FROM crystallang/crystal:1.19

# Set environment variables
ENV APP_ENV=development
ENV TZ=America/Chicago
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/workspaces/quickheadlines/bin:/home/vscode/.local/bin:/home/vscode/.npm-global/bin:${PATH}"
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# Configure fast apt mirrors for faster downloads (ARM64 compatible)
RUN rm -rf /var/lib/apt/lists/* && \
    echo "=== Configuring fast Ubuntu mirrors === " && \
    echo "deb http://ports.ubuntu.com/ubuntu-ports noble main" > /etc/apt/sources.list && \
    echo "deb http://ports.ubuntu.com/ubuntu-ports noble-updates main" >> /etc/apt/sources.list && \
    echo "deb http://ports.ubuntu.com/ubuntu-ports noble-backports main" >> /etc/apt/sources.list && \
    echo "deb http://ports.ubuntu.com/ubuntu-ports noble-security main" >> /etc/apt/sources.list && \
    apt-get update -y --no-install-recommends

# Install required packages
RUN apt-get update -y --no-install-recommends && apt-get install -y --no-install-recommends \
    protobuf-compiler \
    libprotobuf-dev \
    sqlite3 \
    libsqlite3-dev \
    libssl-dev \
    libmagic-dev \
    git \
    curl \
    bash \
    build-essential \
    golang \
    python3-pip \
    python3-venv \
    pipx \
    sudo \
    pkg-config \
    tzdata \
    locales

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

# Install Node.js 22 (required for beads-ui)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs

# Create vscode user with sudo privileges
# Use UID 1001 to avoid conflict with crystal user (UID 1000)
RUN groupadd --gid 1001 vscode \
    && useradd --uid 1001 --gid vscode --shell /bin/bash --create-home vscode \
    && echo 'vscode ALL=\(root\) NOPASSWD: ALL' > /etc/sudoers.d/vscode \
    && chmod 0440 /etc/sudoers.d/vscode

# Configure npm to use user-local directory to avoid EACCES errors (MUST be before npm install -g)
RUN mkdir -p /home/vscode/.npm-global && \
    chown -R 1001:1001 /home/vscode/.npm-global && \
    npm config set prefix '/home/vscode/.npm-global' && \
    echo 'export PATH=/home/vscode/.npm-global/bin:$PATH' >> /home/vscode/.bashrc

# Create symlink for /bin/bd to point to /workspaces/quickheadlines/bin/bd
RUN ln -sf /workspaces/quickheadlines/bin/bd /bin/bd

# Set working directory
WORKDIR /workspaces/quickheadlines

# Change ownership of work directory to vscode user
RUN chown vscode:vscode /workspaces/quickheadlines

# Copy shard files first to cache dependencies (if they exist)
RUN if [ -f shard.yml ]; then \
    cp shard.yml shard.lock . 2>/dev/null || cp shard.yml .; \
    shards install; \
    fi && chown -R vscode:vscode /workspaces/quickheadlines

# Copy package files for npm dependencies (if they exist)
RUN if [ -f package.json ]; then \
    cp package.json package-lock.json . 2>/dev/null || cp package.json .; \
    npm install; \
    npx playwright install --with-deps chromium 2>/dev/null || true; \
    fi && chown -R vscode:vscode /workspaces/quickheadlines

# Install Elm and tools using ARM64-compatible community wrappers
RUN if command -v npm &> /dev/null; then \
    # We use @lydell/elm because it provides native ARM64 binaries for Linux/Mac
    npm install -g @lydell/elm elm-format elm-test elm-review; \
    # Link 'elm' to the lydell version so your scripts remain compatible
    ln -sf /home/vscode/.npm-global/bin/elm /home/vscode/.npm-global/bin/elm-native; \
    echo "✅ Elm (ARM64 compatible) installed via npm: $(elm --version)"; \
    fi

# Install elm-format via npm (architecture-independent)
RUN if [ -f package.json ]; then \
    npm install -g elm-format; \
    fi

# Install beads-ui (if package.json exists, requires Node >=22)
RUN if [ -f package.json ]; then \
    npm install -g beads-ui; \
    fi

# Install Go tools (bd - Beads task manager)
# Install to /go/bin to leverage Docker layer caching
RUN export GOPATH=/go && \
    export PATH=$PATH:$GOPATH/bin && \
    go install github.com/steveyegge/beads/cmd/bd@latest && \
    echo "✅ bd installed: $(bd --version 2>/dev/null || echo 'version unknown')"

# Install spec-kitty-cli using pipx
RUN pipx install spec-kitty-cli && \
    echo "✅ spec-kitty-cli installed successfully"

# Copy rest of application
COPY --chown=vscode:vscode . .

# Expose default port
EXPOSE 3000

# Switch to vscode user
USER vscode

# Command to keep container running for development
CMD ["sleep", "infinity"]
