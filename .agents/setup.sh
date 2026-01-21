#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
CONFIG_FILE="$SCRIPT_DIR/setup.json"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

# Check dependencies
if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed"
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: $CONFIG_FILE not found"
    exit 1
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

# Install skills from config
install_skills() {
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
    local cmd_count
    cmd_count=$(jq -r '.postInstall // [] | length' "$CONFIG_FILE")

    if [[ $cmd_count -eq 0 ]]; then
        return
    fi

    echo "Running post-install commands..."

    for ((i = 0; i < cmd_count; i++)); do
        local cmd
        cmd=$(jq -r ".postInstall[$i]" "$CONFIG_FILE")

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

# Update routing tables in agent configuration files
update_routing_tables() {
    local skills_dir="$SCRIPT_DIR/skills"
    local routing_content=""

    if [[ ! -d "$skills_dir" ]]; then
        echo "No skills directory found, skipping routing table update"
        return
    fi

    # Find all SKILL.md files and extract frontmatter
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
                # Check if we're in a multiline description
                if [[ "$reading_multiline_desc" == true ]]; then
                    # If line starts with a field name (word followed by colon), stop multiline
                    if [[ "$line" =~ ^[a-zA-Z_-]+: ]]; then
                        reading_multiline_desc=false
                    elif [[ -n "$line" ]]; then
                        # Append to description (trim leading whitespace)
                        local trimmed_line="${line#"${line%%[![:space:]]*}"}"
                        if [[ -n "$trimmed_line" ]]; then
                            skill_description+=" $trimmed_line"
                        fi
                        continue
                    fi
                fi

                if [[ "$line" =~ ^name:\ *(.+)$ ]]; then
                    skill_name="${BASH_REMATCH[1]}"
                elif [[ "$line" =~ ^description:\ *\>$ ]] || [[ "$line" =~ ^description:\ *\|$ ]]; then
                    # Multiline YAML description (folded > or literal |)
                    skill_description=""
                    reading_multiline_desc=true
                elif [[ "$line" =~ ^description:\ *(.+)$ ]]; then
                    skill_description="${BASH_REMATCH[1]}"
                    # Remove surrounding quotes if present
                    skill_description="${skill_description#\"}"
                    skill_description="${skill_description%\"}"
                fi
            fi
        done <"$skill_file"

        # Clean up description - collapse multiple spaces
        skill_description=$(echo "$skill_description" | tr -s ' ' | sed 's/^ //')

        if [[ -n "$skill_name" && -n "$skill_description" ]]; then
            routing_content+="| $skill_description | \`Skill({ skill: \"$skill_name\" })\` |"$'\n'
        fi
    done < <(find "$skills_dir" -name "SKILL.md" -print0 2>/dev/null)

    # Build the full table if we have content
    local table_content=""
    if [[ -n "$routing_content" ]]; then
        table_content="| When to use | Invocation |"$'\n'
        table_content+="| ----------- | ---------- |"$'\n'
        table_content+="$routing_content"
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

copy_templates
install_skills
update_workflows
update_routing_tables
run_post_install || echo "Note: Some post-install commands failed (this is expected in web environments)"
