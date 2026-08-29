require('catppuccin').setup({
    flavour = 'mocha',

    transparent_background = true,

    float = {
        transparent = true,
        solid = false,
    },

    auto_integrations = true,
})

vim.cmd.colorscheme('catppuccin')