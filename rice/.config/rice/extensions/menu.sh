# Overwrite parts of the adept-menu with user-specific submenus.
# See ~/.local/bin/rice/adept-menu for functions that can be overwritten.
#
# WARNING: Overwritten functions will not receive upstream updates.
#
# Example of minimal system menu:
#
# show_system_menu() {
#   case $(menu "System" "  Lock\n󰐥  Shutdown") in
#   *Lock*) adept-lock-screen ;;
#   *Shutdown*) adept-cmd-shutdown ;;
#   *) back_to show_main_menu ;;
#   esac
# }
