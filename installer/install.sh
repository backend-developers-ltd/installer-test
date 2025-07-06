#!/usr/bin/env bash
# Script to install a cron job that fetches and runs the updater script

set -euo pipefail

# Default values for arguments
ENV_NAME="${1:-prod}"
WORKING_DIRECTORY="${2:-$HOME/test-validator/}"

# Ensure the working directory exists
mkdir -p "${WORKING_DIRECTORY}"

# Check if .env file exists in the working directory
ENV_FILE="${WORKING_DIRECTORY}/.env"
if [ ! -f "${ENV_FILE}" ]; then
    echo "Creating .env file..."

    # Prompt for user inputs with default values
    read -p "Enter BITTENSOR_NETUID [9999]: " BITTENSOR_NETUID </dev/tty
    BITTENSOR_NETUID=${BITTENSOR_NETUID:-9999}

    read -p "Enter BITTENSOR_NETWORK [finney]: " BITTENSOR_NETWORK  </dev/tty
    BITTENSOR_NETWORK=${BITTENSOR_NETWORK:-finney}

    read -p "Enter HOST_WALLET_DIR [~/.bittensor/wallets]: " HOST_WALLET_DIR  </dev/tty
    HOST_WALLET_DIR=${HOST_WALLET_DIR:-~/.bittensor/wallets}

    read -p "Enter BITTENSOR_WALLET_NAME [validator]: " BITTENSOR_WALLET_NAME  </dev/tty
    BITTENSOR_WALLET_NAME=${BITTENSOR_WALLET_NAME:-validator}

    read -p "Enter BITTENSOR_WALLET_HOTKEY_NAME [default]: " BITTENSOR_WALLET_HOTKEY_NAME  </dev/tty
    BITTENSOR_WALLET_HOTKEY_NAME=${BITTENSOR_WALLET_HOTKEY_NAME:-default}

    # Generate a random string for SECRET_KEY
    SECRET_KEY=$(openssl rand -base64 64 | tr -d '\n\r\t ')

    # Create the .env file
    cat > "${ENV_FILE}" << EOL
BITTENSOR_NETUID=${BITTENSOR_NETUID}
BITTENSOR_NETWORK=${BITTENSOR_NETWORK}
HOST_WALLET_DIR=${HOST_WALLET_DIR}
BITTENSOR_WALLET_NAME=${BITTENSOR_WALLET_NAME}
BITTENSOR_WALLET_HOTKEY_NAME=${BITTENSOR_WALLET_HOTKEY_NAME}
POSTGRES_PASSWORD=123456789
SECRET_KEY=${SECRET_KEY}
EOL

    echo ".env file created successfully."
fi

# Hardcoded GitHub raw URL
GITHUB_URL="https://raw.githubusercontent.com/backend-developers-ltd/installer-test/refs/heads"

# Run update_compose.sh once to ensure it works
echo "Running update_compose.sh once to ensure it works..."
curl -s "${GITHUB_URL}/deploy-config-${ENV_NAME}/installer/update_compose.sh" > /tmp/update_compose.sh
chmod +x /tmp/update_compose.sh
if ! /tmp/update_compose.sh "${ENV_NAME}" "${WORKING_DIRECTORY}"; then
    echo "Error: update_compose.sh failed. Not adding cronline."
    exit 1
fi
echo "update_compose.sh ran successfully."

# Create the cron job command with a unique identifier comment
# This will fetch the updater script from GitHub and run it with the provided arguments
CRON_CMD="*/15 * * * * cd ${WORKING_DIRECTORY} && curl -s ${GITHUB_URL}/deploy-config-${ENV_NAME}/installer/update_compose.sh > /tmp/update_compose.sh && chmod +x /tmp/update_compose.sh && /tmp/update_compose.sh ${ENV_NAME} ${WORKING_DIRECTORY} # TEST_VALIDATOR_UPDATE"

# Install the cron job
(crontab -l 2>/dev/null || echo "") | grep -v "TEST_VALIDATOR_UPDATE" | { cat; echo "${CRON_CMD}"; } | crontab -

echo "Cron job installed successfully. It will run every 15 minutes."
echo "Environment: ${ENV_NAME}"
echo "Working directory: ${WORKING_DIRECTORY}"
