#!/bin/bash
# Test 1: Chat con Gemini (verificar no 404, respuesta texto)
curl -X POST 'http://localhost:4005/v1/chat/completions' \
  -H 'Authorization: Bearer sk-1234567890' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "nano-banana-gemini",
    "messages": [{"role": "user", "content": "Describe una nano banana"}],
    "max_tokens": 100
  }' > chat_test.json
echo "Chat test output: $(cat chat_test.json)"

# Test 2: Image gen con DALL-E (fallback, verificar URL imagen)
curl -X POST 'http://localhost:4005/v1/images/generations' \
  -H 'Authorization: Bearer sk-1234567890' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "dall-e-3",
    "prompt": "Una nano banana en estilo cartoon",
    "n": 1,
    "size": "1024x1024"
  }' > image_test.json
echo "Image test output: $(cat image_test.json)"