---
section: 14-telemetry
applies_to: [Win10, Win11, Server]
order: 140
risk: none
ac_safe: true
---

# Telemetry + Cortana + Privacy off

## Telemetry

Path: `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection`

| Name | Type | Value |
|------|------|-------|
| AllowTelemetry | DWord | 0 |
| DoNotShowFeedbackNotifications | DWord | 1 |
| LimitEnhancedDiagnosticDataWindowsAnalytics | DWord | 0 |

Path: `HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows`

| Name | Type | Value |
|------|------|-------|
| CEIPEnable | DWord | 0 |

Path: `HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat`

| Name | Type | Value |
|------|------|-------|
| DisablePCA | DWord | 1 |
| DisableUAR | DWord | 1 |
| DisableInventory | DWord | 1 |

## Cortana + Bing search

Path: `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search`

| Name | Type | Value |
|------|------|-------|
| AllowCortana | DWord | 0 |
| DisableWebSearch | DWord | 1 |
| ConnectedSearchUseWeb | DWord | 0 |
| ConnectedSearchUseWebOverMeteredConnections | DWord | 0 |
| AllowSearchToUseLocation | DWord | 0 |
| AllowCloudSearch | DWord | 0 |
| AllowIndexingEncryptedStoresOrItems | DWord | 0 |

Path: `HKCU:\Software\Microsoft\Windows\CurrentVersion\Search`

| Name | Type | Value |
|------|------|-------|
| BingSearchEnabled | DWord | 0 |
| CortanaEnabled | DWord | 0 |
| CortanaConsent | DWord | 0 |
| DeviceHistoryEnabled | DWord | 0 |
| HistoryViewEnabled | DWord | 0 |
| BackgroundAppGlobalToggle | DWord | 0 |
| SearchboxTaskbarMode | DWord | 0 |
| SafeSearchMode | DWord | 0 |

## Location

Path: `HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors`

| Name | Type | Value |
|------|------|-------|
| DisableLocation | DWord | 1 |
| DisableLocationScripting | DWord | 1 |
| DisableWindowsLocationProvider | DWord | 1 |
| DisableSensors | DWord | 1 |

## Advertising ID

Path: `HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo`

| Name | Type | Value |
|------|------|-------|
| DisabledByGroupPolicy | DWord | 1 |

Path: `HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo`

| Name | Type | Value |
|------|------|-------|
| Enabled | DWord | 0 |

## Activity history

Path: `HKLM:\SOFTWARE\Policies\Microsoft\Windows\System`

| Name | Type | Value |
|------|------|-------|
| PublishUserActivities | DWord | 0 |
| UploadUserActivities | DWord | 0 |
| EnableActivityFeed | DWord | 0 |

## Updates — no auto reboot, no P2P

Path: `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`

| Name | Type | Value |
|------|------|-------|
| NoAutoRebootWithLoggedOnUsers | DWord | 1 |
| AUPowerManagement | DWord | 0 |
| NoAutoUpdate | DWord | 0 |
| AUOptions | DWord | 3 |
| ScheduledInstallDay | DWord | 0 |

Path: `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization`

| Name | Type | Value |
|------|------|-------|
| DODownloadMode | DWord | 0 |

## Suggestions / Spotlight off

Path: `HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`

| Name | Type | Value |
|------|------|-------|
| ContentDeliveryAllowed | DWord | 0 |
| OemPreInstalledAppsEnabled | DWord | 0 |
| PreInstalledAppsEnabled | DWord | 0 |
| PreInstalledAppsEverEnabled | DWord | 0 |
| SilentInstalledAppsEnabled | DWord | 0 |
| SoftLandingEnabled | DWord | 0 |
| SubscribedContent-338388Enabled | DWord | 0 |
| SubscribedContent-338389Enabled | DWord | 0 |
| SubscribedContent-338393Enabled | DWord | 0 |
| SubscribedContent-353694Enabled | DWord | 0 |
| SubscribedContent-353696Enabled | DWord | 0 |
| SystemPaneSuggestionsEnabled | DWord | 0 |
| RotatingLockScreenEnabled | DWord | 0 |
| RotatingLockScreenOverlayEnabled | DWord | 0 |

Path: `HKCU:\Software\Policies\Microsoft\Windows\CloudContent`

| Name | Type | Value |
|------|------|-------|
| DisableWindowsSpotlightFeatures | DWord | 1 |
| DisableTailoredExperiencesWithDiagnosticData | DWord | 1 |

Path: `HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent`

| Name | Type | Value |
|------|------|-------|
| DisableWindowsConsumerFeatures | DWord | 1 |
| DisableConsumerAccountStateContent | DWord | 1 |
| DisableSoftLanding | DWord | 1 |
| DisableThirdPartySuggestions | DWord | 1 |

## Input personalization

Path: `HKCU:\Software\Microsoft\InputPersonalization`

| Name | Type | Value |
|------|------|-------|
| RestrictImplicitTextCollection | DWord | 1 |
| RestrictImplicitInkCollection | DWord | 1 |

## Error reporting

Path: `HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting`

| Name | Type | Value |
|------|------|-------|
| Disabled | DWord | 1 |
| DontSendAdditionalData | DWord | 1 |
| LoggingDisabled | DWord | 1 |
