# How to Install NVM (Node Version Manager)

NVM is a tool that allows you to manage multiple versions of Node.js on your system. Below is a step-by-step guide to install and use NVM.

## Prerequisites

- A Unix-based system (Linux, macOS, or WSL on Windows).
- Access to a terminal with `curl` or `wget` installed.


## Installation Steps

### 1. Download the Installation Script
Use either `curl` or `wget` to fetch the installation script:

```bash
# Using curl
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# Using wget
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
```

### 2. Update Your Shell Configuration
The installation script adds necessary lines to your shell configuration file. You must restart your shell or reload the configuration for the changes to take effect.

#### For Bash Users
```bash
source ~/.bashrc
```

#### For Zsh Users
```bash
source ~/.zshrc
```

#### For Fish Users
NVM is not natively supported in Fish shell. You can install an alternative wrapper, [Fisher NVM](https://github.com/jorgebucaran/fisher).


### 3. Verify the Installation
To confirm NVM is installed, run:

```bash
nvm --version
```

You should see the version number of NVM.

## Basic Usage

### Install a Node.js Version
```bash
nvm install <version>
# Example: nvm install 18
```

### Use a Specific Node.js Version
```bash
nvm use <version>
# Example: nvm use 18
```

## Troubleshooting

1. **NVM Command Not Found**  
   Ensure the lines added to your shell configuration file are sourced. Manually add the following to `~/.bashrc` or `~/.zshrc` if missing:
   ```bash
   export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
   [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
   ```

## Resources

- [NVM Official Repository](https://github.com/nvm-sh/nvm)
- [Node.js Official Website](https://nodejs.org/)
