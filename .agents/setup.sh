#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
CONFIG_FILE="$SCRIPT_DIR/setup.json"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
COMMANDS_DIR="$SCRIPT_DIR/commands"
CODEX_PROMPTS_DIR=""
RUN_CODEX_MCP=1
RUN_POST_INSTALL=1
RUN_SKILLS=1
DOCS_ONLY=0

for arg in "$@"; do
    case "$arg" in
        --skip-postinstall)
            RUN_POST_INSTALL=0
            ;;
        --skip-skills)
            RUN_SKILLS=0
            ;;
        --docs-only)
            RUN_POST_INSTALL=0
            RUN_SKILLS=0
            DOCS_ONLY=1
            ;;
        --lite)
            RUN_POST_INSTALL=0
            ;;
        --skip-codex-mcp)
            RUN_CODEX_MCP=0
            ;;
    esac
done

# Check dependencies
if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed"
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: $CONFIG_FILE not found"
    exit 1
fi

if [[ -n "$HOME" ]]; then
    CODEX_PROMPTS_DIR="$HOME/.codex/prompts"
else
    CODEX_PROMPTS_DIR="$PROJECT_ROOT/.codex/prompts"
fi

# Copy templates to project
copy_templates() {
    if [[ ! -d "$TEMPLATES_DIR" ]]; then
        return
    fi

    echo "Setting up project files..."

    # Always copy settings.json and session-start script
    mkdir -p "$PROJECT_ROOT/.claude/scripts/web/session-start"
    cp "$TEMPLATES_DIR/.claude/settings.json" "$PROJECT_ROOT/.claude/settings.json"
    cp "$TEMPLATES_DIR/.claude/scripts/web/session-start/setup.sh" "$PROJECT_ROOT/.claude/scripts/web/session-start/setup.sh"
    chmod +x "$PROJECT_ROOT/.claude/scripts/web/session-start/setup.sh"

    # Only copy MD files if they don't exist (at project root)
    if [[ ! -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
        cp "$TEMPLATES_DIR/CLAUDE.md" "$PROJECT_ROOT/CLAUDE.md"
    fi

    if [[ ! -f "$PROJECT_ROOT/AGENTS.md" ]]; then
        cp "$TEMPLATES_DIR/AGENTS.md" "$PROJECT_ROOT/AGENTS.md"
    fi
}

# Copy commands to agent-specific folders
copy_commands() {
    if [[ ! -d "$COMMANDS_DIR" ]]; then
        return
    fi

    local command_files
    command_files=$(find "$COMMANDS_DIR" -name "*.md" -type f 2>/dev/null)

    if [[ -z "$command_files" ]]; then
        return
    fi

    echo "Setting up commands..."

    # Get configured agents
    local agents
    agents=$(jq -r '.agents // ["claude-code"] | .[]' "$CONFIG_FILE" 2>/dev/null)

    for agent in $agents; do
        case "$agent" in
            claude-code|claude)
                # Claude Code uses .claude/commands/
                mkdir -p "$PROJECT_ROOT/.claude/commands"
                for cmd_file in $command_files; do
                    local filename
                    filename=$(basename "$cmd_file")
                    cp "$cmd_file" "$PROJECT_ROOT/.claude/commands/$filename"
                done
                echo "  Copied commands to .claude/commands/"
                ;;
            codex)
                # Codex custom prompts live in ~/.codex/prompts
                mkdir -p "$CODEX_PROMPTS_DIR"
                for cmd_file in $command_files; do
                    local filename
                    filename=$(basename "$cmd_file")
                    cp "$cmd_file" "$CODEX_PROMPTS_DIR/$filename"
                done
                echo "  Copied commands to $CODEX_PROMPTS_DIR"
                ;;
        esac
    done

    echo "Commands installed successfully"
}

