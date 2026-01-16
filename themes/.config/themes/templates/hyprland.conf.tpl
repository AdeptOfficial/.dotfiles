$borderTop = rgba({{ border_top_strip }}ee)
$borderBottom = rgba({{ border_bottom_strip }}ee)
$inactiveBorder = rgba({{ background_strip }}88)

general {
    col.active_border = $borderTop $borderBottom 180deg
    col.inactive_border = $inactiveBorder
}

group {
    col.border_active = $borderTop $borderBottom 180deg
}
