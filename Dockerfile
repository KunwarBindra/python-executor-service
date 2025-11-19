# Use Python slim image for smaller size
FROM python:3.11-slim

# Install nsjail dependencies and build tools
RUN apt-get update && apt-get install -y \
    autoconf \
    bison \
    flex \
    gcc \
    g++ \
    git \
    libnl-route-3-dev \
    libtool \
    make \
    pkg-config \
    protobuf-compiler \
    libprotobuf-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone and build nsjail
RUN git clone --depth 1 https://github.com/google/nsjail.git /nsjail && \
    cd /nsjail && \
    make && \
    mv /nsjail/nsjail /usr/bin/nsjail && \
    rm -rf /nsjail

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Create temp directory for script execution
RUN mkdir -p /tmp && chmod 1777 /tmp

# Expose port 8080
EXPOSE 8080

# Use gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--threads", "4", "--timeout", "60", "app:app"]

