#!/bin/bash

# Install skills
npx -y skills add better-auth/skills -y -a claude-code -a codex --skill "better-auth-best-practices"

# Update routing tables in agent configuration files
update_routing_tables() {
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local skills_dir="$script_dir/skills"
  local routing_content=""

  # Check if skills directory exists
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
        if [[ "$line" =~ ^name:\ *(.+)$ ]]; then
          skill_name="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^description:\ *(.+)$ ]]; then
          skill_description="${BASH_REMATCH[1]}"
        fi
      fi
    done < "$skill_file"

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
  local claude_file="$script_dir/../.claude/CLAUDE.md"
  if [[ -f "$claude_file" ]]; then
    update_file_routing_table "$claude_file" "$table_content"
    echo "Updated routing table in .claude/CLAUDE.md"
  fi

  # Update .codex/AGENTS.md
  local codex_file="$script_dir/../.codex/AGENTS.md"
  if [[ -f "$codex_file" ]]; then
    update_file_routing_table "$codex_file" "$table_content"
    echo "Updated routing table in .codex/AGENTS.md"
  fi
}

update_file_routing_table() {
  local file="$1"
  local content="$2"
  local temp_file=$(mktemp)
  local content_file=$(mktemp)

  # Write content to a temp file to avoid awk newline issues
  printf '%s' "$content" > "$content_file"

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
  ' "$file" > "$temp_file"

  mv "$temp_file" "$file"
  rm -f "$content_file"
}

update_routing_tables
