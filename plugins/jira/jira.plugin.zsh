# CLI support for JIRA interaction
#
# See README.md for details



function jira() {
  emulate -L zsh
  
  local action=$(_jira_find_property ".jira-default-action" "JIRA_DEFAULT_ACTION")
  if [[ -n "$1" ]]; then
    action=$1
  elif [[ -z "$action" ]]; then
    action="new"
  fi

  local jira_url=$(_jira_find_property ".jira-url" "JIRA_URL")
  if [[ -z "$jira_url" ]]; then
    _jira_url_help
    return 1
  fi

  local jira_prefix=$(_jira_find_property ".jira-prefix" "JIRA_PREFIX")

  if [[ $action == "new" ]]; then
    echo "Opening new issue"
    open_command "${jira_url}/secure/CreateIssue!default.jspa"
  elif [[ "$action" == "assigned" || "$action" == "reported" ]]; then
    _jira_query ${@:-$action}
  elif [[ "$action" == "myissues" ]]; then
    echo "Opening my issues"
    open_command "${jira_url}/issues/?filter=-1"
  elif [[ "$action" == "dashboard" ]]; then
    echo "Opening dashboard"
    if [[ "$JIRA_RAPID_BOARD" == "true" ]]; then
      open_command "${jira_url}/secure/RapidBoard.jspa"
    else
      open_command "${jira_url}/secure/Dashboard.jspa"
    fi
  elif [[ "$action" == "dumpconfig" ]]; then
    echo "JIRA_URL=$jira_url"
    echo "JIRA_PREFIX=$jira_prefix"
    echo "JIRA_NAME=$JIRA_NAME"
    echo "JIRA_RAPID_BOARD=$JIRA_RAPID_BOARD"
    echo "JIRA_DEFAULT_ACTION=$JIRA_DEFAULT_ACTION"
  else
    # Anything that doesn't match a special action is considered an issue name
    # but `branch` is a special case that will parse the current git branch
    if [[ "$action" == "branch" ]]; then
      local issue_arg=$(git rev-parse --abbrev-ref HEAD)
      local issue="${jira_prefix}${issue_arg}"
    else
      local issue_arg=$action
      local issue="${jira_prefix}${issue_arg}"
    fi
    local url_fragment=''
    if [[ "$2" == "m" ]]; then
      url_fragment="#add-comment"
      echo "Add comment to issue #$issue"
    else
      echo "Opening issue #$issue"
    fi
    if [[ "$JIRA_RAPID_BOARD" == "true" ]]; then
      open_command "${jira_url}/issues/${issue}${url_fragment}"
    else
      open_command "${jira_url}/browse/${issue}${url_fragment}"
    fi
  fi
}

function _jira_find_property() {
  local file_name="$1"
  local fallback_env="$2"

  local current_dir="$(pwd)"

  while [[ ! -a "${current_dir}/${file_name}" ]]; do
    if [[ "$current_dir" == "/" ]]; then break; fi;
    current_dir=$(dirname "$current_dir")
  done

  if [[ -a "${current_dir}/${file_name}" ]]; then
    cat "${current_dir}/${file_name}"
  elif [[ -a "~/${file_name}" ]]; then
    cat "~/${file_name}"
  else
    echo ${(P)fallback_env}
  fi
}

function _jira_url_help() {
  cat << EOF
error: JIRA URL is not specified anywhere.

Valid options, in order of precedence:
  .jira-url file
  <parents>/.jira-url file
  \$HOME/.jira-url file
  \$JIRA_URL environment variable
EOF
}

function _jira_query() {
  emulate -L zsh
  local verb="$1"
  local jira_name lookup preposition query
  if [[ "${verb}" == "reported" ]]; then
    lookup=reporter
    preposition=by
  elif [[ "${verb}" == "assigned" ]]; then
    lookup=assignee
    preposition=to
  else
    echo "error: not a valid lookup: $verb" >&2
    return 1
  fi
  jira_name=${2:=$JIRA_NAME}
  if [[ -z $jira_name ]]; then
    echo "error: JIRA_NAME not specified" >&2
    return 1
  fi

  echo "Browsing issues ${verb} ${preposition} ${jira_name}"
  query="${lookup}+%3D+%22${jira_name}%22+AND+resolution+%3D+unresolved+ORDER+BY+priority+DESC%2C+created+ASC"
  open_command "${jira_url}/secure/IssueNavigator.jspa?reset=true&jqlQuery=${query}"
}
