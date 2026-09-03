# Schatz

**Premium AI Chat Companion for Android**

Schatz is a free, open-source AI chat companion that supports multiple AI providers, streaming chat, multimodal input, and offline models.

## Features

- **Multi-Provider Support**: OpenAI, Groq, Gemini, Mistral, Cerebras, OpenRouter, and custom OpenAI-compatible endpoints
- **Provider Setup Wizard**: Guided onboarding with Skip option for new users
- **Persistent Setup Banner**: Reminds users to complete provider setup when incomplete
- **Native Gemini Adapter**: Direct Gemini API support with list/generate/stream
- **Free/Starter Model Catalog**: Pre-configured free and starter models per provider
- **Streaming Chat**: Real-time token streaming with stop generation
- **Model Discovery**: Automatic model listing where supported
- **Connection Testing**: Validate provider configurations
- **Persistent Chat History**: All conversations saved locally
- **Markdown Rendering**: Full markdown support with code highlighting
- **Image Input**: Upload images for vision-capable models
- **File Upload**: Support for text, code, and document files
- **Voice Recording**: Hold-to-record with transcription support
- **Text-to-Speech**: Listen to assistant responses
- **Personas**: Built-in and custom personality presets
- **Offline Mode**: Local GGUF model support (experimental)
- **Import/Export**: Chat backup in JSON format
- **Premium UI**: Material 3 dark theme with gold accents

## Architecture

```
lib/
├── core/
│   ├── constants/
│   ├── errors/
│   ├── network/
│   ├── routing/
│   ├── security/
│   ├── theme/
│   └── widgets/
├── providers/
│   ├── adapters/
│   ├── models/
│   └── services/
├── chat/
│   ├── database/
│   ├── models/
│   ├── screens/
│   ├── services/
│   └── widgets/
├── settings/
│   ├── screens/
│   └── widgets/
├── onboarding/
│   └── screens/
└── main.dart
```

## Setup

### Prerequisites

- Flutter 3.16+
- Android SDK 24+
- Dart 3.2+

### Installation

```bash
git clone https://github.com/yourusername/schatz.git
cd schatz
flutter pub get
flutter run
```

### Android Build

```bash
flutter build apk --release
```

## Provider Setup

### Free API Keys

1. **OpenRouter**: [openrouter.ai](https://openrouter.ai) - Free tier available
2. **Groq**: [groq.com](https://groq.com) - Free tier with fast inference
3. **Google Gemini**: [ai.google.dev](https://ai.google.dev) - Free tier available
4. **Mistral**: [mistral.ai](https://mistral.ai) - Free tier available

### Adding a Provider

1. Open Settings → Providers
2. Tap the + button
3. Select provider type
4. Enter your API key
5. Select a model
6. Test connection

### Provider Onboarding

New users are guided through a streamlined setup flow:

1. **Welcome** - Brief intro to Schatz
2. **Provider Selection** - Choose from available AI providers
3. **API Key Entry** - Enter your API key (or skip for later)
4. **Model Selection** - Choose from free/starter models

Users can skip setup and configure later. A persistent banner in Home reminds users to complete setup when incomplete.

## Security

- API keys stored in Flutter Secure Storage (encrypted)
- No analytics or tracking
- No backend servers
- No data leaves your device except to your chosen AI provider
- Exported chats never include API keys

## Offline Mode

Experimental GGUF model support for offline inference. Download models from the Model Manager in Settings.

**Warning**: Large models require significant RAM and storage.

## Permissions

- **Internet**: Required for AI provider communication
- **Camera**: Optional, for image capture
- **Microphone**: Optional, for voice recording
- **Storage**: Optional, for file uploads

## Building

```bash
# Debug build
flutter build apk --debug

# Release build
flutter build apk --release

# App Bundle
flutter build appbundle
```

## Testing

```bash
flutter test
flutter analyze
dart format --set-exit-if-changed .
```

## License

MIT License

## Acknowledgments

- [Flutter](https://flutter.dev)
- [Material Design 3](https://m3.material.io)
- [Riverpod](https://riverpod.dev)
- [Dio](https://pub.dev/packages/dio)
- [flutter_markdown](https://pub.dev/packages/flutter_markdown)
