# SceneFixer

An iOS app to diagnose and repair HomeKit scene issues.

## Features

- **Device Health Monitoring**: Track the health status of all your HomeKit devices
- **Scene Auditing**: Identify scenes with unreachable or problematic devices
- **AI-Powered Diagnostics**: Natural language queries about your smart home using Ollama, OpenWebUI, or cloud AI services
- **Automatic Repair**: Remove unreachable devices from scenes with backup support
- **Toggle Testing**: Safe toggle tests on devices (excludes locks and garage doors)
- **Manufacturer Insights**: See device reliability by manufacturer

## Requirements

- iOS 17.0 or later
- iPhone or iPad with HomeKit configured
- HomeKit-compatible smart home devices

## HomeKit Capability

This app requires the HomeKit capability. To build and run:

1. Open `SceneFixer.xcodeproj` in Xcode
2. Select your Development Team in Signing & Capabilities
3. Xcode will automatically create a provisioning profile with HomeKit capability
4. Build and run on a physical iOS device

**Note**: HomeKit apps cannot run in the iOS Simulator. You must use a physical device.

## AI Backend Configuration

SceneFixer supports multiple AI backends for natural language queries:

- **Ollama** (default): Local AI inference at `http://localhost:11434`
- **OpenWebUI**: Web-based interface at `http://localhost:3000`
- **Claude**: Anthropic's AI (requires API key)
- **GPT-4**: OpenAI's model (requires API key)

Configure backends in the Settings tab.

## How It Works

### Device Testing
1. The app reads the current state of all HomeKit devices
2. For each device, it attempts to read characteristics to verify connectivity
3. Devices are marked as Healthy, Degraded, or Unreachable based on response

### Scene Auditing
1. Each scene's action set is analyzed to identify participating devices
2. Device reachability is checked for all devices in the scene
3. Scenes are marked as Healthy, Degraded, or Broken

### Scene Repair
1. Before repair, a backup of the scene is created
2. Unreachable devices are identified in the action set
3. Actions for unreachable devices are removed from HomeKit
4. The scene is refreshed to reflect changes

## Project Structure

```
SceneFixer/
├── Models/
│   ├── DeviceModels.swift     # Device types, categories, manufacturers
│   └── SceneModels.swift      # Scene types and status tracking
├── Services/
│   ├── HomeKitManager.swift   # HomeKit integration
│   ├── DeviceTester.swift     # Device health checking
│   ├── SceneAnalyzer.swift    # Scene auditing and repair
│   └── AIAssistant.swift      # AI backend integration
└── Views/
    ├── ContentView.swift      # Main tab navigation
    ├── DashboardView.swift    # Overview and quick actions
    ├── DeviceListView.swift   # Device list and details
    ├── SceneListView.swift    # Scene list and details
    ├── AIAssistantView.swift  # Chat interface
    └── SettingsView.swift     # App configuration
```

## Safety Features

- **Dangerous Device Protection**: Locks and garage doors are excluded from toggle tests
- **Scene Backup**: Backups are created before any scene modifications
- **Original State Restoration**: Toggle tests restore devices to their original state

## Author

Jordan Koch

## License

MIT License
