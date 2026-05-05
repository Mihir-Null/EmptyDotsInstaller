@{
    Name           = 'Catppuccin Mocha'
    WeztermScheme  = 'Catppuccin Mocha'
    VscodiumTheme  = 'Catppuccin Mocha'
    FlowTheme      = 'Dark'
    FlowBackdrop   = 'Acrylic'

    # Komorebi border colors
    BorderSingle   = '#cba6f7'   # mauve  — focused window
    BorderStack    = '#a6e3a1'   # green  — stacked
    BorderMonocle  = '#f38ba8'   # red    — monocle
    BorderUnfocused= '#585b70'   # surface2
    StackbarBg     = '#1e1e2e'   # base

    # CSS :root block — {{CORNER_RADIUS}} is injected by Apply-Theme before writing
    CssRootBlock   = @'
:root {
    --mauve:      #cba6f7;
    --red:        #f38ba8;
    --yellow:     #f9e2af;
    --blue:       #89b4fa;
    --teal:       #94e2d5;
    --lavender:   #b4befe;
    --maroon:     #eba0ac;
    --frostdark:  rgba(30, 30, 46, 0.88);
    --white:      rgba(205, 214, 244, 0.92);
    --frostwhite: rgba(205, 214, 244, 0.92);
    --frostglass: rgba(205, 214, 244, 0.12);
    --frostgray:  rgba(108, 112, 134, 0.65);
    --darkfrost:  rgba(49, 50, 68, 0.85);
    --gray:       rgb(69, 71, 90);
    --mantle:     rgba(24, 24, 37, 0.82);
    --transparent: transparent;
    --container-padding: 0 16px;
    --container-border-radius: {{CORNER_RADIUS}};
}
'@
}
