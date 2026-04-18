#!/usr/bin/env bash

# System Resource Monitor Script
# Supports Ubuntu 24.04 and macOS
# Usage: ./main.sh [refresh_interval_seconds]

# Default refresh interval is 2 seconds
REFRESH_INTERVAL=${1:-2}

# Use regular arrays to simulate associative arrays (compatible with old bash)
declare -a prev_rx_keys
declare -a prev_rx_values
declare -a prev_tx_values

# Function to get array value
get_prev_rx() {
    local key="$1"
    for i in "${!prev_rx_keys[@]}"; do
        if [ "${prev_rx_keys[$i]}" == "$key" ]; then
            echo "${prev_rx_values[$i]}"
            return
        fi
    done
    echo ""
}

get_prev_tx() {
    local key="$1"
    for i in "${!prev_rx_keys[@]}"; do
        if [ "${prev_rx_keys[$i]}" == "$key" ]; then
            echo "${prev_tx_values[$i]}"
            return
        fi
    done
    echo ""
}

# Function to set array value
set_prev_values() {
    local key="$1"
    local rx="$2"
    local tx="$3"

    for i in "${!prev_rx_keys[@]}"; do
        if [ "${prev_rx_keys[$i]}" == "$key" ]; then
            prev_rx_values[$i]="$rx"
            prev_tx_values[$i]="$tx"
            return
        fi
    done

    # If not exists, add new item
    prev_rx_keys+=("$key")
    prev_rx_values+=("$rx")
    prev_tx_values+=("$tx")
}

# Color definitions
COLOR_RESET=$'\033[0m'
COLOR_WHITE=$'\033[37m'
COLOR_YELLOW=$'\033[33m'
COLOR_BLACK=$'\033[30m'
COLOR_RED=$'\033[31m'
COLOR_BLACK_BG=$'\033[43m'  # Yellow background for black text

# Cursor control
CURSOR_HIDE=$'\033[?25l'
CURSOR_SHOW=$'\033[?25h'
CURSOR_HOME=$'\033[H'
CLEAR_LINE=$'\033[2K'
CLEAR_SCREEN=$'\033[2J'

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)

# Get color based on value
get_color() {
    local value=$1
    if (( $(echo "$value < 30" | bc -l) )); then
        echo "$COLOR_WHITE"
    elif (( $(echo "$value < 80" | bc -l) )); then
        echo "$COLOR_YELLOW"
    elif (( $(echo "$value < 95" | bc -l) )); then
        echo "$COLOR_BLACK_BG$COLOR_BLACK"
    else
        echo "$COLOR_RED"
    fi
}

# Get CPU usage
get_cpu_usage() {
    if [ "$OS" == "linux" ]; then
        cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}')
        if [ -z "$cpu_idle" ]; then
            cpu_idle=$(top -bn1 | grep "%Cpu" | awk '{print $8}')
        fi
        if [ -n "$cpu_idle" ]; then
            cpu_usage=$(echo "100 - $cpu_idle" | bc)
        else
            cpu_usage=0
        fi
    elif [ "$OS" == "macos" ]; then
        cpu_usage=$(top -l 1 -n 0 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
        if [ -z "$cpu_usage" ]; then
            cpu_usage=0
        fi
    else
        cpu_usage=0
    fi
    echo "$cpu_usage"
}

