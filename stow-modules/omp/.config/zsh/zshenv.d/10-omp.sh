# Keep omp (oh-my-pi) out of $HOME: PI_CONFIG_DIR is the dirname of omp's
# config root under $HOME, so ".config/omp" resolves to ~/.config/omp/agent
# instead of the default ~/.omp/agent.
#
# Runtime state is split away from that config root: DBs/sessions resolve to
# $XDG_DATA_HOME/omp, logs/run/terminal-sessions to $XDG_STATE_HOME/omp, caches
# to $XDG_CACHE_HOME/omp - but only while those omp dirs already exist, which
# bootstrap-omp creates. Without them omp keeps DBs, sessions, logs, and caches
# next to config.yml. XDG_*_HOME themselves come from 00-base.sh.
#
# PI_CONFIG_DIR is an omp-only variable: pi (0.87.0) never reads it. Pi's config
# dir name comes from its package.json piConfig.configDir (".pi"), so pi keeps
# using ~/.pi/agent for both config and runtime data - the entries it needs in
# .gitignore stay there. Verified: `PI_CONFIG_DIR=... node -e "import('pi/dist/config.js')"`
# still reports CONFIG_DIR_NAME=.pi, getAgentDir()=~/.pi/agent.
#
# Do NOT export PI_CODING_AGENT_DIR: both tools read that name (pi as its agent
# dir override, omp as a default-profile-only override that also disables the
# XDG split above), so setting it would relocate both tools into one directory.
export PI_CONFIG_DIR=".config/omp"
