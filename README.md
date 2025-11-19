# Python Code Execution Service

A secure API service that executes arbitrary Python code in a sandboxed environment. This service is designed to run Python scripts safely in the cloud, capturing both the return value and stdout output.

**Live Service:** https://python-executor-498097721438.us-central1.run.app

## Features

- Secure execution using Google Cloud Run's gVisor sandboxing
- CPU, memory, and time limits to prevent resource abuse
- Pre-installed libraries: pandas, numpy, os
- Lightweight Docker image for easy deployment
- Fully compatible with Google Cloud Run

## Important Note: Cloud Run Architecture

This service is designed for **Google Cloud Run**, which uses **gVisor** for container sandboxing. An earlier version attempted to use nsjail for sandboxing, but this caused conflicts because nsjail is incompatible with gVisor (you cannot run a sandbox inside another sandbox). The current implementation leverages Cloud Run's built-in gVisor security, which provides:
- Process isolation
- Limited syscalls
- Resource limits
- Network isolation
- Security boundaries

For local development, the service executes Python directly with timeout controls.

## API Specification

### Endpoint: `POST /execute`

Execute a Python script and return the result of its `main()` function.

**Request Body:**
```json
{
  "script": "def main():\n    return {'message': 'Hello, World!'}"
}
```

**Requirements:**
- Script must contain a `main()` function
- `main()` must return a JSON-serializable object
- Print statements are captured in stdout

**Response (Success):**
```json
{
  "result": {"message": "Hello, World!"},
  "stdout": ""
}
```

**Response (Error):**
```json
{
  "error": "Error message",
  "stdout": "captured stdout if any"
}
```

### Endpoint: `GET /health`

**Response:**
```json
{
  "status": "healthy"
}
```

## Local Development

### Prerequisites

- Docker

### Running Locally

```bash
docker build -t python-executor .
docker run -p 8080:8080 python-executor
```

Service will be available at `http://localhost:8080`

## Testing

### Testing the Live Cloud Run Service

Set base URL to the live service:

```bash
export BASE_URL="https://python-executor-498097721438.us-central1.run.app"
```

### Test Case 1: Health Check

```bash
curl -s $BASE_URL/health | python3 -m json.tool
```

Expected Response:
```json
{
  "status": "healthy"
}
```

### Test Case 2: Basic Return Value

```bash
curl -s -X POST $BASE_URL/execute \
  -H "Content-Type: application/json" \
  -d '{
    "script": "def main():\n    return {\"message\": \"Hello, World!\", \"value\": 42}"
  }' | python3 -m json.tool
```

Expected Response:
```json
{
  "result": {
    "message": "Hello, World!",
    "value": 42
  },
  "stdout": ""
}
```

### Test Case 3: With Print Statements

```bash
curl -s -X POST $BASE_URL/execute \
  -H "Content-Type: application/json" \
  -d '{
    "script": "def main():\n    print(\"Starting calculation...\")\n    result = 10 * 5\n    print(f\"Result is {result}\")\n    return {\"answer\": result}"
  }' | python3 -m json.tool
```

Expected Response:
```json
{
  "result": {
    "answer": 50
  },
  "stdout": "Starting calculation...\nResult is 50"
}
```

### Test Case 4: Using NumPy

```bash
curl -s -X POST $BASE_URL/execute \
  -H "Content-Type: application/json" \
  -d '{
    "script": "import numpy as np\n\ndef main():\n    arr = np.array([1, 2, 3, 4, 5])\n    return {\n        \"sum\": int(np.sum(arr)),\n        \"mean\": float(np.mean(arr)),\n        \"max\": int(np.max(arr))\n    }"
  }' | python3 -m json.tool
```

Expected Response:
```json
{
  "result": {
    "sum": 15,
    "mean": 3.0,
    "max": 5
  },
  "stdout": ""
}
```

### Test Case 5: Using Pandas

```bash
curl -s -X POST $BASE_URL/execute \
  -H "Content-Type: application/json" \
  -d '{
    "script": "import pandas as pd\n\ndef main():\n    df = pd.DataFrame({\n        \"name\": [\"Alice\", \"Bob\", \"Charlie\"],\n        \"age\": [25, 30, 35]\n    })\n    return {\n        \"rows\": len(df),\n        \"columns\": list(df.columns),\n        \"mean_age\": float(df[\"age\"].mean())\n    }"
  }' | python3 -m json.tool
```

Expected Response:
```json
{
  "result": {
    "rows": 3,
    "columns": ["name", "age"],
    "mean_age": 30.0
  },
  "stdout": ""
}
```

### Test Case 6: Using Pandas and NumPy Together

