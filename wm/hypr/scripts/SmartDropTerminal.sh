#!/bin/bash
# /* ---- 💫 Smart Dropdown Terminal 💫 ---- */  ##
# Opens dropdown terminal in the same directory as the active VS Code workspace
# Usage: ./SmartDropTerminal.sh <terminal_command>

DEBUG=false
TERMINAL_CMD="$1"

# Debug echo function
debug_echo() {
    if [ "$DEBUG" = true ]; then
        echo "$@" >&2
    fi
}

# Function to get VS Code workspace directory
get_vscode_workspace_dir() {
    local active_window_pid
    local active_window_class
    local workspace_dir=""
    
    # Get active window info
    local active_window=$(hyprctl activewindow -j)
    active_window_pid=$(echo "$active_window" | jq -r '.pid // empty')
    active_window_class=$(echo "$active_window" | jq -r '.class // empty')
    
    debug_echo "Active window PID: $active_window_pid, Class: $active_window_class"
    
    # Check if current window is VS Code
    if [[ "$active_window_class" == *"code"* ]] || [[ "$active_window_class" == *"Code"* ]]; then
        debug_echo "Active window is VS Code"
        
        # Try to get workspace from VS Code process
        if [ -n "$active_window_pid" ]; then
            # Get command line of VS Code process to find workspace
            local cmdline=$(cat "/proc/$active_window_pid/cmdline" 2>/dev/null | tr '\0' ' ')
            debug_echo "VS Code cmdline: $cmdline"
            
            # Extract workspace path from command line arguments
            # Look for directory arguments (not starting with -)
            local potential_dirs=$(echo "$cmdline" | grep -oE '[^[:space:]]+' | grep -E '^/' | grep -v -E '\.(js|ts|json|md|txt|py|css|html)$')
            
            for dir in $potential_dirs; do
                if [ -d "$dir" ]; then
                    workspace_dir="$dir"
                    debug_echo "Found workspace directory: $workspace_dir"
                    break
                fi
            done
        fi
    fi
    
    # Fallback: try to find any VS Code window and get its workspace
    if [ -z "$workspace_dir" ]; then
        debug_echo "Trying to find any VS Code window"
        local vscode_windows=$(hyprctl clients -j | jq -r '.[] | select(.class | test("code|Code")) | .pid')
        
        for pid in $vscode_windows; do
            if [ -n "$pid" ]; then
                local cmdline=$(cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ')
                local potential_dirs=$(echo "$cmdline" | grep -oE '[^[:space:]]+' | grep -E '^/' | grep -v -E '\.(js|ts|json|md|txt|py|css|html)$')
                
                for dir in $potential_dirs; do
                    if [ -d "$dir" ]; then
                        workspace_dir="$dir"
                        debug_echo "Found workspace directory from VS Code window: $workspace_dir"
                        break 2
                    fi
                done
            fi
        done
    fi
    
    # Another fallback: check VS Code recent workspaces
    if [ -z "$workspace_dir" ]; then
        debug_echo "Checking VS Code recent workspaces"
        local vscode_storage="$HOME/.config/Code/User/workspaceStorage"
        
        if [ -d "$vscode_storage" ]; then
            # Get the most recently modified workspace
            local recent_workspace=$(find "$vscode_storage" -name "workspace.json" -exec stat -c '%Y %n' {} \; 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)
            
            if [ -n "$recent_workspace" ]; then
                local workspace_path=$(jq -r '.folder // empty' "$recent_workspace" 2>/dev/null | sed 's|^file://||')
                if [ -d "$workspace_path" ]; then
                    workspace_dir="$workspace_path"
                    debug_echo "Found workspace from recent: $workspace_dir"
                fi
            fi
        fi
    fi
    
    echo "$workspace_dir"
}

# Function to modify terminal command to change directory
modify_terminal_command() {
    local terminal_cmd="$1"
    local target_dir="$2"
    
    if [ -z "$target_dir" ]; then
        echo "$terminal_cmd"
        return
    fi
    
    debug_echo "Modifying terminal command to start in: $target_dir"
    
    # Handle different terminal types
    case "$terminal_cmd" in
        *kitty*)
            # For kitty, we need to pass the directory properly
            echo "$terminal_cmd --directory=\"$target_dir\""
            ;;
        *alacritty*)
            echo "$terminal_cmd --working-directory=\"$target_dir\""
            ;;
        *foot*)
            echo "$terminal_cmd --working-directory=\"$target_dir\""
            ;;
        *gnome-terminal*)
            echo "$terminal_cmd --working-directory=\"$target_dir\""
            ;;
        *xterm*)
            echo "cd \"$target_dir\" && $terminal_cmd"
            ;;
        *)
            # For unknown terminals, create a wrapper script
            local wrapper_script="/tmp/terminal_wrapper_$$.sh"
            cat > "$wrapper_script" << EOF
#!/bin/bash
cd "$target_dir"
exec $terminal_cmd
EOF
            chmod +x "$wrapper_script"
            echo "$wrapper_script"
            ;;
    esac
}

# Main logic
if [ -z "$TERMINAL_CMD" ]; then
    echo "Usage: $0 <terminal_command>"
    exit 1
fi

# Get VS Code workspace directory
workspace_dir=$(get_vscode_workspace_dir)

if [ -n "$workspace_dir" ]; then
    debug_echo "Using workspace directory: $workspace_dir"
    modified_cmd=$(modify_terminal_command "$TERMINAL_CMD" "$workspace_dir")
    debug_echo "Modified command: $modified_cmd"
else
    debug_echo "No VS Code workspace found, using default terminal"
    modified_cmd="$TERMINAL_CMD"
fi

# Call the original dropdown terminal script with modified command
exec "$(dirname "$0")/Dropterminal.sh" "$modified_cmd"