# Generate .mcp.json from config
generate_mcp_json() {
    local mcp_servers
    mcp_servers=$(jq -r '.mcpServers // empty' "$CONFIG_FILE")

    if [[ -z "$mcp_servers" || "$mcp_servers" == "null" ]]; then
        return
    fi

    echo "Generating .mcp.json..."

    local mcp_json
    mcp_json=$(jq -n --argjson servers "$mcp_servers" '{ mcpServers: $servers }')

    echo "$mcp_json" > "$PROJECT_ROOT/.mcp.json"
    echo "Generated .mcp.json with MCP server configurations"
}

# Configure Codex MCP servers in global config
configure_codex_mcp() {
    if [[ $RUN_CODEX_MCP -ne 1 ]]; then
        return
    fi

    local mcp_servers
    mcp_servers=$(jq -r '.mcpServers // empty' "$CONFIG_FILE")

    if [[ -z "$mcp_servers" || "$mcp_servers" == "null" ]]; then
        return
    fi

    local codex_home="${CODEX_HOME:-$HOME/.codex}"
    if [[ -z "$codex_home" ]]; then
        codex_home="$PROJECT_ROOT/.codex"
    fi

    local config_file="$codex_home/config.toml"
    mkdir -p "$codex_home"

    local tmp_file
    tmp_file=$(mktemp)

    if [[ -f "$config_file" ]]; then
        cp "$config_file" "$tmp_file"
    else
        : >"$tmp_file"
    fi

    local names
    names=$(echo "$mcp_servers" | jq -r 'keys[]')

    for name in $names; do
        local tmp_out
        tmp_out=$(mktemp)
        awk -v target="mcp_servers.${name}" '
        function is_header(line) { return line ~ /^\[[^]]+\]/ }
        {
          if ($0 == "[" target "]") { skip=1; next }
          if (skip && is_header($0)) { skip=0 }
          if (!skip) print $0
        }
      ' "$tmp_file" >"$tmp_out"
        mv "$tmp_out" "$tmp_file"
    done

    printf '\n' >>"$tmp_file"

    for name in $names; do
        local server_json url command args
        server_json=$(echo "$mcp_servers" | jq -c --arg name "$name" '.[$name]')
        url=$(echo "$server_json" | jq -r '.url // empty')
        command=$(echo "$server_json" | jq -r '.command // empty')
        args=$(echo "$server_json" | jq -c '.args // empty')

        {
            printf '[mcp_servers.%s]\n' "$name"
            if [[ -n "$url" ]]; then
                printf 'url = "%s"\n' "$url"
            fi
            if [[ -n "$command" ]]; then
                printf 'command = "%s"\n' "$command"
            fi
            if [[ -n "$args" && "$args" != "null" && "$args" != "[]" ]]; then
                printf 'args = %s\n' "$args"
            fi
            printf '\n'
        } >>"$tmp_file"
    done

    mv "$tmp_file" "$config_file"
    echo "Updated Codex MCP config at $config_file"
}

# Install skills from config
install_skills() {
    if [[ $RUN_SKILLS -ne 1 ]]; then
        return
    fi

    local agents
    agents=$(jq -r '.agents | map("-a " + .) | join(" ")' "$CONFIG_FILE")

    local repo_count
    repo_count=$(jq -r '.skills | length' "$CONFIG_FILE")

    for ((i = 0; i < repo_count; i++)); do
        local repo
        repo=$(jq -r ".skills[$i].repo" "$CONFIG_FILE")

        local skills
        skills=$(jq -r ".skills[$i].skills | map(\"--skill \\\"\" + . + \"\\\"\") | join(\" \")" "$CONFIG_FILE")

        echo "Installing skills from $repo..."

        local output
        local exit_code
        output=$(eval "npx -y skills@latest add \"$repo\" -y $agents $skills" 2>&1) && exit_code=$? || exit_code=$?

        if [[ $exit_code -ne 0 ]]; then
            echo "Error installing skills from $repo:"
            echo "$output"
            exit 1
        fi
    done

    echo "All skills installed successfully"
}

