#!/bin/bash

# Test script for local development
# Run this after starting the Docker container

BASE_URL="http://localhost:8080"

echo "Testing Python Executor Service..."
echo "=================================="
echo ""

# Test 1: Health check
echo "1. Health Check:"
curl -s "$BASE_URL/health" | python3 -m json.tool
echo ""
echo ""

# Test 2: Simple example
echo "2. Simple Example:"
curl -s -X POST "$BASE_URL/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "script": "def main():\n    return {\"message\": \"Hello, World!\", \"status\": \"success\"}"
  }' | python3 -m json.tool
echo ""
echo ""

# Test 3: Example with stdout
echo "3. Example with stdout:"
curl -s -X POST "$BASE_URL/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "script": "def main():\n    print(\"Processing data...\")\n    print(\"Step 1 complete\")\n    return {\"result\": \"done\", \"steps\": 2}"
  }' | python3 -m json.tool
echo ""
echo ""

# Test 4: Pandas and NumPy example
echo "4. Pandas and NumPy Example:"
curl -s -X POST "$BASE_URL/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "script": "import pandas as pd\nimport numpy as np\n\ndef main():\n    data = pd.DataFrame({\"numbers\": [1, 2, 3, 4, 5]})\n    return {\"sum\": int(np.sum(data[\"numbers\"])), \"mean\": float(data[\"numbers\"].mean())}"
  }' | python3 -m json.tool
echo ""
echo ""

# Test 5: Error case - no main function
echo "5. Error Case - No main() function:"
curl -s -X POST "$BASE_URL/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "script": "def other_function():\n    return {\"value\": 42}"
  }' | python3 -m json.tool
echo ""
echo ""

# Test 6: Error case - non-JSON return
echo "6. Error Case - Non-JSON return:"
curl -s -X POST "$BASE_URL/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "script": "def main():\n    return \"plain string\""
  }' | python3 -m json.tool
echo ""
echo ""

echo "=================================="
echo "Testing completed!"

