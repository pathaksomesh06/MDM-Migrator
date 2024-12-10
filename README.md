# MDM Migrator

MDM Migrator is a professional macOS application designed to automate and streamline the migration process from Jamf to Microsoft Intune mobile device management. The tool provides a secure, efficient, and user-friendly solution for organizations transitioning their device management infrastructure.

## Features

### Core Functionality
MDM Migrator handles the complete migration process through several automated steps:

- **Prerequisite Validation**: Comprehensive system and configuration checks ensure migration readiness
- **Jamf Management Removal**: Automated removal of Jamf MDM profiles and framework
- **Intune Integration**: Streamlined Microsoft Intune enrollment process
- **Security Management**: Secure handling of FileVault key rotation
- **Progress Monitoring**: Real-time status updates and detailed logging

### Screenshots
![Screenshots](screenshots/1.png)
![Screenshots](screenshots/2.png)
![Screenshots](screenshots/3.png)
![Screenshots](screenshots/4.png)
![Screenshots](screenshots/5.png)
![Screenshots](screenshots/6.png)
![Screenshots](screenshots/7.png)
![Screenshots](screenshots/8.png)
![Screenshots](screenshots/9.png)
![Screenshots](screenshots/10.png)

### Video
Watch a quick demonstration of the MDM migration process:

<video width="100%" controls>
  <source src="screenshots/MDMMigrator.mp4" type="video/mp4">
</video>


## System Requirements

- macOS 14.0 or later
- Administrative privileges
- Active internet connection
- Minimum 10GB free disk space
- Valid Jamf enrollment
- Microsoft Intune license

### Required Setup Steps

#### 1. Apple Business Manager (ABM) Configuration
- Assign the Mac device to Apple Business Manager
- Verify the device appears in ABM inventory
- Ensure ABM has the correct MDM server tokens

#### 2. Microsoft Intune Configuration
- Sync ABM token in Intune Admin Center
- Verify the sync completed successfully
- Assign required device profiles
  - Enrollment profile
  - Configuration profiles
  - Compliance policies

#### 3. Synchronization
- Wait for ABM-Intune sync to complete
- Verify device appears in Intune inventory
- Confirm profile assignments are active

### Pre-Migration Checklist
✓ Device is enrolled in Jamf
✓ Device appears in ABM
✓ ABM token synced with Intune
✓ Required profiles assigned
✓ Sync completion verified
✓ Backup of important data
✓ Network connectivity confirmed

### Important Notes
- Sync times may vary depending on your environment
- Profile assignments might take up to 15 minutes to propagate
- Verify all assignments before proceeding with migration
- Keep device connected to network throughout the process

## Installation

1. Download the latest release package
3. Run the installer
4. The tool launches automatically after installation and does not require any additional rights.
5. For manual launch from Applications folder, please use:
            **sudo /Applications/MDM\ Migrator.app/Contents/MacOS/MDM\ Migrator**
6. Follow the setup wizard

## Usage

### Pre-Migration Steps
1. Ensure all system requirements are met
2. Back up your device
3. Close all running applications
4. Verify network connectivity

### Migration Process
1. Launch MDM Migrator
2. Complete prerequisites check
3. Follow the guided migration workflow
5. Review final status and logs

### Post-Migration
1. Verify successful Intune enrollment
2. Restart your device
3. Test system functionality
4. Archive migration logs

## Documentation

Comprehensive documentation is available.

## Contributing

Contributions to MDM Migrator are always welcome.

---
© 2024 [IntuneInRealLife]. All rights reserved.
© 2024 [MDMMigrator]. All rights reserved.

## Disclaimer

This tool is provided "AS IS" without warranty of any kind. The developer and/or distributor of this software explicitly disclaim all responsibility and liability for any consequences resulting from the use of this software, including but not limited to:
- Data loss or corruption
- System configuration changes or failures
- Network connectivity issues
- Business interruption
- Device performance issues
- Any direct, indirect, incidental, or consequential damages. The entire risk arising out of the use of this tool and associated documentation remains with you.
