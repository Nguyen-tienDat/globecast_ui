#!/bin/bash

echo "🚀 Setting up GlobeCast Whisper Streaming Server..."

# Check Python version
python_version=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1-2)
echo "Python version: $python_version"

# Create virtual environment
echo "📦 Creating virtual environment..."
python3 -m venv whisper_env
source whisper_env/bin/activate

# Upgrade pip
echo "⬆️ Upgrading pip..."
pip install --upgrade pip

# Install requirements
echo "📚 Installing requirements..."
pip install -r requirements.txt

# Download Whisper model (optional - will auto-download on first use)
echo "🤖 Testing Whisper model download..."
python3 -c "
from faster_whisper import WhisperModel
print('Testing model download...')
model = WhisperModel('base')  # Download smaller model for testing
print('✅ Model download successful!')
"

echo "✅ Setup complete!"
echo ""
echo "To start the server:"
echo "  source whisper_env/bin/activate"
echo "  python3 whisper_streaming_server.py"
echo ""
echo "For GPU support (optional):"
echo "  pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu118"