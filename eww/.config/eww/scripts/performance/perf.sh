#!/bin/bash
# Performance metrics for EWW dashboard
# Path: ~/.dotfiles/eww/.config/eww/scripts/performance/perf.sh
# Symlinked to: ~/.config/eww/scripts/performance/perf.sh
#
# Environment variables:
#   EWW_GPU_CARD           - Direct card path (e.g., /sys/class/drm/card1/device) - most stable
#   EWW_GPU_INDEX          - GPU index (0-based, AMD/NVIDIA only) - convenience, less stable
#   EWW_NVIDIA_POLL_SECONDS - NVIDIA poll interval in seconds (recommended, default: 10)
#   EWW_NVIDIA_POLL        - NVIDIA poll interval in loops (legacy, couples to sleep)
#   EWW_CPU_TEMP_FALLBACK  - Set to 1 to scan all hwmon if driver-based search fails

set -u

# Debug logging - helps diagnose eww freezes
DEBUG_LOG="$HOME/.cache/eww/debug/perf.log"
mkdir -p "$(dirname "$DEBUG_LOG")"
log_debug() { echo "[$(date '+%H:%M:%S')] $1" >> "$DEBUG_LOG"; }
log_debug "=== perf.sh started (PID $$) ==="

# === Normalize label for comparison ===
# Lowercase + remove all non-alphanumeric (handles "Package id 0", "Package_ID_0", etc.)
# NOTE: Only called during startup (detection phase), NOT in the hot loop
normalize() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'
}

# === GPU Detection ===
detect_gpu() {
  # Priority 1: Direct card path override (most stable)
  if [[ -n "${EWW_GPU_CARD:-}" && -f "$EWW_GPU_CARD/vendor" ]]; then
    local vendor=$(< "$EWW_GPU_CARD/vendor")
    case "$vendor" in
      0x1002) echo "AMD:$EWW_GPU_CARD"; return ;;
      0x10de) echo "NVIDIA:$EWW_GPU_CARD"; return ;;
    esac
  fi

  # Priority 2: Index-based selection
  local index=0
  local target_index="${EWW_GPU_INDEX:-}"

  for card in /sys/class/drm/card*/device; do
    [[ -f "$card/vendor" ]] || continue
    local vendor=$(< "$card/vendor")

    case "$vendor" in
      0x1002|0x10de)
        if [[ -n "$target_index" ]]; then
          if ((index == target_index)); then
            [[ "$vendor" == "0x1002" ]] && echo "AMD:$card" || echo "NVIDIA:$card"
            return
          fi
          ((index++))
        else
          [[ "$vendor" == "0x1002" ]] && echo "AMD:$card" || echo "NVIDIA:$card"
          return
        fi
        ;;
    esac
  done
  echo "GPU:"
}

# === CPU Temp Detection ===
find_cpu_temp() {
  # Priority 1: CPU-specific drivers (avoids GPU/other device false positives)
  for name in /sys/class/hwmon/hwmon*/name; do
    [[ -r "$name" ]] || continue
    local driver=$(< "$name")
    case "$driver" in
      k10temp|coretemp|zenpower)
        local dir="${name%name}"
        # Prefer labeled sensors within CPU driver
        for target in "tdie" "tctl" "packageid0" "package" "core0"; do
          for label in "$dir"temp*_label; do
            [[ -r "$label" ]] || continue
            local content=$(normalize "$(< "$label")")
            [[ "$content" == *"$target"* ]] && echo "${label%_label}_input" && return
          done
        done
        # Fallback to temp1 within CPU driver
        [[ -r "${dir}temp1_input" ]] && echo "${dir}temp1_input" && return
        ;;
    esac
  done

  # Priority 2: Fallback mode - scan all hwmon (if EWW_CPU_TEMP_FALLBACK=1)
  # May pick up non-CPU temps on some systems
  if [[ "${EWW_CPU_TEMP_FALLBACK:-}" == "1" ]]; then
    for target in "tdie" "tctl" "packageid0" "package" "core0"; do
      for label in /sys/class/hwmon/hwmon*/temp*_label; do
        [[ -r "$label" ]] || continue
        local content=$(normalize "$(< "$label")")
        [[ "$content" == *"$target"* ]] && echo "${label%_label}_input" && return
      done
    done
  fi
}

