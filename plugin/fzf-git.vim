function s:get_remotes()
  return ['origin']
endfunction

function s:parse_branch_line(key, line)
  let l:parts = matchlist(a:line, '\(\S\+\)\s\+\(\S\+\)\s\+\(.\+\)')
  let l:branch = {
        \ "line" : l:parts[0],
        \ "name" : l:parts[1],
        \ "fullname" : l:parts[1]
        \ }
  for remote in s:get_remotes()
    let l:prefix = 'remotes/' . remote . '/'
    if l:branch['name'] =~ '^' . l:prefix
      let l:branch['remote'] = remote
      let l:branch['name'] = l:branch['name'][len(l:prefix):]
      break
    endif
  endfor
  return l:branch
endfunction

function s:do_checkout(line)
  let l:branch = s:parse_branch_line(0, a:line)
  let l:command = 'git checkout ' . l:branch.name
  call job_start(l:command, { 'out_cb' : 'Job_out_handler', 'err_cb' : 'Job_err_handler' })
endfunction

function Job_out_handler(channel, message)
  echom(a:message)
endfunction

function Job_err_handler(channel, message)
  echoerr(a:message)
endfunction

function s:get_branch_lines()
  let l:lines = systemlist('git branch -av')
  let l:lines = filter(l:lines, 'v:val[0] !=# "*"') 
  let l:branches = map(l:lines, function('s:parse_branch_line'))
  let l:unique_branches = {  }
  for branch in l:branches
    if !has_key(l:unique_branches, branch.name) || has_key(unique_branches[branch.name], 'remote')
      let l:unique_branches[branch.name] = branch
    endif
  endfor
  let l:output_lines = [  ]
  for name in keys(l:unique_branches)
    call add(l:output_lines, l:unique_branches[name].line)
  endfor
  return l:output_lines
endfunction

function s:fzf_checkout_branch()
  let s:branch_lines = s:get_branch_lines()
  call fzf#run({
        \ 'sink': function('s:do_checkout'),
        \ 'source': s:branch_lines,
        \ 'down': '40%'
        \ })
endfunction

command! FzfGitCheckout call s:fzf_checkout_branch()
