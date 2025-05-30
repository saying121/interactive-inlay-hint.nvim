local M = {}

---@param row1 integer
---@param col1 integer
---@param row2 integer
---@param col2 integer
---@return lsp.Range
M.make_lsp_position = function(row1, col1, row2, col2)
    return {
        ["start"] = {
            line = row1 - 1,
            character = col1,
        },
        ["end"] = {
            line = row2 - 1,
            character = col2,
        },
    }
end

--- @return lsp.Range
M.select_word = function()
    local p1 = vim.fn.getpos("v")

    local row1 = p1[2]
    local col1 = p1[3]
    local p2 = vim.api.nvim_win_get_cursor(0)
    local row2 = p2[1]
    local col2 = p2[2]

    if row1 < row2 then
        return M.make_lsp_position(row1, col1, row2, col2)
    elseif row2 < row1 then
        return M.make_lsp_position(row2, col2, row1, col1)
    end

    return M.make_lsp_position(row1, math.min(col1, col2), row1, math.max(col1, col2))
end

---@param label string|lsp.InlayHintLabelPart[]
---@return string
M.full_label = function(label)
    if type(label) == "string" then
        return label
    end
    local res = ""
    for _, value in ipairs(label) do
        res = res .. value.value
    end
    return res
end

---@param text string[]
---@return integer
M.max_width = function(text)
    local width = 0
    for _, value in ipairs(text) do
        if #value > width then
            width = #value
        end
    end
    return width
end

---@param winnr integer
---@param bufnr integer
---@param ft nil|string
M.set_win_buf_opt = function(winnr, bufnr, ft)
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].number = false
    vim.wo[winnr].rnu = false
    vim.wo[winnr].sidescrolloff = 0
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].ft = ft or "markdown"
end

---@param width integer
---@param height integer
M.min_width_height = function(win_opts, width, height)
    win_opts.width = math.min(win_opts.width, width)
    win_opts.height = math.min(win_opts.height, height)
end

return M
