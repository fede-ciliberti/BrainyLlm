#!/bin/bash
set -e -E

# =======================================
# Script de Prueba Directa para Gemini API
# =======================================
# Este script hace una llamada directa a la API de Google Gemini para generar imágenes,
# sin usar LiteLLM. Úsalo para verificar que tu API key y modelo funcionan correctamente.
#
# INSTRUCTIVO:
# 1. Reemplaza "TU_API_KEY_AQUI" con tu clave real de GEMINI_API_KEY
# 2. Cambia el PROMPT si quieres probar otro prompt
# 3. Ejecuta: chmod +x test_gemini_direct.sh && ./test_gemini_direct.sh
# 4. La respuesta se guardará en response.json y la imagen en generated_image.png (si se genera)
#
# Basado en el ejemplo oficial de AI Studio (https://aistudio.google.com)
# =======================================

# CONFIGURACIÓN HARDCODEADA - REEMPLAZA CON TUS VALORES
GEMINI_API_KEY="AIzaSyCBzkBm6ogQkUDpfUQhsIK3qxpp6qOE1hs"  # ← REEMPLAZA CON TU CLAVE REAL (e.g., AIzaSyA_AwjCnfQLhRSLLi2A2KqqcBZksjaP9wQ)
MODEL_ID="gemini-2.5-flash-image-preview"
GENERATE_CONTENT_API="streamGenerateContent"
PROMPT="Genera una imagen de un paisaje de montañas nevadas al amanecer con un lago cristalino en primer plano"

echo "🔍 Probando generación de imágenes con Gemini API..."
echo "Modelo: $MODEL_ID"
echo "Prompt: $PROMPT"
echo "API Key: ${GEMINI_API_KEY:0:10}..."  # Muestra solo los primeros 10 chars por seguridad

# Validar que la API key no esté vacía
if [[ "$GEMINI_API_KEY" == "TU_API_KEY_AQUI" ]] || [[ -z "$GEMINI_API_KEY" ]]; then
    echo "❌ ERROR: Reemplaza 'TU_API_KEY_AQUI' en la línea 20 con tu clave real de GEMINI_API_KEY"
    echo "   Obtén tu clave en: https://aistudio.google.com/app/apikey"
    exit 1
fi

# Crear el archivo JSON de request
cat << EOF > request.json
{
    "contents": [
      {
        "role": "user",
        "parts": [
          {
            "text": "$PROMPT"
          }
        ]
      }
    ],
    "generationConfig": {
      "responseModalities": ["IMAGE", "TEXT"],
      "temperature": 0.7,
      "topP": 0.8,
      "topK": 40,
      "maxOutputTokens": 100
    },
    "safetySettings": [
      {
        "category": "HARM_CATEGORY_HARASSMENT",
        "threshold": "BLOCK_MEDIUM_AND_ABOVE"
      },
      {
        "category": "HARM_CATEGORY_HATE_SPEECH",
        "threshold": "BLOCK_MEDIUM_AND_ABOVE"
      },
      {
        "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
        "threshold": "BLOCK_MEDIUM_AND_ABOVE"
      },
      {
        "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
        "threshold": "BLOCK_MEDIUM_AND_ABOVE"
      }
    ]
}
EOF

echo "📄 Request JSON creado. Haciendo llamada a la API..."

# Hacer la llamada a la API
RESPONSE_FILE="response.json"
curl \
  -X POST \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  "https://generativelanguage.googleapis.com/v1beta/models/${MODEL_ID}:${GENERATE_CONTENT_API}?alt=sse&key=${GEMINI_API_KEY}" \
  -d '@request.json' \
  --output "$RESPONSE_FILE" \
  --write-out "HTTP Status: %{http_code}\n"

HTTP_STATUS=$(tail -1 "$RESPONSE_FILE")

if [[ "$HTTP_STATUS" != "HTTP Status: 200" ]]; then
    echo "❌ ERROR: La API devolvió un código diferente a 200"
    echo "Respuesta completa:"
    cat "$RESPONSE_FILE"
    rm -f request.json "$RESPONSE_FILE"
    exit 1
fi

echo "✅ Llamada exitosa. Procesando respuesta..."

# Procesar la respuesta (el response de streamGenerateContent es SSE - Server Sent Events)
# Extraer la primera línea de datos válida
FIRST_RESPONSE=$(grep -m1 "data: " "$RESPONSE_FILE" | sed 's/data: //g' | sed 's/\\n/ /g')

if [[ -z "$FIRST_RESPONSE" ]]; then
    echo "⚠️  No se encontró respuesta válida en el stream. Response completo:"
    cat "$RESPONSE_FILE"
    rm -f request.json "$RESPONSE_FILE"
    exit 1
fi

# Intentar extraer información de la respuesta
echo "📊 Resumen de la respuesta:"
echo "$FIRST_RESPONSE" | jq . 2>/dev/null || echo "Respuesta JSON: $FIRST_RESPONSE"

# Buscar si hay una imagen generada (base64)
if grep -q "image" "$RESPONSE_FILE" 2>/dev/null || echo "$FIRST_RESPONSE" | grep -q "image" 2>/dev/null; then
    echo "🖼️  ¡Imagen detectada! Intentando extraer y guardar..."
    
    # Extraer base64 de imagen (esto puede necesitar ajuste según el formato exacto de la respuesta)
    IMAGE_BASE64=$(echo "$FIRST_RESPONSE" | jq -r '.candidates[0].content.parts[]? | select(.inlineData != null) | .inlineData.data' 2>/dev/null)
    
    if [[ -z "$IMAGE_BASE64" ]]; then
        # Fallback: buscar cualquier base64 data:image en la respuesta completa
        IMAGE_BASE64=$(grep -o 'data:image/[a-zA-Z]*;base64,[^"]*' "$RESPONSE_FILE" | head -1 | sed 's/^data:image\/[a-zA-Z]*;base64,//')
    fi
    
    if [[ -n "$IMAGE_BASE64" ]]; then
        # Decodificar y guardar la imagen
        echo "$IMAGE_BASE64" | base64 -d > generated_image.png 2>/dev/null
        if [[ $? -eq 0 ]]; then
            echo "✅ ¡Imagen guardada exitosamente como 'generated_image.png'!"
            echo "📏 Tamaño del archivo: $(wc -c < generated_image.png) bytes"
            ls -la generated_image.png
        else
            echo "⚠️  No se pudo decodificar la imagen base64. Guarda manualmente desde response.json"
        fi
    else
        echo "⚠️  No se encontró base64 de imagen en la respuesta. Revisa response.json manualmente."
    fi
else
    echo "ℹ️  No se detectó generación de imagen en la respuesta. El modelo respondió solo con texto."
    echo "Revisa si el prompt y configuración son correctos para image generation."
fi

# Limpiar archivos temporales (comenta esta línea si quieres mantenerlos para debug)
# rm -f request.json "$RESPONSE_FILE"

echo ""
echo "🎉 Prueba completada. Si funcionó, tu API key y modelo están correctos."
echo "Si falló, revisa:"
echo "  - Que la API key sea válida: https://aistudio.google.com/app/apikey"
echo "  - Que el modelo esté disponible en tu región/cuenta"
echo "  - Los logs de error en response.json"