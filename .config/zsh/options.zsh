setopt autocd              # change directory just by typing its name
#setopt correct            # auto correct mistakes - uncomment if desired
setopt extendedglob        # extended globbing. Allows using regular expressions with *
setopt interactivecomments # allow comments in interactive mode
setopt magicequalsubst     # enable filename expansion for arguments of the form ΓÇÿanything=expressionΓÇÖ
setopt nonomatch           # hide error message if there is no match for the pattern
setopt notify              # report the status of background jobs immediately
setopt numericglobsort     # sort filenames numerically when it makes sense
setopt promptsubst         # enable command substitution in prompt

WORDCHARS=${WORDCHARS//\/}

PROMPT_EOL_MARK=""

export KEYTIMEOUT=1
