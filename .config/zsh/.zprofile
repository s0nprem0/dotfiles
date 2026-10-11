# No session startup here, on purpose.
#
# A .zprofile that execs a compositor makes the shell unusable: it is sourced
# for interactive shells and login shells, so it fires wherever you type.
# Start a graphical session explicitly from a TTY instead.
#
#     scripts/session.sh          # report which session you are in
#
# See README.md for the WSL notes.