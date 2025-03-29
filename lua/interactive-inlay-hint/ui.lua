local methods = vim.lsp.protocol.Methods

local M = {}

---@param hint vim.lsp.inlay_hint.get.ret
M.req = function(hint)
	local client = vim.lsp.get_clients({
		bufnr = hint.bufnr,
		client_id = hint.client_id,
		method = methods.textDocument_inlayHint,
	})[1]
	client:request(
		methods.inlayHint_resolve,
		hint.inlay_hint,
		--- @param inlay_hint lsp.InlayHint
		function(_, inlay_hint)
			-- TODO: also add inlay_hint.tooltip
			-- TODO: also add inlay_hint.label[].tooltip
			-- TODO: also show some stuff about what textEdits/commands/lenses are available
			if not inlay_hint then
				return
			end
			local label = inlay_hint.label
			if type(label) == "table" then
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
		end,
		hint.bufnr
	)
end

return M
