#!/bin/bash
# Setup Skills Symlinks for Kilo Code Extension in DevContainer

set -e

echo "🔧 Setting up skills symlinks for Kilo Code extension..."

# Target directory for skills
TARGET_DIR="/home/vscode/.kilocode/skills"

# Source directories
RULES_DIR="/home/vscode/.kilocode/rules"
MEMORY_BANK_DIR="/home/vscode/.kilocode/memory_bank"

# Create target directory if it doesn't exist
if [ ! -d "$TARGET_DIR" ]; then
    echo "📁 Creating target directory: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
fi

# Link generic skills
echo ""
echo "🔗 Linking generic skills..."
GENERIC_SKILLS=(
    "frontend_ui:docs/generic/FRONTEND_SKILLS.md"
    "terminal_tricks:docs/generic/TERMINAL_TRICKS.md"
    "refactoring:docs/generic/REFACTORING_SKILLS.md"
    "security:docs/generic/SECURITY_POLICIES.md"
    "hallucination_guards:docs/generic/HALLUCINATION_GUARDS.md"
    "verification_rituals:docs/generic/VERIFICATION_RITUALS.md"
    "role_protocols:docs/generic/ROLE_PROTOCOLS.md"
    "memory_bank:docs/generic/MEMORY_BANK_SKILL.md"
)

for skill in "${GENERIC_SKILLS[@]}"; do
    IFS=':' read -r NAME SOURCE <<< "$skill"
    if [ -f "$RULES_DIR/$(basename $SOURCE)" ]; then
        ln -sf "$RULES_DIR/$(basename $SOURCE)" "$TARGET_DIR/${NAME}.md"
        echo "  ✅ Linked: ${NAME}.md"
    else
        echo "  ⚠️  Skipped: ${NAME}.md (source not found)"
    fi
done

# Link language-specific skills
echo ""
echo "🔗 Linking language-specific skills..."
LANGS=("crystal" "elixir" "gleam" "elm" "nim")

for lang in "${LANGS[@]}"; do
    LANG_DIR="$RULES_DIR/$lang"
    if [ -d "$LANG_DIR" ]; then
        # Link main skills file
        MAIN_SKILL="${LANG_DIR}/${lang^^}_SKILLS.md"
        if [ -f "$MAIN_SKILL" ]; then
            ln -sf "$MAIN_SKILL" "$TARGET_DIR/${lang}_skills.md"
            echo "  ✅ Linked: ${lang}_skills.md"
        fi

        # Link other language-specific docs as skills
        for file in "$LANG_DIR"/*.md; do
            if [ -f "$file" ]; then
                BASENAME=$(basename "$file" .md)
                # Skip main skills file (already linked above)
                if [ "$BASENAME" != "${lang^^}_SKILLS" ]; then
                    SKILL_NAME=$(echo "$BASENAME" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
                    ln -sf "$file" "$TARGET_DIR/${lang}_${SKILL_NAME}.md"
                    echo "  ✅ Linked: ${lang}_${SKILL_NAME}.md"
                fi
            fi
        done
    else
        echo "  ⚠️  Skipped: $lang (directory not found)"
    fi
done

# Link memory bank files
echo ""
echo "🔗 Linking memory bank files..."
if [ -d "$MEMORY_BANK_DIR" ]; then
    for file in "$MEMORY_BANK_DIR"/*.md; do
        if [ -f "$file" ]; then
            BASENAME=$(basename "$file")
            ln -sf "$file" "$TARGET_DIR/memory_bank_${BASENAME}"
            echo "  ✅ Linked: memory_bank_${BASENAME}"
        fi
    done
else
    echo "  ⚠️  Memory bank directory not found: $MEMORY_BANK_DIR"
fi

echo ""
echo "✨ Skills setup complete!"
echo ""
echo "📊 Summary:"
echo "  📁 Skills directory: $TARGET_DIR"
echo "  🔗 Symlinks created from:"
echo "     - $RULES_DIR (generic and language skills)"
echo "     - $MEMORY_BANK_DIR (memory bank)"
echo ""
echo "💡 Tip: Reload VSCode window to apply changes (Ctrl+Shift+P > Developer: Reload Window)"