# Run post-install commands from config
run_post_install() {
    if [[ $RUN_POST_INSTALL -ne 1 ]]; then
        return
    fi

    local cmd_count
    local post_type
    post_type=$(jq -r '.postInstall | type' "$CONFIG_FILE")
    local os_key=""
    local cmds=()
    local os_cmds=()

    case "$(uname -s)" in
        Darwin) os_key="darwin" ;;
        Linux) os_key="linux" ;;
        MINGW*|MSYS*|CYGWIN*) os_key="windows" ;;
    esac

    if [[ "$post_type" == "array" ]]; then
        mapfile -t cmds < <(jq -r '.postInstall[]' "$CONFIG_FILE")
    elif [[ "$post_type" == "object" ]]; then
        mapfile -t cmds < <(jq -r '.postInstall.common // [] | .[]' "$CONFIG_FILE")
        if [[ -n "$os_key" ]]; then
            mapfile -t os_cmds < <(jq -r --arg os "$os_key" '.postInstall[$os] // [] | .[]' "$CONFIG_FILE")
            cmds+=("${os_cmds[@]}")
        fi
    else
        return
    fi

    cmd_count=${#cmds[@]}

    if [[ $cmd_count -eq 0 ]]; then
        return
    fi

    echo "Running post-install commands..."

    for ((i = 0; i < cmd_count; i++)); do
        local cmd="${cmds[$i]}"

        echo "  Running: $cmd"

        local output
        local exit_code
        output=$(eval "$cmd" 2>&1) && exit_code=$? || exit_code=$?

        if [[ $exit_code -ne 0 ]]; then
            echo "Error running post-install command: $cmd"
            echo "$output"
            exit 1
        fi
    done

    echo "Post-install commands completed"
}

# Compile hierarchical skill routing from config
compile_skill_routing() {
    local routing_json
    routing_json=$(jq -r '.skillRouting // empty' "$CONFIG_FILE")

    if [[ -z "$routing_json" || "$routing_json" == "null" ]]; then
        return ""
    fi

    local md=""
    local cat_count
    cat_count=$(echo "$routing_json" | jq -r '.categories | length')

    for ((c = 0; c < cat_count; c++)); do
        local category
        category=$(echo "$routing_json" | jq -r ".categories[$c]")

        local cat_name cat_triggers
        cat_name=$(echo "$category" | jq -r '.name')
        cat_triggers=$(echo "$category" | jq -r '.triggers | join(", ")')

        md+="### $cat_name"$'\n'
        md+="**Triggers:** $cat_triggers"$'\n\n'
        md+="| Trigger Phrases | Invocation |"$'\n'
        md+="|-----------------|------------|"$'\n'

        local skill_count
        skill_count=$(echo "$category" | jq -r '.skills | length')

        for ((s = 0; s < skill_count; s++)); do
            local skill skill_name skill_triggers skill_note
            skill=$(echo "$category" | jq -r ".skills[$s]")
            skill_name=$(echo "$skill" | jq -r '.name')
            skill_triggers=$(echo "$skill" | jq -r '.triggers | join(", ")')
            skill_note=$(echo "$skill" | jq -r '.note // empty')

            local triggers_col="$skill_triggers"
            [[ -n "$skill_note" ]] && triggers_col+=" *(${skill_note})*"
            md+="| $triggers_col | \`Skill({ skill: \"$skill_name\" })\` |"$'\n'
        done
        md+=$'\n'
    done

    echo "$md"
}

