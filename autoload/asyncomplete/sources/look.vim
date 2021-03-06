function! asyncomplete#sources#look#get_source_options(opts)
  return a:opts
endfunction

function! asyncomplete#sources#look#completor(opt, ctx)
  let l:col = a:ctx['col']
  let l:typed = a:ctx['typed']
  let l:config = get(a:opt, 'config', {'complete_min_chars': 2})
  let l:complete_min_chars = get(l:config, 'complete_min_chars', 2)

  let l:keyword = matchstr(l:typed, '\v[a-z,A-Z]{'.l:complete_min_chars.',}$')
  let l:keyword_len = len(l:keyword)

  if l:keyword_len < l:complete_min_chars
    call asyncomplete#complete(a:opt['name'], a:ctx, l:startcol, l:matches, 1)
    return
  endif

  let l:start_col = l:col - l:keyword_len
  let l:info = { 'start_col': l:start_col, 'opt': a:opt, 'ctx': a:ctx, 'keyword': l:keyword, 'lines': [] }
  let l:cmd = ['look', l:keyword]

  let l:dict = get(g:, 'asyncomplete#sources#look#dict', '')
  if l:dict != ''
    let l:cmd = l:cmd + [l:dict]
  endif

  call async#job#start(l:cmd, {
    \   'on_stdout': function('s:handler', [l:info]),
    \   'on_exit': function('s:handler', [l:info])
    \ })
endfunction

function! s:handler(info, id, data, event) abort
  if a:event == 'exit'
    call asyncomplete#log('asyncomplete-look.vim', 'exitcode', a:data)

    let l:ctx = a:info['ctx']
    let l:start_col = a:info['start_col']

    let l:matches = []
    let l:itembase = {'dup' : 1, 'icase' : 1, 'menu' : 'look' }

    let l:config = get(a:info['opt'], 'config', {})
    let l:allow_first_capital_letter = get(l:config, 'allow_first_capital_letter', 0)

    for l:line in a:info['lines']
      let l:linesplit = split(l:line)

      if len(l:linesplit) != 0
        let l:item = copy(l:itembase)

        if l:allow_first_capital_letter > 0 && a:info['keyword'] =~# '^\u'
          let l:item['word'] = substitute(l:linesplit[0], '\w\+', '\u\0', 'c')
        else
          let l:item['word'] = l:linesplit[0]
        endif

        if len(l:linesplit) > 1
          let l:item['info'] = join(l:linesplit[1:], ' ')
        endif

        call add(l:matches, l:item)
      endif
    endfor

    call asyncomplete#complete(a:info['opt']['name'], l:ctx, l:start_col, l:matches)
  elseif a:event == 'stdout'
    let a:info['lines'] += a:data
  endif
endfunction

