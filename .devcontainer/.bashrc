#!/bin/bash

########
# Git
########

function git_branch() {
    local branch
    branch="$( { git symbolic-ref -q --short HEAD || git rev-parse -q --short --verify HEAD; } 2>&- )"
    if [[ -n "$branch" ]]; then
        echo -n "$branch"
        return 0
    fi
    return 1
}

function in_git_dir() {
  git rev-parse --is-inside-work-tree > /dev/null 2>&1
}

function git_name() {
  git config user.name 2> /dev/null
}

function git_has_no_diff() {
  git diff --quiet HEAD 2> /dev/null
}

function git_status_marker() {
  if ! in_git_dir; then
    return 1
  fi

  local git_dir
  git_dir=$(git rev-parse --git-dir 2>/dev/null)

  # Rebase states
  if [[ -d "$git_dir/rebase-merge" ]]; then
    echo -n " REBASE-i"
    return 0
  elif [[ -d "$git_dir/rebase-apply" ]]; then
    if [[ -f "$git_dir/rebase-apply/rebasing" ]]; then
      echo -n " REBASE"
      return 0
    elif [[ -f "$git_dir/rebase-apply/applying" ]]; then
      echo -n " AM"
      return 0
    else
      echo -n " REBASE"
      return 0
    fi
  fi

  # Merge state
  if [[ -f "$git_dir/MERGE_HEAD" ]]; then
    echo -n " MERGING"
    return 0
  fi

  # Bisect state
  if [[ -f "$git_dir/BISECT_LOG" ]]; then
    echo -n " BISECTING"
    return 0
  fi

  # Dirty state: unstaged or staged changes
  if ! git_has_no_diff; then
    echo -n " *"
    return 0
  fi

  return 0
}

########
# PROMPT
########

export WHITE='\[\033[1;37m\]'
export LIGHT_GREEN='\[\033[0;32m\]'
export LIGHT_BLUE='\[\033[0;94m\]'
export LIGHT_BLUE_BOLD='\[\033[1;94m\]'
export RED_BOLD='\[\033[1;31m\]'
export YELLOW_BOLD='\[\033[1;33m\]'
export COLOR_OFF='\[\033[0m\]'

function prompt_command() {
  local P=""
  P="[\$?] "
  P+="${LIGHT_GREEN}$(git_name || echo -n \$USER)"
  P+="${WHITE} ➜ "
  P+="${LIGHT_BLUE_BOLD}\w"

  if in_git_dir; then
    P+=" ${LIGHT_BLUE}("
    P+="${RED_BOLD}\$(git_branch)"
    P+="${YELLOW_BOLD}\$(git_status_marker)"
    P+="${LIGHT_BLUE})"
  fi
  P+="${COLOR_OFF} "

  P+='$ '
  export PS1="$P"
}

export PROMPT_COMMAND='prompt_command'

########
# Git autocompletion
########

if [[ -f /usr/share/bash-completion/completions/git ]]; then
  . /usr/share/bash-completion/completions/git
elif [[ -f /etc/bash_completion.d/git ]]; then
  . /etc/bash_completion.d/git
fi