# === AMD GPU Temp (substring match, normalized) ===
find_amd_gpu_temp() {
  local card_path="$1"
  [[ -z "$card_path" ]] && return

  local hwmon_dir=""
  for d in "$card_path"/hwmon/hwmon*; do
    [[ -d "$d" ]] && hwmon_dir="$d" && break
  done
  [[ -z "$hwmon_dir" ]] && return

  # Verify this hwmon is actually amdgpu before using it
  local hwmon_name="${hwmon_dir}/name"
  if [[ -r "$hwmon_name" ]]; then
    grep -qi "amdgpu" "$hwmon_name" || return
  fi

  # Priority: junction (hotspot) > edge > mem > temp1
  # junction = GPU die hotspot (most relevant for thermal throttling)
  # edge = GPU package edge
  # mem = VRAM temperature
  local targets=("junction" "hotspot" "edge" "mem")
  for target in "${targets[@]}"; do
    for label in "$hwmon_dir"/temp*_label; do
      [[ -r "$label" ]] || continue
      local content=$(normalize "$(< "$label")")
      [[ "$content" == *"$target"* ]] && echo "${label%_label}_input" && return
    done
  done
  # Fallback: temp1 only if confirmed amdgpu hwmon
  [[ -r "$hwmon_dir/temp1_input" ]] && echo "$hwmon_dir/temp1_input"
}

# === Initialize ===
IFS=: read -r GPU_VENDOR GPU_CARD_PATH <<< "$(detect_gpu)"
CPU_TEMP_FILE=$(find_cpu_temp)
GPU_USAGE_FILE=""
GPU_TEMP_FILE=""
NVIDIA_AVAILABLE=false

case "$GPU_VENDOR" in
  AMD)
    GPU_USAGE_FILE="$GPU_CARD_PATH/gpu_busy_percent"
    GPU_TEMP_FILE=$(find_amd_gpu_temp "$GPU_CARD_PATH")
    ;;
  NVIDIA)
    if command -v nvidia-smi &>/dev/null; then
      NVIDIA_AVAILABLE=true
    else
      GPU_VENDOR="GPU"  # Fallback if nvidia-smi missing
    fi
    ;;
esac

prev_total=0
prev_idle=0
prev_net_rx=""
prev_net_tx=""
first_sample=true
loop_count=0
disk_poll_counter=0
DISK_POLL_INTERVAL=10  # Poll disk every 10 iterations (disk changes slowly)

# NVIDIA polling config
# EWW_NVIDIA_POLL_SECONDS takes priority (stable across sleep changes)
# EWW_NVIDIA_POLL is loops (legacy, couples to sleep interval)
SLEEP_INTERVAL=2
if [[ -n "${EWW_NVIDIA_POLL_SECONDS:-}" ]]; then
  NVIDIA_POLL_INTERVAL=$((EWW_NVIDIA_POLL_SECONDS / SLEEP_INTERVAL))
  ((NVIDIA_POLL_INTERVAL < 1)) && NVIDIA_POLL_INTERVAL=1
else
  NVIDIA_POLL_INTERVAL="${EWW_NVIDIA_POLL:-5}"  # default: 5 loops = 10s
fi
nvidia_gpu_pct=0
nvidia_gpu_temp=0
nvidia_gpu_temp_ok=false

# Initialize disk values (will be populated on first poll)
disk_pct=0
disk_used="0"

