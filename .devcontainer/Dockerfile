FROM crystallang/crystal:1.19

# Set environment variables
ENV APP_ENV=development
ENV TZ=America/Chicago
ENV DEBIAN_FRONTEND=noninteractive
# Define PATH without $HOME since it's not defined yet
ENV PATH="/workspaces/quickheadlines/bin:/home/vscode/.local/bin:/home/vscode/.npm-global/bin:${PATH}"

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
    pkg-config

# Install Node.js 22 (required for beads-ui)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs

# Create vscode user with sudo privileges
# Use UID 1001 to avoid conflict with crystal user (UID 1000)
RUN groupadd --gid 1001 vscode \
    && useradd --uid 1001 --gid vscode --shell /bin/bash --create-home vscode \
    && echo vscode ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/vscode \
    && chmod 0440 /etc/sudoers.d/vscode

# Create symlink for /bin/bd to point to /workspaces/quickheadlines/bin/bd
RUN ln -sf /workspaces/quickheadlines/bin/bd /bin/bd

# Set working directory
WORKDIR /workspaces/quickheadlines

# Change ownership of work directory to vscode user
RUN chown vscode:vscode /workspaces/quickheadlines

# Copy shard files first to cache dependencies
COPY shard.yml shard.lock ./

# Install Crystal dependencies
RUN shards install && chown -R vscode:vscode /workspaces/quickheadlines

# Copy package files for npm dependencies
COPY package.json package-lock.json ./

# Install npm dependencies (Playwright)
RUN npm install && chown -R vscode:vscode /workspaces/quickheadlines

# Install Playwright system dependencies
RUN npx playwright install --with-deps chromium

# Install Elm for ARM64
RUN curl -L -o elm.gz https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz && \
    gunzip elm.gz && \
    chmod +x elm && \
    mv elm /usr/local/bin/elm && \
    echo "✅ Elm installed successfully: $(elm --version)"

# Install elm-format
RUN npm install -g elm-format

# Install beads-ui (requires Node >=22)
RUN npm install -g beads-ui

# Install spec-kitty-cli using pipx
RUN pipx install spec-kitty-cli && \
    echo "✅ spec-kitty-cli installed successfully"

# Configure npm to use user-local directory to avoid EACCES errors
RUN mkdir -p /home/vscode/.npm-global && \
    chown -R vscode:vscode /home/vscode/.npm-global && \
    echo 'export PATH=/home/vscode/.npm-global/bin:$PATH' >> /home/vscode/.bashrc

# Copy rest of application
COPY --chown=vscode:vscode . .

# Expose default port
EXPOSE 3000

# Switch to vscode user
USER vscode

# Command to keep container running for development
CMD ["sleep", "infinity"]
