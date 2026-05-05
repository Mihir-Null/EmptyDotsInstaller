@{
    Name           = 'Nord'
    WeztermScheme  = 'Nord'
    VscodiumTheme  = 'Nord'
    FlowTheme      = 'Dark'
    FlowBackdrop   = 'Acrylic'

    # Komorebi border colors (Nord palette)
    BorderSingle   = '#88c0d0'   # frost3 — focused
    BorderStack    = '#a3be8c'   # aurora green — stacked
    BorderMonocle  = '#bf616a'   # aurora red — monocle
    BorderUnfocused= '#4c566a'   # polar night4
    StackbarBg     = '#2e3440'   # polar night1

    CssRootBlock   = @'
:root {
    --mauve:      #b48ead;
    --red:        #bf616a;
    --yellow:     #ebcb8b;
    --blue:       #81a1c1;
    --teal:       #88c0d0;
    --lavender:   #5e81ac;
    --maroon:     #bf616a;
    --frostdark:  rgba(46, 52, 64, 0.88);
    --white:      rgba(236, 239, 244, 0.92);
    --frostwhite: rgba(236, 239, 244, 0.92);
    --frostglass: rgba(216, 222, 233, 0.10);
    --frostgray:  rgba(76, 86, 106, 0.65);
    --darkfrost:  rgba(59, 66, 82, 0.85);
    --gray:       rgb(67, 76, 94);
    --mantle:     rgba(36, 41, 51, 0.82);
    --transparent: transparent;
    --container-padding: 0 16px;
    --container-border-radius: {{CORNER_RADIUS}};
}
'@
}