# === Main Loop ===
while true; do
  # --- CPU utilization % ---
  read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
  total=$((user + nice + system + idle + iowait + irq + softirq + steal))
  idle_all=$((idle + iowait))

  if $first_sample; then
    prev_total=$total
    prev_idle=$idle_all
    first_sample=false
    sleep 2
    continue
  fi

  diff_total=$((total - prev_total))
  diff_idle=$((idle_all - prev_idle))
  cpu_pct=$((diff_total > 0 ? 100 * (diff_total - diff_idle) / diff_total : 0))
  # Clamp to 0-100 (guard against bad sensor data)
  ((cpu_pct < 0)) && cpu_pct=0
  ((cpu_pct > 100)) && cpu_pct=100
  prev_total=$total
  prev_idle=$idle_all

  # --- CPU temp (integer + validity flag) ---
  if [[ -n "$CPU_TEMP_FILE" && -r "$CPU_TEMP_FILE" ]]; then
    cpu_temp=$(($(< "$CPU_TEMP_FILE") / 1000))
    cpu_temp_ok=true
  else
    cpu_temp=0
    cpu_temp_ok=false
  fi

  # --- RAM ---
  mem_total_kb=0
  mem_avail_kb=0
  while IFS=': ' read -r key val _; do
    case $key in
      MemTotal) mem_total_kb=${val%%[!0-9]*} ;;
      MemAvailable) mem_avail_kb=${val%%[!0-9]*} ;;
    esac
  done < /proc/meminfo

  if ((mem_total_kb > 0)); then
    mem_used_kb=$((mem_total_kb - mem_avail_kb))
    mem_pct=$((100 * mem_used_kb / mem_total_kb))
    mem_used=$(awk "BEGIN {printf \"%.1f\", $mem_used_kb / 1048576}")
  else
    mem_pct=0
    mem_used="0"
  fi

  # --- GPU (integer temp + validity flag) ---
  gpu_pct=0
  gpu_temp=0
  gpu_temp_ok=false

  case "$GPU_VENDOR" in
    AMD)
      [[ -r "$GPU_USAGE_FILE" ]] && gpu_pct=$(< "$GPU_USAGE_FILE")
      if [[ -r "$GPU_TEMP_FILE" ]]; then
        gpu_temp=$(($(< "$GPU_TEMP_FILE") / 1000))
        gpu_temp_ok=true
      fi
      ;;
    NVIDIA)
      # Poll nvidia-smi at configurable interval (default 10s) to reduce overhead
      if $NVIDIA_AVAILABLE && ((loop_count % NVIDIA_POLL_INTERVAL == 0)); then
        # Pure bash parsing - no head/tr subprocesses
        nv_out=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
          --format=csv,noheader,nounits 2>/dev/null)
        nv_out="${nv_out%%$'\n'*}"  # First line only (bash, no head)
        IFS=',' read -r nvidia_gpu_pct nvidia_gpu_temp <<< "$nv_out"
        nvidia_gpu_pct="${nvidia_gpu_pct// /}"  # Strip spaces (bash, no tr)
        nvidia_gpu_temp="${nvidia_gpu_temp// /}"
        nvidia_gpu_pct="${nvidia_gpu_pct:-0}"
        if [[ -n "$nvidia_gpu_temp" && "$nvidia_gpu_temp" != "--" ]]; then
          nvidia_gpu_temp_ok=true
        else
          nvidia_gpu_temp=0
          nvidia_gpu_temp_ok=false
        fi
      fi
      gpu_pct=$nvidia_gpu_pct
      gpu_temp=${nvidia_gpu_temp:-0}
      gpu_temp_ok=${nvidia_gpu_temp_ok:-false}
      ;;
  esac

  # Clamp GPU % to 0-100 (guard against bad sensor data)
  ((gpu_pct < 0)) && gpu_pct=0
  ((gpu_pct > 100)) && gpu_pct=100

  # --- Network ---
  net_rx=0
  net_tx=0
  for iface in /sys/class/net/*/statistics; do
    [[ "$(dirname "$iface")" == */lo ]] && continue  # Skip loopback
    [[ -r "$iface/rx_bytes" ]] && net_rx=$((net_rx + $(< "$iface/rx_bytes")))
    [[ -r "$iface/tx_bytes" ]] && net_tx=$((net_tx + $(< "$iface/tx_bytes")))
  done

  if [[ -n "$prev_net_rx" ]]; then
    net_rx_speed=$(( (net_rx - prev_net_rx) / SLEEP_INTERVAL ))
    net_tx_speed=$(( (net_tx - prev_net_tx) / SLEEP_INTERVAL ))
    # Convert to human readable (KB/s or MB/s)
    if ((net_rx_speed > 1048576)); then
      net_rx_fmt=$(awk "BEGIN {printf \"%.1f\", $net_rx_speed / 1048576}")
      net_rx_unit="MB/s"
    else
      net_rx_fmt=$(awk "BEGIN {printf \"%.0f\", $net_rx_speed / 1024}")
      net_rx_unit="KB/s"
    fi
    if ((net_tx_speed > 1048576)); then
      net_tx_fmt=$(awk "BEGIN {printf \"%.1f\", $net_tx_speed / 1048576}")
      net_tx_unit="MB/s"
    else
      net_tx_fmt=$(awk "BEGIN {printf \"%.0f\", $net_tx_speed / 1024}")
      net_tx_unit="KB/s"
    fi
    # Network activity level (0-100) based on combined speed (bytes/sec)
    net_combined=$((net_rx_speed + net_tx_speed))
    if ((net_combined < 10240)); then        # <10 KB/s
      net_activity=10
    elif ((net_combined < 102400)); then     # 10-100 KB/s
      net_activity=35
    elif ((net_combined < 1048576)); then    # 100 KB/s - 1 MB/s
      net_activity=60
    elif ((net_combined < 10485760)); then   # 1-10 MB/s
      net_activity=85
    else                                     # >10 MB/s
      net_activity=100
    fi
  else
    net_rx_fmt="0"
    net_rx_unit="KB/s"
    net_tx_fmt="0"
    net_tx_unit="KB/s"
    net_activity=10
  fi
  prev_net_rx=$net_rx
  prev_net_tx=$net_tx

  # --- Disk (poll every 10th iteration - disk changes slowly) ---
  if ((disk_poll_counter == 0)); then
    read -r _ disk_total_kb disk_used_kb _ disk_pct_raw _ < <(df -k / | tail -1)
    if [[ -n "$disk_total_kb" && "$disk_total_kb" -gt 0 ]]; then
      disk_pct=${disk_pct_raw%\%}
      disk_used=$(awk "BEGIN {printf \"%.0f\", $disk_used_kb / 1048576}")
    else
      disk_pct=0
      disk_used="0"
    fi
  fi
  disk_poll_counter=$(( (disk_poll_counter + 1) % DISK_POLL_INTERVAL ))

  # --- Output (temps as integers with validity flags) ---
  echo "{\"cpu\":{\"percent\":${cpu_pct},\"temp\":${cpu_temp},\"temp_ok\":${cpu_temp_ok}},\"ram\":{\"percent\":${mem_pct},\"used\":\"${mem_used}\"},\"gpu\":{\"vendor\":\"${GPU_VENDOR}\",\"percent\":${gpu_pct},\"temp\":${gpu_temp},\"temp_ok\":${gpu_temp_ok}},\"net\":{\"rx\":\"${net_rx_fmt}\",\"rx_unit\":\"${net_rx_unit}\",\"tx\":\"${net_tx_fmt}\",\"tx_unit\":\"${net_tx_unit}\",\"activity\":${net_activity}},\"disk\":{\"percent\":${disk_pct},\"used\":\"${disk_used}\"}}"

  # Log heartbeat every 30 seconds (15 loops * 2s sleep)
  ((loop_count % 15 == 0)) && log_debug "heartbeat (30s) - loop $loop_count"

  ((loop_count++))
  sleep "$SLEEP_INTERVAL"
done
