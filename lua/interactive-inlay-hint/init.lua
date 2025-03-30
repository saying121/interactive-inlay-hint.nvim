local utils = require("interactive-inlay-hint.utils")
local ui = require("interactive-inlay-hint.ui")

local M = {}

--- @param range lsp.Range
M.inlay_tooltip_at_range = function(range)
    local hint_list = vim.lsp.inlay_hint.get({ bufnr = 0, range = range })
    ui.float_ui(hint_list)
end

M.inlay_tooltip_at_cursor_word = function()
    M.inlay_tooltip_at_range(utils.select_word())
end

return M
