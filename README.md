# Run the Partner Center Licensing Export Script on macOS

This guide installs PowerShell 7 and the required PowerShell modules on macOS so you can run:

```powershell
./Export-PartnerCenter-DelegatedUsersLicenses-v2.ps1 -UseDeviceAuthentication
```

## 1. Install Homebrew

Open **Terminal** and run:
<img width="757" height="211" alt="image" src="https://github.com/user-attachments/assets/c84b834c-1873-4cf2-aae8-84bc77cf8ebb" />

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

After installation, follow any Homebrew instructions shown in Terminal to add `brew` to your PATH.

Check Homebrew works:

```bash
brew --version
```

## 2. Install PowerShell 7

<img width="1254" height="1108" alt="image" src="https://github.com/user-attachments/assets/47e1c7fe-f6c3-4e34-be17-ecae8421158f" />


```bash
brew install --cask powershell
```

Start PowerShell:

```bash
pwsh
```

Check the version:

```powershell
$PSVersionTable.PSVersion
```

You should see PowerShell **7.x**.

## 3. Install Required PowerShell Modules

Run these inside `pwsh`:

```powershell
Install-Module PartnerCenter -Scope CurrentUser -Force
Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber
```

If prompted to trust PSGallery, choose:

```text
A
```

## 4. Verify Modules

```powershell
Get-InstalledModule PartnerCenter
Get-InstalledModule Microsoft.Graph
```

## 5. Remove macOS Quarantine Flag

If the script was downloaded from a browser, macOS may block it.

From Terminal or PowerShell, run:

```bash
xattr -d com.apple.quarantine ~/Downloads/Export-PartnerCenter-DelegatedUsersLicenses-v2.ps1
```

If the file is somewhere else, update the path.

## 6. Allow Script Execution for This Session

Inside `pwsh`:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

This only applies to the current PowerShell session.

## 7. Run the Script

```powershell
cd ~/Downloads

./Export-PartnerCenter-DelegatedUsersLicenses-v2.ps1 -UseDeviceAuthentication
```

You will be given a device login code and a Microsoft login URL.

Sign in with your Partner Center account.

## 8. Output Files

The script creates CSV files in the same folder:

```text
PartnerCenter-Customers.csv
PartnerCenter-SubscribedSkus.csv
PartnerCenter-Users.csv
PartnerCenter-UserLicenses.csv
PartnerCenter-Errors.csv
```

## Troubleshooting

### `Connect-PartnerCenter` not recognised

Install or re-import the module:

```powershell
Install-Module PartnerCenter -Scope CurrentUser -Force
Import-Module PartnerCenter
```

### `Forbidden` errors

Your Partner Center login works, but your account does not have enough delegated permissions for that customer.

Check Partner Center:

```text
Partner Center > Account settings > User management
```

Your account usually needs:

```text
Admin agent
```

For GDAP customer access, your assigned security group usually needs roles such as:

```text
Directory Readers
User Administrator
License Administrator
```

### Browser login does not open

Use device authentication:

```powershell
Connect-PartnerCenter -UseDeviceAuthentication
```

The provided export script already supports:

```powershell
-UseDeviceAuthentication
```
