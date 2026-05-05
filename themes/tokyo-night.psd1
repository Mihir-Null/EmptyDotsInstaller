@{
    Name           = 'Tokyo Night'
    WeztermScheme  = 'Tokyo Night'
    VscodiumTheme  = 'Tokyo Night'
    FlowTheme      = 'Dark'
    FlowBackdrop   = 'Acrylic'

    # Komorebi border colors (Tokyo Night palette)
    BorderSingle   = '#7aa2f7'   # blue — focused
    BorderStack    = '#9ece6a'   # green — stacked
    BorderMonocle  = '#f7768e'   # red — monocle
    BorderUnfocused= '#3b4261'   # bg highlight
    StackbarBg     = '#1a1b26'   # bg

    CssRootBlock   = @'
:root {
    --mauve:      #bb9af7;
    --red:        #f7768e;
    --yellow:     #e0af68;
    --blue:       #7aa2f7;
    --teal:       #7dcfff;
    --lavender:   #c0caf5;
    --maroon:     #ff9e64;
    --frostdark:  rgba(26, 27, 38, 0.90);
    --white:      rgba(192, 202, 245, 0.92);
    --frostwhite: rgba(192, 202, 245, 0.92);
    --frostglass: rgba(192, 202, 245, 0.10);
    --frostgray:  rgba(86, 95, 137, 0.65);
    --darkfrost:  rgba(41, 46, 66, 0.88);
    --gray:       rgb(59, 66, 97);
    --mantle:     rgba(22, 22, 30, 0.85);
    --transparent: transparent;
    --container-padding: 0 16px;
    --container-border-radius: {{CORNER_RADIUS}};
}
'@
}
