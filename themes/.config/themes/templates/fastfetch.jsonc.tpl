{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "auto",
    "source": "~/.config/fastfetch/assets/logo.txt",
    "width": 5,
    "padding": {
      "top": 2,
      "right": 3,
      "left": 1
    }
  },  
  "modules": [
    "break",
    {
      "type": "custom",
      "format": "\u001b[90m┌──────────────────────Hardware──────────────────────┐"
    },
    {
      "type": "host",
      "key": " PC",
      "keyColor": "{{ color6 }}"
    },
    {
      "type": "cpu",
      "key": "│ ├",
      "showPeCoreCount": true,
      "keyColor": "{{ color6 }}"
    },
    {
      "type": "gpu",
      "key": "│ ├",
      "detectionMethod": "pci",
      "keyColor": "{{ color6 }}"
    },
    {
      "type": "display",
      "key": "│ ├󱄄",
      "keyColor": "{{ color6 }}"
    },
    {
      "type": "disk",
      "key": "│ ├󰋊",
      "keyColor": "{{ color6 }}",
      "folders": ["/", "/mnt/SharedData", "/mnt/SynaDrive"],
      "format": "{name} | {size-used}/{size-total} ({size-percentage})"
    },
    {
      "type": "memory",
      "key": "└ └",
      "keyColor": "{{ color6 }}"
    },
    //{
      //"type": "swap",
      //"key": "└ └󰓡 ",
      //"keyColor": "{{ accent }}"
    //},
    {
      "type": "custom",
      "format": "\u001b[90m└────────────────────────────────────────────────────┘"
    },
    "break",
    {
      "type": "custom",
      "format": "\u001b[90m┌──────────────────────Software──────────────────────┐"
    },
    {
      "type": "command",
      "key": "\ue900 OS",
      "keyColor": "{{ accent }}",
      "text": "version=$(syna-version); echo \"SynaOS\""
    },
    {
      "type": "kernel",
      "key": "│ ├",
      "keyColor": "{{ accent }}"
    },
    {
      "type": "wm",
      "key": "│ ├",
      "keyColor": "{{ accent }}"
    },
    {
      "type": "de",
      "key": " DE",
      "keyColor": "{{ accent }}"
    },
    {
      "type": "terminal",
      "key": "│ ├",
      "keyColor": "{{ accent }}"
    },
    {
      "type": "packages",
      "key": "│ ├󰏖",
      "keyColor": "{{ accent }}"
    },
    {
      "type": "wmtheme",
      "key": "│ ├󰉼",
      "keyColor": "{{ accent }}"
    },
    {
      "type": "command",
      "key": "│ ├󰸌",
      "keyColor": "{{ accent }}",
      "text": "theme=$(~/.local/bin/rice/syna-theme-current); echo -e \"$theme \\e[38m●\\e[37m●\\e[36m●\\e[35m●\\e[34m●\\e[33m●\\e[32m●\\e[31m●\""
    },
    {
      "type": "terminalfont",
      "key": "└ └",
      "keyColor": "{{ accent }}"
    },
    {
      "type": "custom",
      "format": "\u001b[90m└────────────────────────────────────────────────────┘"
    },
    "break",
    {
      "type": "custom",
      "format": "\u001b[90m┌────────────────Age / Uptime / Update───────────────┐"
    },
    {
      "type": "command",
      "key": "󱦟 OS Age",
      "keyColor": "{{ color5 }}",
      "text": "birth_install=$(stat -c %W /); current=$(date +%s); time_progression=$((current - birth_install)); days_difference=$((time_progression / 86400)); echo $days_difference days"
    },
    {
      "type": "uptime",
      "key": "󱫐 Uptime",
      "keyColor": "{{ color5 }}"
    },
    {
      "type": "command",
      "key": " Update",
      "keyColor": "{{ color5 }}",
      "text": "updated=$(syna-version-pkgs); echo \"$updated\""
    },
    {
      "type": "custom",
      "format": "\u001b[90m└────────────────────────────────────────────────────┘"
    },
    "break"
  ]
}
