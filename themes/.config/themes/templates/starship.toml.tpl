[username]
style_user = "bold {{ prompt_user }}"
style_root = "bold {{ prompt_error }}"
format = "[$user]($style)"
disabled = false
show_always = true

[hostname]
ssh_only = false
format = "[@](bold {{ prompt_at }})[$hostname]($style) "
style = "bold {{ prompt_host }}"
disabled = false

[directory]
format = ": [$path]($style) "
style = "bold {{ prompt_directory }}"
truncation_length = 0
truncate_to_repo = false

[character]
success_symbol = "[❯](bold {{ prompt_success }})"
error_symbol = "[❯](bold {{ prompt_error }})"

# Disable everything else for minimal prompt
[git_branch]
disabled = true
[git_status]
disabled = true
[package]
disabled = true
[nodejs]
disabled = true
[python]
disabled = true
[rust]
disabled = true
