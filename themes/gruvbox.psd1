@{
    Name           = 'Gruvbox Dark'
    WeztermScheme  = 'GruvboxDark'
    VscodiumTheme  = 'Gruvbox Dark Hard'
    FlowTheme      = 'Dark'
    FlowBackdrop   = 'Acrylic'

    # Komorebi border colors (Gruvbox Dark palette)
    BorderSingle   = '#83a598'   # aqua — focused
    BorderStack    = '#b8bb26'   # yellow-green — stacked
    BorderMonocle  = '#fb4934'   # red bright — monocle
    BorderUnfocused= '#504945'   # bg3
    StackbarBg     = '#1d2021'   # bg hard

    CssRootBlock   = @'
:root {
    --mauve:      #d3869b;
    --red:        #fb4934;
    --yellow:     #fabd2f;
    --blue:       #83a598;
    --teal:       #8ec07c;
    --lavender:   #b8bb26;
    --maroon:     #cc241d;
    --frostdark:  rgba(29, 32, 33, 0.90);
    --white:      rgba(235, 219, 178, 0.92);
    --frostwhite: rgba(235, 219, 178, 0.92);
    --frostglass: rgba(235, 219, 178, 0.10);
    --frostgray:  rgba(102, 92, 84, 0.70);
    --darkfrost:  rgba(50, 48, 47, 0.88);
    --gray:       rgb(80, 73, 69);
    --mantle:     rgba(29, 32, 33, 0.85);
    --transparent: transparent;
    --container-padding: 0 16px;
    --container-border-radius: {{CORNER_RADIUS}};
}
'@
}
