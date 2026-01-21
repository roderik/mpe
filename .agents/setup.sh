#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/setup.json"

# Check dependencies
if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed"
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: $CONFIG_FILE not found"
    exit 1
fi

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
        output=$(eval "npx -y skills add \"$repo\" -y $agents $skills" 2>&1) && exit_code=$? || exit_code=$?

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

    # Update .claude/CLAUDE.md
    local claude_file="$SCRIPT_DIR/../.claude/CLAUDE.md"
    if [[ -f "$claude_file" ]]; then
        update_file_routing_table "$claude_file" "$table_content"
        echo "Updated routing table in .claude/CLAUDE.md"
    fi

    # Update .codex/AGENTS.md
    local codex_file="$SCRIPT_DIR/../.codex/AGENTS.md"
    if [[ -f "$codex_file" ]]; then
        update_file_routing_table "$codex_file" "$table_content"
        echo "Updated routing table in .codex/AGENTS.md"
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

install_skills
run_post_install
update_routing_tables
