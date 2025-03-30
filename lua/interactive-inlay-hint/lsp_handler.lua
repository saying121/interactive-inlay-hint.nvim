local util = vim.lsp.util
local api = vim.api
local vfn = vim.fn
local log = vim.lsp.log

local M = {}

---@type lsp.Handler
M.goto_definition = function(_, result, ctx)
    if result == nil or vim.tbl_isempty(result) then
        local _ = log.info() and log.info(ctx.method, "No location found")
        return nil
    end

    if vim.islist(result) then
        util.show_document(result[1], "utf-8", { focus = true })

        if #result > 1 then
            vfn.setqflist(util.locations_to_items(result))
        end
    else
        util.show_document(result, "utf-8", { focus = true })
    end
end
---@type lsp.Handler
M.hover = function(_, result, ctx)
end

return M
