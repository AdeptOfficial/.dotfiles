# Overwrite parts of the syna-menu with user-specific submenus.
# See ~/.local/bin/rice/syna-menu for functions that can be overwritten.
#
# WARNING: Overwritten functions will not receive upstream updates.
#
# Example of minimal system menu:
#
# show_system_menu() {
#   case $(menu "System" "  Lock\n󰐥  Shutdown") in
#   *Lock*) syna-lock-screen ;;
#   *Shutdown*) syna-cmd-shutdown ;;
#   *) back_to show_main_menu ;;
#   esac
# }
