set scrolloff=20
set number 
set relativenumber 
set tabstop=4 softtabstop=4
set shiftwidth=4
set expandtab
set smartindent

set nobackup
set nowritebackup
set encoding=utf-8

set nocompatible

set updatetime=300
set signcolumn=yes

syntax enable
filetype off
set rtp+=~/.vim/bundle/Vundle.vim

call vundle#begin()
Plugin 'VundleVim/Vundle.vim'
Plugin 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plugin 'neovim/nvim-lspconfig'

Plugin 'nvim-lualine/lualine.nvim'
Plugin 'Luxed/ayu-vim'

" Typescript
Plugin 'pmizio/typescript-tools.nvim'

Plugin 'tpope/vim-surround'

Plugin 'github/copilot.vim'
Plugin 'nvim-lua/plenary.nvim'
Plugin 'nvim-telescope/telescope.nvim', { 'tag': '0.1.4' }
Plugin 'prettier/vim-prettier', {
  \ 'do': 'yarn install --frozen-lockfile --production',
  \ 'branch': 'release/0.x'
  \ }
Plugin 'neoclide/coc.nvim', {'branch': 'release'}
call vundle#end()           
filetype plugin indent on    

set termguicolors
let g:ayucolor="mirage"
colorscheme ayu

let mapleader = " "
nnoremap <leader>pv :Explore<CR>
nnoremap <leader><CR> :so ~/.config/nvim/init.vim<CR>
nnoremap <leader>ff <cmd>Telescope find_files<CR>
nnoremap <leader>fg <cmd>Telescope live_grep<CR>
nnoremap <leader>fb <cmd>Telescope buffers<CR>
nnoremap <leader>fh <cmd>Telescope help_tags<CR>
nnoremap <silent> <leader>rn :lua vim.lsp.buf.rename()<CR>
nnoremap b q
xnoremap b q
nnoremap q b
xnoremap q b
nnoremap B Q
xnoremap B Q
nnoremap Q B
xnoremap Q B

" nice remaps?
nnoremap <leader>y "+y
vnoremap <leader>y "+y
nnoremap <leader>uc gUU
nnoremap <leader>lc guu

" call :LazyGit
nnoremap <leader>gg :LazyGit<CR>

" copy current path
nnoremap <leader>cp :let @*=expand('%:p')<CR>

" CoC settings start
inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ CheckBackSpace() ? "\<Tab>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

" Make <CR> to accept selected completion item or notify coc.nvim to format
" <C-g>u breaks current undo, please make your own choice
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

function! CheckBackSpace() abort
    let col = col('.') - 1
    return !col || getline('.')[col - 1]  =~# '\s'
endfunction

if has('nvim')
    inoremap <silent><expr> <C-Space> coc#refresh()
else
    inoremap <silent><expr> <C-@> coc#refresh()
endif

nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" Remap keys for gotos
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use K to show documentation in preview window
nnoremap <silent> K :call ShowDocumentation()<CR>

function ShowDocumentation()
    if CocAction('hasProvider', 'hover')
        call CocAction('doHover')
    else
        call feedkeys('K', 'in')
    endif
endfunction

autocmd CursorHold * silent call CocActionAsync('highlight')

" Remap for rename current word
nmap <leader>rn <Plug>(coc-rename)

" Remap for format selected region
vmap <leader>f  <Plug>(coc-format-selected)
nmap <leader>f  <Plug>(coc-format-selected)
" CoC settings end

let g:go_auto_type_info = 1
let g:go_doc_popup_window = 1

augroup AutoPrettier
  autocmd!
  autocmd BufWritePre *.ts,*.tsx,*.js,*.jsx,*.css,*.html,*.json :Prettier
augroup END

lua << EOF
require('lualine').setup()

local actions = require('telescope.actions')
require('telescope').setup {
    defaults = {
        file_ignore_patterns = { "node_modules", "target", "dist" }
    }
}

require'nvim-treesitter.configs'.setup {
  ensure_installed = "all",     
  highlight = {
    enable = true              
  },
}

require('typescript-tools').setup {
  lsp = {
    on_attach = function(client)
      client.resolved_capabilities.document_formatting = false
    end
  }
}
EOF