# Get memory usage
get_memory_usage() {
    if [ "$OS" == "linux" ]; then
        mem_info=$(free | grep Mem)
        mem_total=$(echo "$mem_info" | awk '{print $2}')
        mem_used=$(echo "$mem_info" | awk '{print $3}')
        if [ -n "$mem_total" ] && [ "$mem_total" -gt 0 ]; then
            mem_usage=$(echo "scale=2; $mem_used * 100 / $mem_total" | bc)
        else
            mem_usage=0
        fi
    elif [ "$OS" == "macos" ]; then
        vm_stat_output=$(vm_stat)
        page_size=$(vm_stat | grep "page size" | awk '{print $8}' | sed 's/\.//')
        if [ -z "$page_size" ]; then
            page_size=4096
        fi

        pages_free=$(echo "$vm_stat_output" | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
        pages_active=$(echo "$vm_stat_output" | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
        pages_inactive=$(echo "$vm_stat_output" | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
        pages_wired=$(echo "$vm_stat_output" | grep "Pages wired down" | awk '{print $4}' | sed 's/\.//')
        pages_speculative=$(echo "$vm_stat_output" | grep "Pages speculative" | awk '{print $3}' | sed 's/\.//')

        pages_free=${pages_free:-0}
        pages_active=${pages_active:-0}
        pages_inactive=${pages_inactive:-0}
        pages_wired=${pages_wired:-0}
        pages_speculative=${pages_speculative:-0}

        mem_total=$(sysctl -n hw.memsize)
        mem_used=$(( (pages_active + pages_inactive + pages_wired + pages_speculative) * page_size ))

        if [ "$mem_total" -gt 0 ]; then
            mem_usage=$(echo "scale=2; $mem_used * 100 / $mem_total" | bc)
        else
            mem_usage=0
        fi
    else
        mem_usage=0
    fi
    echo "$mem_usage"
}

# Get network interface list
get_network_interfaces() {
    if [ "$OS" == "linux" ]; then
        ip -o link show | awk -F': ' '{print $2}' | grep -v "^lo$" | grep -v "docker" | grep -v "veth" | grep -v "br-"
    elif [ "$OS" == "macos" ]; then
        networksetup -listallhardwareports | grep "Device:" | awk '{print $2}'
    else
        echo ""
    fi
}

# Get network usage
get_network_usage() {
    local interface=$1

    if [ "$OS" == "linux" ]; then
        if [ -f /proc/net/dev ]; then
            rx_bytes=$(cat /proc/net/dev | grep "$interface:" | awk '{print $2}')
            tx_bytes=$(cat /proc/net/dev | grep "$interface:" | awk '{print $10}')
            echo "$rx_bytes $tx_bytes"
        else
            echo "0 0"
        fi
    elif [ "$OS" == "macos" ]; then
        netstat -ib | grep "$interface" | head -1 | awk '{print $7 " " $10}'
    else
        echo "0 0"
    fi
}

# Get disk IO usage
get_disk_io_usage() {
    if [ "$OS" == "linux" ]; then
        if command -v iostat &> /dev/null; then
            disk_usage=$(iostat -x 1 2 | tail -n +4 | awk '{if($1 ~ /^[sh]d/ || $1 ~ /^nvme/ || $1 ~ /^vd/) print $NF}' | head -1)
            if [ -z "$disk_usage" ]; then
                disk_usage=0
            fi
        else
            disk_usage=0
        fi
    elif [ "$OS" == "macos" ]; then
        if command -v iostat &> /dev/null; then
            disk_usage=$(iostat -d -c 2 | tail -1 | awk '{print $1}')
            if [ -z "$disk_usage" ]; then
                disk_usage=0
            fi
        else
            disk_usage=0
        fi
    else
        disk_usage=0
    fi
    echo "$disk_usage"
}

# Print line with cursor control
print_line() {
    printf "%s\r%s" "$CLEAR_LINE" "$1"
}

# Move cursor up
move_up() {
    local lines=$1
    printf "\033[%dA" "$lines"
}

# Display header (only once)
display_header() {
    printf "%s%s" "$CLEAR_SCREEN" "$CURSOR_HOME"
    echo "========================================"
    printf "       System Monitor - %s\n" "$OS"
    echo "========================================"
    echo ""
}

# Display stats (in-place update)
display_stats() {
    local line_count=0

    # CPU Usage
    cpu_usage=$(get_cpu_usage)
    cpu_color=$(get_color "$cpu_usage")
    print_line "CPU Usage:    ${cpu_color}$(printf '%6.2f%%' "$cpu_usage")${COLOR_RESET}"
    echo ""
    ((line_count++))

    # Memory Usage
    mem_usage=$(get_memory_usage)
    mem_color=$(get_color "$mem_usage")
    print_line "Memory Usage: ${mem_color}$(printf '%6.2f%%' "$mem_usage")${COLOR_RESET}"
    echo ""
    ((line_count++))

    echo ""
    ((line_count++))
    print_line "----------------------------------------"
    echo ""
    ((line_count++))
    print_line "Network Bandwidth (per interface)"
    echo ""
    ((line_count++))
    print_line "----------------------------------------"
    echo ""
    ((line_count++))

    # Network bandwidth
    interfaces=$(get_network_interfaces)
    local interface_count=0
    if [ -n "$interfaces" ]; then
        for interface in $interfaces; do
            current_stats=$(get_network_usage "$interface")
            rx_current=$(echo "$current_stats" | awk '{print $1}')
            tx_current=$(echo "$current_stats" | awk '{print $2}')

            prev_rx_val=$(get_prev_rx "$interface")
            prev_tx_val=$(get_prev_tx "$interface")
            if [ -n "$prev_rx_val" ] && [ -n "$prev_tx_val" ]; then
                rx_diff=$((rx_current - prev_rx_val))
                tx_diff=$((tx_current - prev_tx_val))

                rx_rate=$(echo "scale=2; $rx_diff / 1024 / $REFRESH_INTERVAL" | bc)
                tx_rate=$(echo "scale=2; $tx_diff / 1024 / $REFRESH_INTERVAL" | bc)

                rx_percent=$(echo "scale=2; $rx_rate / 1024 * 100" | bc)
                tx_percent=$(echo "scale=2; $tx_rate / 1024 * 100" | bc)

                if (( $(echo "$rx_percent > 100" | bc -l) )); then
                    rx_percent=100
                fi
                if (( $(echo "$tx_percent > 100" | bc -l) )); then
                    tx_percent=100
                fi

                rx_color=$(get_color "$rx_percent")
                tx_color=$(get_color "$tx_percent")

                print_line "$(printf 'Iface: %-8s RX: %s%8.2f KB/s%s  TX: %s%8.2f KB/s%s' "$interface" "$rx_color" "$rx_rate" "$COLOR_RESET" "$tx_color" "$tx_rate" "$COLOR_RESET")"
            else
                print_line "$(printf 'Iface: %-8s RX: %10s  TX: %10s' "$interface" "Calculating..." "Calculating...")"
            fi
            echo ""
            ((line_count++))
            ((interface_count++))

            set_prev_values "$interface" "$rx_current" "$tx_current"
        done
    else
        print_line "No network interfaces found"
        echo ""
        ((line_count++))
    fi

    echo ""
    ((line_count++))
    print_line "----------------------------------------"
    echo ""
    ((line_count++))
    print_line "Disk IO"
    echo ""
    ((line_count++))
    print_line "----------------------------------------"
    echo ""
    ((line_count++))

    # Disk IO
    disk_usage=$(get_disk_io_usage)
    disk_color=$(get_color "$disk_usage")
    print_line "Disk IO Usage: ${disk_color}$(printf '%6.2f%%' "$disk_usage")${COLOR_RESET}"
    echo ""
    ((line_count++))

    echo ""
    ((line_count++))
    print_line "========================================"
    echo ""
    ((line_count++))
    print_line "Interval: ${REFRESH_INTERVAL}s | Press Ctrl+C to exit"
    echo ""
    ((line_count++))
    print_line "========================================"
    echo ""
    ((line_count++))

    # Move cursor back to the top of the stats area
    move_up "$line_count"
}

# Check dependencies
check_dependencies() {
    local missing_deps=()

    if ! command -v bc &> /dev/null; then
        missing_deps+=("bc")
    fi

    if [ "$OS" == "linux" ]; then
        if ! command -v top &> /dev/null; then
            missing_deps+=("procps")
        fi
        if ! command -v free &> /dev/null; then
            missing_deps+=("procps")
        fi
        if ! command -v iostat &> /dev/null; then
            missing_deps+=("sysstat")
        fi
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Error: Missing dependencies: ${missing_deps[*]}"
        echo "Please run ./install.sh to install dependencies"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    printf "%s%s\n\n" "$CURSOR_SHOW" "$CLEAR_LINE"
    echo "Monitor stopped"
    exit 0
}

# Main function
main() {
    check_dependencies

    # Hide cursor
    printf "%s" "$CURSOR_HIDE"

    display_header

    # First display to initialize network data
    display_stats
    sleep "$REFRESH_INTERVAL"

    # Main loop
    while true; do
        display_stats
        sleep "$REFRESH_INTERVAL"
    done
}

# Trap Ctrl+C
trap cleanup INT

main
