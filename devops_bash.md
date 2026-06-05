Here are the 4 core pillars of DevOps Bash Automation:

Handling Environmental Data (Variables, Env Vars, and Defaults).

Text Processing & Parsing Logs (grep, awk, sed, jq).

Validating Pre-requisites (Checking if tools/files exist before running code).

Error Auditing & Signal Trapping (trap for cleanups on failure).


1. set -euo pipefail (The Pipeline Bodyguard)
By default, Bash is incredibly lazy and reckless. If a line in your script crashes, Bash ignores it and just moves to the next line.

set -euo pipefail is a combination of three different settings that forces your script to be strict.

-e (Exit on Error): If any command fails (returns a non-zero exit code), stop the script immediately. Don't keep running blindly.

-u (Unset Variables): If you try to use a variable that doesn't exist, crash immediately. This stops disasters like rm -rf /$MY_VAR if $MY_VAR is empty (which would turn into rm -rf / and wipe your system).

-o pipefail (Pipe Failure): If you chain commands together like cat file.txt | grep "something", and the first command fails, make sure the script catches it. (Normally, Bash only looks at the very last command in the chain).

2. >&2 (The Direct Routing to Error Logs)
Every Linux system has two separate paths for output text:

stdout (Standard Output / Channel 1): Where normal, successful information goes.

stderr (Standard Error / Channel 2): Where warning and error messages go.

By default, echo "hello" sends text to Channel 1 (stdout).

When you add >&2 at the end of an echo command, you are telling Bash:
"Take this text and reroute it out of Channel 1 over into Channel 2 (Error stream)."

Bash
echo "All good"          # Goes to Channel 1 (Normal output)
echo "ERROR: DB down" >&2 # Forced into Channel 2 (Error logs)
Why do this? In a production system, monitoring tools look only at Channel 2 to trigger alerts. If your script outputs a critical error to Channel 1, the monitoring tool might miss it entirely.

3. &> /dev/null (The Mute Button / Black Hole)
In Linux, /dev/null is a special virtual file. It is literally a digital black hole. Anything you send to it disappears forever. It cannot be read or recovered.

&> means "Take both Channel 1 (normal output) AND Channel 2 (errors)."

/dev/null means "Send it to the black hole."

When we write:

Bash
command -v docker &> /dev/null
We are asking the system, "Is docker installed?" If docker is installed, it normally prints a path like /usr/bin/docker. If it isn't, it prints an ugly error message.

Because we only care if the command succeeds or fails behind the scenes, we don't want that random text messing up our beautiful terminal logs. &> /dev/null acts as a mute button, throwing all output into the trash so the script stays completely silent.

Let's see them in a tiny example
Look at this 2-line snippet:

Bash
#!/usr/bin/env bash
set -euo pipefail

# 1. We test if 'kubectl' is installed. We mute the output entirely.
if ! command -v kubectl &> /dev/null; then
    # 2. If it failed, we route this message strictly to the error log stream.
    echo "CRITICAL ERROR: kubectl missing!" >&2
    exit 1
fi