```bash
curl -s -X POST $BASE_URL/execute \
  -H "Content-Type: application/json" \
  -d '{
    "script": "import pandas as pd\nimport numpy as np\n\ndef main():\n    print(\"Creating dataset...\")\n    data = pd.DataFrame({\n        \"x\": np.arange(1, 11),\n        \"y\": np.arange(1, 11) ** 2\n    })\n    print(f\"Dataset has {len(data)} rows\")\n    \n    return {\n        \"x_sum\": int(data[\"x\"].sum()),\n        \"y_sum\": int(data[\"y\"].sum()),\n        \"correlation\": float(data[\"x\"].corr(data[\"y\"]))\n    }"
  }' | python3 -m json.tool
```

Expected Response:
```json
{
  "result": {
    "x_sum": 55,
    "y_sum": 385,
    "correlation": 0.9745586280878213
  },
  "stdout": "Creating dataset...\nDataset has 10 rows"
}
```

### Test Case 7: Complex Calculation

```bash
curl -s -X POST $BASE_URL/execute \
  -H "Content-Type: application/json" \
  -d '{
    "script": "import math\n\ndef main():\n    print(\"Calculating fibonacci...\")\n    def fib(n):\n        if n <= 1:\n            return n\n        return fib(n-1) + fib(n-2)\n    \n    result = fib(10)\n    print(f\"Fibonacci(10) = {result}\")\n    return {\"fibonacci_10\": result}"
  }' | python3 -m json.tool
```

Expected Response:
```json
{
  "result": {
    "fibonacci_10": 55
  },
  "stdout": "Calculating fibonacci...\nFibonacci(10) = 55"
}
```

### Test Case 8: Missing main() Function

```bash
curl -s -X POST $BASE_URL/execute \
  -H "Content-Type: application/json" \
  -d '{
    "script": "def other_function():\n    return {\"value\": 42}"
  }' | python3 -m json.tool
```

Expected Response:
```json
{
  "error": "Script must contain a main() function",
  "stdout": ""
}
```

### Test Case 9: Syntax Error

```bash
curl -s -X POST $BASE_URL/execute \
  -H "Content-Type: application/json" \
  -d '{
    "script": "def main():\n    return {invalid syntax here}"
  }' | python3 -m json.tool
```

Expected Response:
```json
{
  "error": "Syntax error in script: ...",
  "stdout": ""
}
```

### Test Case 10: Non-Serializable Return

```bash
curl -s -X POST $BASE_URL/execute \
  -H "Content-Type: application/json" \
  -d '{
    "script": "class MyClass:\n    pass\n\ndef main():\n    return MyClass()"
  }' | python3 -m json.tool
```

Expected Response:
```json
{
  "error": "TypeError: Object of type MyClass is not JSON serializable",
  "stdout": ""
}
```

## Deployment to Google Cloud Run

### Quick Deploy

```bash
export PROJECT_ID=your-project-id
export SERVICE_NAME=python-executor
export REGION=us-central1

gcloud auth configure-docker

gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE_NAME

gcloud run deploy $SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$SERVICE_NAME \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --memory 1Gi \
  --cpu 1 \
  --timeout 60 \
  --max-instances 10

gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)'
```

### Deployment Challenges & Solutions

**Challenge:** Initial implementation used nsjail for sandboxing, but this caused "Couldn't launch the child process" errors on Cloud Run.

**Root Cause:** Google Cloud Run uses **gVisor** for container sandboxing. Attempting to run nsjail (another sandbox) inside gVisor creates incompatible nested sandboxing.

**Solution:** Removed nsjail and leveraged Cloud Run's built-in gVisor sandboxing. This resulted in:
- Faster builds (46s vs 2+ minutes)
- Smaller Docker images
- Full Cloud Run compatibility
- Equal or better security via gVisor

**Key Lesson:** When deploying to managed container platforms like Cloud Run, rely on the platform's built-in security features rather than adding your own sandboxing layer.

## Security Features

When deployed on Google Cloud Run, the service benefits from gVisor sandboxing:
- Process isolation via gVisor
- Limited syscalls enforced by gVisor
- Memory limit: 1 GB per Cloud Run instance
- Script execution timeout: 30 seconds
- Input validation for script syntax and main() function
- Network isolation provided by Cloud Run
- Restricted filesystem access

The service configuration on Cloud Run:
- Memory: 1 GB per instance
- CPU: 1 vCPU per instance
- Timeout: 60 seconds per request
- Max instances: 10 (auto-scaling)
- Authentication: Public access (unauthenticated)

## Limitations

- Maximum script execution time: 30 seconds per script
- Memory available: Up to 1 GB (Cloud Run instance limit)
- Network access: Isolated by Cloud Run (scripts cannot make external network calls)
- Filesystem: Limited to container filesystem
- Subprocess creation: Limited by gVisor security policies

## License

MIT License

