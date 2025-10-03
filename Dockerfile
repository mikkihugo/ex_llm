FROM oven/bun:1 as base
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install gcloud CLI for Gemini ADC
RUN curl https://sdk.cloud.google.com | bash && \
    /root/google-cloud-sdk/bin/gcloud --version

# Copy package files
COPY package.json bun.lockb ./

# Install dependencies
RUN bun install --frozen-lockfile

# Copy application code
COPY . .

# Expose port
EXPOSE 3000

# Set environment
ENV PATH="/root/google-cloud-sdk/bin:${PATH}"
ENV PORT=3000

# Run the server
CMD ["bun", "run", "tools/ai-server.ts"]
