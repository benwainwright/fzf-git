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

function! GetLineBlameHash()
  let l:blame_cmd = 'git blame ' . expand('%') . ' -L ' . line('.') . ',' .  line('.')
  let l:hash_cmd = l:blame_cmd . " | awk '{print $1}'"
  let l:response = system(l:hash_cmd)
  echom(l:response)
endfunction

function! OpenLinePr()
  let l:blame_cmd = 'git blame ' . expand('%') . ' -L ' . line('.') . ',' .  line('.')
  let l:hash_cmd = l:blame_cmd . " | awk '{print $1}'"
  let l:response = system(l:hash_cmd)
  if v:shell_error == 0
    let l:repo_url = system('hub browse -u | cut -d/ -f1-5 | tr -d "\n"')
    let l:pr_search_url = l:repo_url . "/pulls\\?q=" . l:response
    let l:command = 'silent !open ' . l:pr_search_url . " | :redraw!"
    execute l:command
  else
    echoerr l:response
  endif
endfunction

function s:do_branch_checkout(line)
  let l:branch = s:parse_branch_line(0, a:line)
  execute 'Git checkout ' . l:branch.name
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
  let l:branch_lines = s:get_branch_lines()

  let l:opts = {
    \ 'sink': function('s:do_branch_checkout'),
    \ 'source': l:branch_lines,
    \ 'down': '40%'
    \ }

  call fzf#run(fzf#wrap(l:opts))
endfunction

function s:do_pr_checkout(line)
  let l:parts = matchlist(a:line, '|\(\d\+\)|')
  let l:prNumber = l:parts[1]
  execute 'Git pr checkout ' . l:prNumber
endfunction

function s:fzf_hub_output(channel, message)
  let s:fzf_hub_lines = s:fzf_hub_lines + split(a:message, "\n")
endfunction

function s:fzf_hub_has_finished(job, exit)
  if len(s:fzf_hub_lines) != 0

    let l:opts = {
      \ 'sink' : function('s:do_pr_checkout'),
      \ 'source' : s:fzf_hub_lines,
      \ 'down' : '40%'
      \ }

    call fzf#run(fzf#wrap(l:opts))
  else
    echom('No prs found for repository')
  endif
endfunction

function s:fzf_checkout_pr()

  let s:fzf_hub_lines = [  ]

  if !executable('hub')
    echoerr('You need "hub" installed to checkout PRs. See https://github.com/github/hub')
    return
  endif

  let l:command = 'hub pr list --format="|%I| %t%n"'
  call job_start(l:command, { 
        \ 'out_cb' : function('s:fzf_hub_output'),
        \ 'exit_cb' : function('s:fzf_hub_has_finished')
        \ })
endfunction

command! GitCheckoutBranch call s:fzf_checkout_branch()
command! GitCheckoutPr call s:fzf_checkout_pr()
