# Design Document

## Overview

The white screen issue was caused by dependency initialization failures and platform-specific code being executed on web builds. The solution involves creating platform-specific entry points and graceful error handling.

## Architecture

### Platform Detection
- Use `kIsWeb` to detect web platform at runtime
- Route to appropriate main function based on platform
- Separate web and mobile implementations

### Error Handling Strategy
- Wrap dependency initialization in try-catch blocks
- Continue app execution even if some services fail to initialize
- Provide fallback functionality for failed services

### Web Demo Architecture
- Create separate web-specific pages and providers
- Use mock data providers instead of platform channels
- Implement demo functionality with simulated interactions

## Components and Interfaces

### Main Entry Points
- `main.dart` - Platform detection and routing
- `main_web.dart` - Web-specific application entry
- `main_mobile.dart` - Mobile platform fallback

### Web Demo Components
- `HomePageWeb` - Web version of home page with demo data
- `SendPickerPageWeb` - File sending simulation
- `ReceivePageWeb` - File receiving simulation
- `TransferHistoryPageWeb` - Mock transfer history display

### Provider Architecture
- `app_providers_web.dart` - Web-specific state providers
- Mock data providers for devices, transfers, and statistics
- Simulated user interactions and state changes

## Data Models

### Mock Data Structure
- Demo devices with realistic properties
- Simulated transfer sessions with progress tracking
- Mock statistics for demonstration purposes

## Error Handling

### Initialization Errors
- Catch dependency injection failures
- Continue with limited functionality
- Log warnings for debugging

### Platform Compatibility
- Avoid platform-specific imports on web
- Use conditional imports where necessary
- Graceful degradation for unsupported features

## Testing Strategy

### Web Build Verification
- Ensure successful compilation for web target
- Verify all demo features function correctly
- Test responsive design across different screen sizes

### Mobile Compatibility
- Maintain existing mobile functionality
- Ensure error handling doesn't break mobile features
- Test initialization recovery scenarios