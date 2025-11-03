# BrowserStack NOW

`browserstack-now` is an onboarding utility designed for BrowserStack customers to get started with automated tests on the BrowserStack platform.

This utility automates the entire first-mile experience — from credential input to running a verified test on BrowserStack infrastructure — all within approximately 2 minutes.

## 🔧 Key Features

| Feature                  | Description                                                                                             |
| ------------------------ | ------------------------------------------------------------------------------------------------------- |
| 🔐 UI-based Credential Input | Uses native dialogs for username and access key capture.                                                |
| 🧪 Sample Test Execution   | Runs a real sample repo from the customer’s account to validate the setup.                                 |
| 🔍 Pre-requisite Check     | Validates if Java, Node, and Python are installed. Provides installation guidance if they are missing.      |
| 📊 Plan Variant Detection  | Calls the `/plan` API to tailor the sample repo based on the customer’s subscription tier (e.g., Live, Pro). |
| ✅ Console UX with Checkmarks | Mimics the BrowserStack Network Assessment Tool for a familiar experience.                              |
| 🪵 Logging for Debugging   | Saves all raw logs under `~/.browserstack/bstack_onboarding.log` for support and debugging purposes.     |
| 🖥️ (Planned) UI Framework Picker | Allows customers to select their preferred test framework via an interactive UI.                      |

## How to Use?

You can either run the script directly from the web or clone the repository and run it locally.

### Clone and Run Locally

1.  Clone the repository:
    ```bash
    git clone https://github.com/BrowserStackCE/browserstack-now.git
    ```
2.  Navigate to the directory:
    ```bash
    cd browserstack-now
    ```
3.  Execute the script for your operating system:

    **macOS / Linux**
    ```bash
    bash mac.sh
    ```

    **Windows**
    ```powershell
    ./windows.ps1
    ```

### Remote Execution

#### macOS / Linux

To run the onboarding utility on macOS or Linux without cloning, execute the following command in your terminal:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/http-heading/browserstack-now/main/mac_os.sh)"
```

#### Windows

To run the onboarding utility on Windows without cloning, execute the following command in PowerShell:
**Note:** You may need to set the execution policy to `RemoteSigned` or `Bypass` to run the script.

```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/http-heading/browserstack-now/main/windows.ps1'))
```

## Identifying and sharing the log files

The NOW framework creates the log files in this folder. To seek assistance from the BrowserStack team after running this Github repository, please share a zip of the logs with the BrowserStack team in toucn with you.

### NOW Framework Logs 

#### macOS / Linux
```
$HOME/.browserstack/NOW/logs
```

#### Windows
```
$HOME/.browserstack/NOW/logs
```


