# I was getting errors saying compinit was not found. This line fixed it
autoload -U +X compinit && compinit

eval "$(gs shell completion zsh)"

# Format: "Category|alias_name" -> "command"
typeset -A _gs_aliases=(
  "Repository|gss" "gs repo sync"
  "Navigation|gsu" "gs up"
  "Navigation|gsd" "gs down"
  "Navigation|gst" "gs top"
  "Navigation|gsb" "gs bottom"
  "Navigation|gstrunk" "gs trunk"
  "Branch|gsco" "gs b checkout"
  "Branch|gsc" "gs b create"
  "Branch|gscm" "gs b create --target main"
  "Branch|gsub" "gs b submit"
  "Branch|gsr" "gs b restack"
  "Branch|gsrm" "gs b delete"
  "Branch|gsmv" "gs b rename"
  "Stack|gssr" "gs s restack"
  "Stack|gsse" "gs s edit"
  "Stack|gssub" "gs s submit"
  "Rebase|gsrc" "gs rebase continue"
  "Rebase|gsra" "gs rebase abort"
  "Log|gsl" "gs log short"
  "Log|gsll" "gs log long"
)

# Generate aliases
for key cmd in ${(kv)_gs_aliases}; do
  local alias_name=${key#*|}
  alias $alias_name="$cmd"
done

# Quick reference function
gs-aliases() {
  echo "Git-spice aliases:\n"

  # Extract unique categories from keys
  local categories=($(print -l ${(k)_gs_aliases} | cut -d'|' -f1 | sort -u))

  for category in $categories; do
    echo "$category:"
    for key in ${(k)_gs_aliases}; do
      if [[ $key == $category\|* ]]; then
        local alias_name=${key#*|}
        printf "  %-12s  %s\n" "$alias_name" "${_gs_aliases[$key]}"
      fi
    done
    echo
  done
}
