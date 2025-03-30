local utils = require("interactive-inlay-hint.utils")
local ui = require("interactive-inlay-hint.ui")

local M = {}

--- @param range lsp.Range
M.inlay_tooltip_at_range = function(range)
    local hint_list = vim.lsp.inlay_hint.get({ bufnr = 0, range = range })

    if #hint_list < 1 then
        return
    end

    local labels = {}
    for _, value in ipairs(hint_list) do
        table.insert(labels, utils.full_label(value.inlay_hint.label))
    end

    if #hint_list == 1 then
        ui.req(hint_list[1])
        return
    end

    vim.ui.select(labels, { prompt = "Select label" }, function(_, idx)
        local hint = hint_list[idx]
        vim.print(hint)

        if not hint then
            return
        end
        ui.req(hint)
    end)
end

M.inlay_tooltip_at_cursor_word = function()
    M.inlay_tooltip_at_range(utils.select_word())
end

return M
