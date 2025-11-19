# Python Code Execution Service

A secure API service that executes arbitrary Python code in a sandboxed environment using nsjail. This service is designed to run Python scripts safely in the cloud, capturing both the return value and stdout output.

## Features

- Secure execution using nsjail for sandboxing
- CPU, memory, and time limits to prevent resource abuse
- Pre-installed libraries: pandas, numpy, os
- Lightweight Docker image for easy deployment
- Google Cloud Run compatible

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

Set your base URL:

```bash
export BASE_URL="http://localhost:8080"
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

```bash
export PROJECT_ID=your-project-id
export SERVICE_NAME=python-executor
export REGION=us-central1

gcloud auth configure-docker

docker build -t gcr.io/$PROJECT_ID/$SERVICE_NAME .
docker push gcr.io/$PROJECT_ID/$SERVICE_NAME

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

## Security Features

- Sandboxing with nsjail isolates script execution from host system
- Memory limit: 512 MB per execution
- CPU time limit: 10 seconds
- Wall time limit: 30 seconds
- No new process spawning
- Input validation for script syntax and main() function
- Read-only filesystem except /tmp
- No network access from executed scripts
- Scripts run as unprivileged user 99999

## Limitations

- Maximum execution time: 30 seconds
- Maximum memory: 512 MB
- No network access
- No subprocess creation
- Limited filesystem access

## License

MIT License

