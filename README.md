# cosse
Bring your tools to your SSH session

# Install
```
git clone --depth 1 https://github.com/camphi/cosse.git ~/.cosse
ln -s ~/.cosse/cosse ~/bin/
```

# Usage
```
Usage: cosse [options] [--] [command...]

Generates a base64-encoded 'bash -c' remote payload to pass local functions,
environment variables and scripts over SSH. (Not safe for secrets)

Options:
  -s, --source <file>   Source a local file (e.g., ~/.bash_aliases) before exporting.
  -a, --alias <name>    Export a specific alias by name.
  -f, --func <name>     Export a specific local function by name.
  -v, --var <name>      Export a specific local environment variable by name.
  -x, --script <file>   Transfer a local script to remote temp dir, and add to $PATH.
  -i, --interactive     Force remote execution to spawn an interactive shell.
      --debug           Print the decoded payload string for dry-run debugging.
  -h, --help            Display this help message and exit.

Examples:
  # Start an interactive shell pre-loaded with local function and variable
  ssh -t user@host "$(cosse -f my_func -v LESS -i)"

  # Execute a local function remotely with options and arguments
  ssh -t user@host "$(cosse -s ~/.bash_aliases -f deploy_app -- deploy_app production)"

  # Use aliases for repeated operations
  alias sshenv-base="cosse --source='${HOME}/.bash_aliases' --alias={l,ll,la} --func={l-size,field,total,avg,max,min,max-line,min-line,from-iec,to-iec,showargs}"
  ssh -t user@host "$(sshenv-base -i)"
```


# Test
```
./test/bats/bin/bats test
```
