#!/usr/bin/env bash
set -euo pipefail

# ---------- Config via Codespaces Secrets ----------
# Required: set these in your repo/Org Codespaces secrets
#   ADO_ORG  -> org name (e.g. contoso) OR full URL (https://dev.azure.com/contoso)
#   ADO_PAT  -> PAT with at least "Agent Pools (Read & manage)"
: "${ADO_ORG:?Set Codespaces secret ADO_ORG to your org name or full URL}"
: "${ADO_PAT:?Set Codespaces secret ADO_PAT to your Azure DevOps PAT}"

# Optional overrides (you can also set these as secrets/envs)
: "${AZP_POOL:=Default}"              # Azure DevOps agent pool
: "${AZP_AGENT_VERSION:=2.206.1}"     # Agent version
: "${AZP_AGENT_NAME:=$(hostname)}"    # Agent name

# ---------- Derive org URL ----------
if [[ "$ADO_ORG" =~ ^https?:// ]]; then
  AZP_URL="$ADO_ORG"
else
  AZP_URL="https://dev.azure.com/${ADO_ORG}"
fi

# ---------- Prepare workspace folder ----------
AGENT_ROOT="/home/vscode/azp"
mkdir -p "$AGENT_ROOT"
chown -R vscode:vscode "$AGENT_ROOT"
cd "$AGENT_ROOT"

# ---------- Download agent from GitHub releases (reliable) ----------
AGENT_TGZ="vsts-agent-linux-x64-${AZP_AGENT_VERSION}.tar.gz"
AGENT_URL="https://github.com/microsoft/azure-pipelines-agent/releases/download/v${AZP_AGENT_VERSION}/${AGENT_TGZ}"

if [[ ! -x "./bin/Agent.Listener" ]]; then
  echo "Downloading Azure Pipelines agent ${AZP_AGENT_VERSION}..."
  curl -fsSL -o "${AGENT_TGZ}" "${AGENT_URL}"
  tar -xzf "${AGENT_TGZ}"
  rm -f "${AGENT_TGZ}"
  ./bin/installdependencies.sh
fi

# ---------- Configure agent (ephemeral; auto-removes after job) ----------
# If reconfiguring, clean stale files to avoid conflicts
if [[ -f ".agent" ]]; then
  ./config.sh remove --unattended --auth pat --token "$ADO_PAT" || true
fi

./config.sh --unattended \
  --url "$AZP_URL" \
  --auth pat --token "$ADO_PAT" \
  --pool "$AZP_POOL" \
  --agent "$AZP_AGENT_NAME" \
  --acceptTeeEula \
  --ephemeral \
  --replace

# ---------- Run a single job, then exit ----------
exec ./run.sh --once
