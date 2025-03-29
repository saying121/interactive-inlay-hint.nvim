local lsp = vim.lsp
local methods = lsp.protocol.Methods
local lsp_util = lsp.util

local M = {}

---@type lsp.Handler
--- @param inlay_hint lsp.InlayHint
local function lsp_handler(_, inlay_hint, ctx)
	-- vim.print(inlay_hint)
	local client = lsp.get_clients({
		bufnr = ctx.bufnr,
		client_id = ctx.client_id,
		method = methods.textDocument_inlayHint,
	})[1]

	-- TODO: also add inlay_hint.tooltip
	-- TODO: also add inlay_hint.label[].tooltip
	-- TODO: also show some stuff about what textEdits/commands/lenses are available
	if not inlay_hint then
		return
	end
	local label = inlay_hint.label
	vim.print(label)
	if type(label) == "table" then
		---@type lsp.InlayHintLabelPart[]
		local parts = vim.tbl_filter(function(part)
			return part.location ~= nil
		end, label)

		-- TODO: merge all hovers
		local part = parts[1]
		if part then
			client:request(methods.textDocument_hover, {
				textDocument = { uri = part.location.uri },
				position = part.location.range.start,
			})
		end
	end
end

---@param hint vim.lsp.inlay_hint.get.ret
M.req = function(hint)
	local client = lsp.get_clients({
		bufnr = hint.bufnr,
		client_id = hint.client_id,
		method = methods.textDocument_inlayHint,
	})[1]
	client:request(methods.inlayHint_resolve, hint.inlay_hint, lsp_handler, hint.bufnr)
end

return M