# Update routing tables in agent configuration files
update_routing_tables() {
    local table_content=""

    # Try hierarchical routing from config first
    local hierarchical_content
    hierarchical_content=$(compile_skill_routing)

    if [[ -n "$hierarchical_content" ]]; then
        table_content="$hierarchical_content"
    else
        # Fallback: extract from SKILL.md files
        local skills_dir="$SCRIPT_DIR/skills"
        local entries=()

        if [[ -d "$skills_dir" ]]; then
            while IFS= read -r -d '' skill_file; do
                local skill_name=""
                local skill_description=""
                local in_frontmatter=false
                local frontmatter_started=false
                local reading_multiline_desc=false

                while IFS= read -r line; do
                    if [[ "$line" == "---" ]]; then
                        if [[ "$frontmatter_started" == false ]]; then
                            frontmatter_started=true
                            in_frontmatter=true
                            continue
                        else
                            break
                        fi
                    fi

                    if [[ "$in_frontmatter" == true ]]; then
                        if [[ "$reading_multiline_desc" == true ]]; then
                            if [[ "$line" =~ ^[a-zA-Z_-]+: ]]; then
                                reading_multiline_desc=false
                            elif [[ -n "$line" ]]; then
                                local trimmed_line="${line#"${line%%[![:space:]]*}"}"
                                [[ -n "$trimmed_line" ]] && skill_description+=" $trimmed_line"
                                continue
                            fi
                        fi

                        if [[ "$line" =~ ^name:\ *(.+)$ ]]; then
                            skill_name="${BASH_REMATCH[1]}"
                        elif [[ "$line" =~ ^description:\ *\>$ ]] || [[ "$line" =~ ^description:\ *\|$ ]]; then
                            skill_description=""
                            reading_multiline_desc=true
                        elif [[ "$line" =~ ^description:\ *(.+)$ ]]; then
                            skill_description="${BASH_REMATCH[1]}"
                            skill_description="${skill_description#\"}"
                            skill_description="${skill_description%\"}"
                        fi
                    fi
                done <"$skill_file"

                skill_description=$(echo "$skill_description" | tr -s ' ' | sed 's/^ //')

                if [[ -n "$skill_name" && -n "$skill_description" ]]; then
                    entries+=("$skill_name|$skill_description")
                fi
            done < <(find "$skills_dir" -name "SKILL.md" -print0 2>/dev/null)

            if [[ ${#entries[@]} -gt 0 ]]; then
                local routing_content
                routing_content=$(printf '%s\n' "${entries[@]}" | sort -t '|' -k1,1 | while IFS='|' read -r name desc; do
                    printf '| %s | `Skill({ skill: "%s" })` |\n' "$desc" "$name"
                done)
                table_content="| When to use | Invocation |"$'\n'
                table_content+="| ----------- | ---------- |"$'\n'
                table_content+="$routing_content"
            fi
        fi
    fi

    if [[ -z "$table_content" ]]; then
        echo "No skill routing content found"
        return
    fi

    # Update CLAUDE.md at project root
    local claude_file="$PROJECT_ROOT/CLAUDE.md"
    if [[ -f "$claude_file" ]]; then
        update_file_routing_table "$claude_file" "$table_content"
        echo "Updated routing table in CLAUDE.md"
    fi

    # Update AGENTS.md at project root
    local agents_file="$PROJECT_ROOT/AGENTS.md"
    if [[ -f "$agents_file" ]]; then
        update_file_routing_table "$agents_file" "$table_content"
        echo "Updated routing table in AGENTS.md"
    fi
}

update_file_routing_table() {
    local file="$1"
    local content="$2"
    local temp_file
    temp_file=$(mktemp)
    local content_file
    content_file=$(mktemp)

    printf '%s' "$content" >"$content_file"

    # Check if skill-routing-table tags exist
    if ! grep -q '<skill-routing-table>' "$file"; then
        # Append the tags to the end of the file
        {
            cat "$file"
            echo ""
            echo "<skill-routing-table>"
            cat "$content_file"
            echo "</skill-routing-table>"
        } >"$temp_file"
        mv "$temp_file" "$file"
        rm -f "$content_file"
        return
    fi

    # Replace content between tags (removes old content completely)
    awk -v content_file="$content_file" '
    BEGIN { in_section = 0 }
    /<skill-routing-table>/ {
      print
      in_section = 1
      next
    }
    /<\/skill-routing-table>/ {
      while ((getline line < content_file) > 0) {
        print line
      }
      close(content_file)
      print
      in_section = 0
      next
    }
    !in_section { print }
  ' "$file" >"$temp_file"

    mv "$temp_file" "$file"
    rm -f "$content_file"
}

# Compile workflow JSON to markdown
compile_workflow() {
    local workflow_json="$1"
    local md=""

    # Title and description
    local title
    title=$(echo "$workflow_json" | jq -r '.title // "Workflow"')
    local desc
    desc=$(echo "$workflow_json" | jq -r '.description // ""')
    md+="## $title"$'\n\n'
    [[ -n "$desc" ]] && md+="$desc"$'\n\n'

    # Principles
    local principles
    principles=$(echo "$workflow_json" | jq -r '.principles // empty')
    if [[ -n "$principles" && "$principles" != "null" ]]; then
        md+="### Principles"$'\n\n'
        local prin_count
        prin_count=$(echo "$principles" | jq -r 'length')
        for ((pr = 0; pr < prin_count; pr++)); do
            local prin
            prin=$(echo "$principles" | jq -r ".[$pr]")
            md+="- $prin"$'\n'
        done
        md+=$'\n'
    fi

    # Phases
    local phase_count
    phase_count=$(echo "$workflow_json" | jq -r '.phases | length')

    for ((p = 0; p < phase_count; p++)); do
        local phase
        phase=$(echo "$workflow_json" | jq -r ".phases[$p]")
        local name iter trigger alias with iron_law note cmd

        name=$(echo "$phase" | jq -r '.name')
        iter=$(echo "$phase" | jq -r '.iterations // empty')
        trigger=$(echo "$phase" | jq -r '.trigger // empty')
        alias=$(echo "$phase" | jq -r '.alias // empty')
        with=$(echo "$phase" | jq -r '.with // empty')
        iron_law=$(echo "$phase" | jq -r '.ironLaw // empty')
        note=$(echo "$phase" | jq -r '.note // empty')
        cmd=$(echo "$phase" | jq -r '.command // empty')

        # Phase header
        local header="### Phase $((p + 1)): $name"
        [[ -n "$iter" ]] && header+=" ($iter+ iterations)"
        md+="$header"$'\n\n'

        # Trigger line
        if [[ -n "$trigger" ]]; then
            md+="**Start:** \`$trigger\`"
            [[ -n "$alias" ]] && md+=" or \`$alias\`"
            md+=$'\n\n'
        fi

        # With line
        [[ -n "$with" ]] && md+="**With:** \`$with\`"$'\n\n'

        # Note
        [[ -n "$note" ]] && md+="$note"$'\n\n'

        # Command
        [[ -n "$cmd" ]] && md+="\`\`\`bash"$'\n'"$cmd"$'\n'"\`\`\`"$'\n\n'

        # Steps
        local steps
        steps=$(echo "$phase" | jq -r '.steps // .perTask // empty')
        if [[ -n "$steps" && "$steps" != "null" ]]; then
            local step_count
            step_count=$(echo "$steps" | jq -r 'length')
            for ((s = 0; s < step_count; s++)); do
                local step action tool snote cond
                step=$(echo "$steps" | jq -r ".[$s]")
                action=$(echo "$step" | jq -r '.action // empty')
                tool=$(echo "$step" | jq -r '.tool // empty')
                snote=$(echo "$step" | jq -r '.note // empty')
                cond=$(echo "$step" | jq -r '.condition // empty')
                scmd=$(echo "$step" | jq -r '.command // empty')

                local line="$((s + 1)). "
                if [[ -n "$action" ]]; then
                    line+="**$action**"
                    [[ -n "$tool" ]] && line+=" - \`$tool\`"
                elif [[ -n "$tool" ]]; then
                    line+="\`$tool\`"
                elif [[ -n "$scmd" ]]; then
                    line+="Run: \`$scmd\`"
                fi
                [[ -n "$cond" ]] && line+=" *(if $cond)*"
                [[ -n "$snote" ]] && line+=" - $snote"
                md+="$line"$'\n'
            done
            md+=$'\n'
        fi

        # Deepen list
        local deepen
        deepen=$(echo "$phase" | jq -r '.deepen // empty')
        if [[ -n "$deepen" && "$deepen" != "null" ]]; then
            md+="**Each iteration must deepen:** "
            md+=$(echo "$deepen" | jq -r 'join(", ")')
            md+="."$'\n\n'
        fi

        # Iron law
        [[ -n "$iron_law" ]] && md+="**Iron Law:** $iron_law"$'\n\n'
    done

    # Quick reference table
    local qr
    qr=$(echo "$workflow_json" | jq -r '.quickReference // empty')
    if [[ -n "$qr" && "$qr" != "null" ]]; then
        md+="### Quick Reference"$'\n\n'
        md+="| Phase | Tool | Purpose |"$'\n'
        md+="|-------|------|---------|"$'\n'
        local qr_count
        qr_count=$(echo "$qr" | jq -r 'length')
        for ((q = 0; q < qr_count; q++)); do
            local row ph tl pu
            row=$(echo "$qr" | jq -r ".[$q]")
            ph=$(echo "$row" | jq -r '.phase')
            tl=$(echo "$row" | jq -r '.tool')
            pu=$(echo "$row" | jq -r '.purpose')
            md+="| $ph | \`$tl\` | $pu |"$'\n'
        done
        md+=$'\n'
    fi

    # MCP servers reference table
    local mcp
    mcp=$(echo "$workflow_json" | jq -r '.mcpServersReference // empty')
    if [[ -n "$mcp" && "$mcp" != "null" ]]; then
        md+="### MCP Servers Reference"$'\n\n'
        md+="| Server | Tools | Purpose |"$'\n'
        md+="|--------|-------|---------|"$'\n'
        local mcp_count
        mcp_count=$(echo "$mcp" | jq -r 'length')
        for ((m = 0; m < mcp_count; m++)); do
            local row srv tools pu
            row=$(echo "$mcp" | jq -r ".[$m]")
            srv=$(echo "$row" | jq -r '.server')
            tools=$(echo "$row" | jq -r '.tools')
            pu=$(echo "$row" | jq -r '.purpose')
            md+="| \`mcp__${srv}__*\` | $tools | $pu |"$'\n'
        done
    fi

    echo "$md"
}

# Update workflows section from config
update_workflows() {
    local workflow_json
    workflow_json=$(jq -r '.workflow // empty' "$CONFIG_FILE")

    if [[ -z "$workflow_json" || "$workflow_json" == "null" ]]; then
        return
    fi

    local workflow_content
    workflow_content=$(compile_workflow "$workflow_json")

    # Update CLAUDE.md at project root
    local claude_file="$PROJECT_ROOT/CLAUDE.md"
    if [[ -f "$claude_file" ]]; then
        update_file_section "$claude_file" "$workflow_content" "workflows"
        echo "Updated workflows in CLAUDE.md"
    fi

    # Update AGENTS.md at project root
    local agents_file="$PROJECT_ROOT/AGENTS.md"
    if [[ -f "$agents_file" ]]; then
        update_file_section "$agents_file" "$workflow_content" "workflows"
        echo "Updated workflows in AGENTS.md"
    fi
}

update_file_section() {
    local file="$1"
    local content="$2"
    local tag="$3"
    local temp_file
    temp_file=$(mktemp)
    local content_file
    content_file=$(mktemp)

    printf '%s' "$content" >"$content_file"

    # Check if tags exist
    if ! grep -q "<$tag>" "$file"; then
        {
            cat "$file"
            echo ""
            echo "<$tag>"
            cat "$content_file"
            echo "</$tag>"
        } >"$temp_file"
        mv "$temp_file" "$file"
        rm -f "$content_file"
        return
    fi

    # Replace content between tags
    awk -v content_file="$content_file" -v tag="$tag" '
    BEGIN { in_section = 0 }
    $0 ~ "<"tag">" {
      print
      in_section = 1
      next
    }
    $0 ~ "</"tag">" {
      while ((getline line < content_file) > 0) {
        print line
      }
      close(content_file)
      print
      in_section = 0
      next
    }
    !in_section { print }
  ' "$file" >"$temp_file"

    mv "$temp_file" "$file"
    rm -f "$content_file"
}

if [[ $DOCS_ONLY -eq 1 ]]; then
    generate_mcp_json
    update_workflows
    update_routing_tables
    copy_commands
    exit 0
fi

copy_templates
copy_commands
generate_mcp_json
configure_codex_mcp
install_skills
update_workflows
update_routing_tables
run_post_install || echo "Note: Some post-install commands failed (this is expected in web environments)"
