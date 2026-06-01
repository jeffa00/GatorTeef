local group = vim.api.nvim_create_augroup("dev-environment-dotnet", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "cs",
  callback = function(args)
    local opts = { buffer = args.buf }

    vim.keymap.set("n", "<leader>dc", function()
      require("dap").continue()
    end, vim.tbl_extend("force", opts, { desc = "Debug continue" }))
    vim.keymap.set("n", "<leader>db", function()
      require("dap").toggle_breakpoint()
    end, vim.tbl_extend("force", opts, { desc = "Debug breakpoint" }))
    vim.keymap.set("n", "<leader>di", function()
      require("dap").step_into()
    end, vim.tbl_extend("force", opts, { desc = "Debug step into" }))
    vim.keymap.set("n", "<leader>do", function()
      require("dap").step_over()
    end, vim.tbl_extend("force", opts, { desc = "Debug step over" }))
    vim.keymap.set("n", "<leader>dO", function()
      require("dap").step_out()
    end, vim.tbl_extend("force", opts, { desc = "Debug step out" }))
    vim.keymap.set("n", "<leader>dr", function()
      require("dap").repl.open()
    end, vim.tbl_extend("force", opts, { desc = "Debug REPL" }))
    vim.keymap.set("n", "<leader>dq", function()
      require("dap").terminate()
    end, vim.tbl_extend("force", opts, { desc = "Debug terminate" }))
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client or client.name ~= "roslyn_ls" then
      return
    end

    local opts = { buffer = args.buf }

    vim.keymap.set("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Go to definition" }))
    vim.keymap.set("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "List references" }))
    vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover" }))
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Rename symbol" }))
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "Code action" }))
  end,
})

return {
  {
    "williamboman/mason.nvim",
    lazy = false,
    opts = {
      registries = {
        "github:mason-org/mason-registry",
        "github:Crashdummyy/mason-registry",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
    },
    ft = "cs",
    config = function()
      if vim.fn.executable("roslyn") ~= 1 then
        vim.schedule(function()
          vim.notify("Roslyn language server is not installed yet. Run :MasonInstall roslyn, then restart Neovim.", vim.log.levels.WARN)
        end)
        return
      end

      local uv = vim.uv or vim.loop

      vim.lsp.config("roslyn_ls", {
        cmd = {
          "roslyn",
          "--logLevel",
          "Information",
          "--extensionLogDirectory",
          vim.fs.joinpath(uv.os_tmpdir(), "roslyn_ls", "logs"),
          "--stdio",
        },
        root_dir = function(bufnr, on_dir)
          local fname = vim.api.nvim_buf_get_name(bufnr)

          local sln = vim.fs.find(function(name)
            return name:match("%.sln$")
          end, { upward = true, path = fname, type = "file" })[1]
          if sln then
            on_dir(vim.fs.dirname(sln))
            return
          end

          local csproj = vim.fs.find(function(name)
            return name:match("%.csproj$")
          end, { upward = true, path = fname, type = "file" })[1]
          if csproj then
            on_dir(vim.fs.dirname(csproj))
          end
        end,
        settings = {
          ["csharp|background_analysis"] = {
            dotnet_analyzer_diagnostics_scope = "openFiles",
            dotnet_compiler_diagnostics_scope = "openFiles",
          },
          ["csharp|code_lens"] = {
            dotnet_enable_references_code_lens = true,
          },
          ["csharp|completion"] = {
            dotnet_show_completion_items_from_unimported_namespaces = true,
          },
        },
      })

      vim.lsp.enable("roslyn_ls")
    end,
  },
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "williamboman/mason.nvim",
    },
    ft = "cs",
    config = function()
      local dap = require("dap")

      if vim.fn.executable("netcoredbg") ~= 1 then
        vim.schedule(function()
          vim.notify("netcoredbg is not installed yet. Run :MasonInstall netcoredbg before starting a .NET debug session.", vim.log.levels.WARN)
        end)
        return
      end

      dap.adapters.netcoredbg = {
        type = "executable",
        command = vim.fn.exepath("netcoredbg"),
        args = { "--interpreter=vscode" },
        options = {
          detached = false,
        },
      }

      dap.configurations.cs = {
        {
          type = "netcoredbg",
          name = "Launch .NET DLL",
          request = "launch",
          cwd = "${workspaceFolder}",
          program = function()
            return vim.fn.input("Path to DLL: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
          end,
        },
        {
          type = "netcoredbg",
          name = "Attach to process",
          request = "attach",
          processId = require("dap.utils").pick_process,
        },
      }
    end,
  },
}
