" Language:     Colored CSS Color Preview
" Author:       Max Vasiliev <vim@skammer.name>
" Last Change:  2010 Jul 3
" Licence:      No Warranties. WTFPL. But please tell me!
" Version:      0.7.1
" vim:et:ts=2 sw=2 sts=2

let s:hex={}
for i in range(0, 255)
  let s:hex[ printf( '%02x', i ) ] = i
endfor

" xterm color table
" 16 vt100 colors preset
let s:colortable=[
\  [ 0x00, 0x00, 0x00 ],
\  [ 0xCD, 0x00, 0x00 ],
\  [ 0x00, 0xCD, 0x00 ],
\  [ 0xCD, 0xCD, 0x00 ],
\  [ 0x00, 0x00, 0xEE ],
\  [ 0xCD, 0x00, 0xCD ],
\  [ 0x00, 0xCD, 0xCD ],
\  [ 0xE5, 0xE5, 0xE5 ],
\  [ 0x7F, 0x7F, 0x7F ],
\  [ 0xFF, 0x00, 0x00 ],
\  [ 0x00, 0xFF, 0x00 ],
\  [ 0xFF, 0xFF, 0x00 ],
\  [ 0x5C, 0x5C, 0xFF ],
\  [ 0xFF, 0x00, 0xFF ],
\  [ 0x00, 0xFF, 0xFF ],
\  [ 0xFF, 0xFF, 0xFF ]]

for c in range(0, 15)
  let s:colortable[c] += [c]
endfor

" grayscale ramp
for c in range(0, 23)
  let value = 8 + c * 0x0A
  let s:colortable += [[value, value, value, 232 + c]]
endfor

" the 6 values used in the xterm color cube
let s:valuerange = [ 0x00, 0x5F, 0x87, 0xAF, 0xD7, 0xFF ]

let i = 0
let s:vquant = []
for c in range(0, 255)
  let value = s:valuerange[i]
  if c == value | let s:vquant += [i] | continue | endif
  let nextvalue = s:valuerange[i+1]
  let s:vquant += [ c - value < nextvalue - c ? i : i+1 ]
  if c >= nextvalue | let i += 1 | endif
endfor

function! s:distance(c1,c2)
  let [r1,g1,b1] = a:c1[0:2]
  let [r2,g2,b2] = a:c2[0:2]
  let dr = r2 - r1
  let dg = g2 - g1
  let db = b2 - b1
  return dr*dr + dg*dg + db*db
endfunction

" selects the nearest xterm color for a rgb value like #FF0000
function! s:Rgb2xterm(color)
  let best_match=0
  let smallest_distance = 10000000000
  let color = tolower(a:color)
  let r = s:hex[color[1:2]]
  let g = s:hex[color[3:4]]
  let b = s:hex[color[5:6]]
  unlet color
  let color = [r,g,b]

  let vr  = s:vquant[r]
  let vg  = s:vquant[g]
  let vb  = s:vquant[b]
  let cidx = vr * 36 + vg * 6 + vb + 16
  let ccol = [s:valuerange[vr],s:valuerange[vg],s:valuerange[vg],cidx]

  for c in [ ccol ] + s:colortable
    let d = s:distance( color, c )
    if d == 0 | return c[3] | endif
    if d < smallest_distance
      let smallest_distance = d
      let best_match = c[3]
    endif
  endfor
  return best_match
endfunction

function! s:FGforBG(bg)
  " takes a 6hex color code and returns a matching color that is visible
  let rgb = matchlist(tolower(a:bg),'^#\(\x\x\)\(\x\x\)\(\x\x\)$')
  if len( rgb ) == 0 | return '#cccccc' | endif
  let [r,g,b] = rgb[1:3]
  return s:hex[r]*30 + s:hex[g]*59 + s:hex[b]*11 > 12000 ? '#000000' : '#ffffff'
endfunction

function! s:SetMatcher(clr,pat)
  let group = 'cssColor'.tolower(matchstr(a:clr,'^#\zs.*'))
  redir => s:currentmatch
  silent! exe 'syn list' group
  redir END
  if s:currentmatch !~ a:pat.'\/'
    exe 'syn match' group '/'.a:pat.'/ contained'
    exe 'syn cluster cssColors add='.group
    if has('gui_running')
      exe 'hi' group 'guifg='.s:FGforBG(a:clr)
      exe 'hi' group 'guibg='.a:clr
    elseif &t_Co == 256
      exe 'hi' group 'ctermfg='.s:Rgb2xterm(s:FGforBG(a:clr))
      exe 'hi' group 'ctermbg='.s:Rgb2xterm(a:clr)
    endif
    return 1
  else
    return 0
  endif
endfunction

function! s:SetNamedColor(clr,name)
  let group = 'cssColor'.tolower(matchstr(a:clr,'^#\zs.*'))
  exe 'syn keyword' group a:name 'contained'
  exe 'syn cluster cssColors add='.group
  if has('gui_running')
    exe 'hi' group 'guifg='.s:FGforBG(a:clr)
    exe 'hi' group 'guibg='.a:clr
  elseif &t_Co == 256
    exe 'hi' group 'ctermfg='.s:Rgb2xterm(s:FGforBG(a:clr))
    exe 'hi' group 'ctermbg='.s:Rgb2xterm(a:clr)
  endif
endfunction

" Convert 80% -> 204, 100% -> 255, etc.
function! s:cssvalue(value)
  let percentage = matchstr( a:value, '\(.*\)\ze%$' )
  return len( percentage ) ? ( 255 * percentage ) / 100 : a:value
endf

function! s:PreviewCSSColorInLine()
  " TODO use cssColor matchdata
  let n = 0
  while 1
    let rgb = matchlist( getline('.'), '#\(\x\)\(\x\)\(\x\)\>', 0, n )
    if len( rgb ) == 0 | break | endif
    let [r,g,b] = rgb[1:3]
    call s:SetMatcher( '#'.r.r.g.g.b.b, rgb[0] )
    let n+=1
  endwhile
  unlet rgb

  let n = 0
  while 1
    let rgb = matchstr( getline('.'), '#\x\{6}\>', 0, n )
    if len( rgb ) == 0 | break | endif
    call s:SetMatcher( rgb, rgb )
    let n+=1
  endwhile
  unlet rgb

  let n = 0
  while 1
    let rgb = matchlist( getline('.'), 'rgba\?(\(\d\{1,3}%\?\)\s*,\s*\(\d\{1,3}%\?\)\s*,\s*\(\d\{1,3}%\?\)\s*\%(,[^)]*\)\?)', 0, n )
    if len( rgb ) == 0 | break | endif
    let [r,g,b] = rgb[1:3]
    let color = printf( '#%02x%02x%02x', s:cssvalue(r), s:cssvalue(g), s:cssvalue(b) )
    call s:SetMatcher( color, rgb[0] )
    let n+=1
  endwhile
endfunction

if has("gui_running") || &t_Co==256
  " HACK modify cssDefinition to add @cssColors to its contains
  redir => s:olddef
  silent!  syn list cssDefinition
  redir END
  if s:olddef != ''
    let s:b = strridx(s:olddef,'matchgroup')
    if s:b != -1
      exe 'syn region cssDefinition' strpart(s:olddef,s:b).',@cssColors'
    endif
  endif

  " w3c Colors
  call s:SetNamedColor('#800000', 'maroon')
  call s:SetNamedColor('#ff0000', 'red')
  call s:SetNamedColor('#ffA500', 'orange')
  call s:SetNamedColor('#ffff00', 'yellow')
  call s:SetNamedColor('#808000', 'olive')
  call s:SetNamedColor('#800080', 'purple')
  call s:SetNamedColor('#ff00ff', 'fuchsia')
  call s:SetNamedColor('#ffffff', 'white')
  call s:SetNamedColor('#00ff00', 'lime')
  call s:SetNamedColor('#008000', 'green')
  call s:SetNamedColor('#000080', 'navy')
  call s:SetNamedColor('#0000ff', 'blue')
  call s:SetNamedColor('#00ffff', 'aqua')
  call s:SetNamedColor('#008080', 'teal')
  call s:SetNamedColor('#000000', 'black')
  call s:SetNamedColor('#c0c0c0', 'silver')
  call s:SetNamedColor('#808080', 'gray')

  " extra colors
  call s:SetNamedColor('#F0F8FF','AliceBlue')
  call s:SetNamedColor('#FAEBD7','AntiqueWhite')
  call s:SetNamedColor('#7FFFD4','Aquamarine')
  call s:SetNamedColor('#F0FFFF','Azure')
  call s:SetNamedColor('#F5F5DC','Beige')
  call s:SetNamedColor('#FFE4C4','Bisque')
  call s:SetNamedColor('#FFEBCD','BlanchedAlmond')
  call s:SetNamedColor('#8A2BE2','BlueViolet')
  call s:SetNamedColor('#A52A2A','Brown')
  call s:SetNamedColor('#DEB887','BurlyWood')
  call s:SetNamedColor('#5F9EA0','CadetBlue')
  call s:SetNamedColor('#7FFF00','Chartreuse')
  call s:SetNamedColor('#D2691E','Chocolate')
  call s:SetNamedColor('#FF7F50','Coral')
  call s:SetNamedColor('#6495ED','CornflowerBlue')
  call s:SetNamedColor('#FFF8DC','Cornsilk')
  call s:SetNamedColor('#DC143C','Crimson')
  call s:SetNamedColor('#00FFFF','Cyan')
  call s:SetNamedColor('#00008B','DarkBlue')
  call s:SetNamedColor('#008B8B','DarkCyan')
  call s:SetNamedColor('#B8860B','DarkGoldenRod')
  call s:SetNamedColor('#A9A9A9','DarkGray')
  call s:SetNamedColor('#A9A9A9','DarkGrey')
  call s:SetNamedColor('#006400','DarkGreen')
  call s:SetNamedColor('#BDB76B','DarkKhaki')
  call s:SetNamedColor('#8B008B','DarkMagenta')
  call s:SetNamedColor('#556B2F','DarkOliveGreen')
  call s:SetNamedColor('#FF8C00','Darkorange')
  call s:SetNamedColor('#9932CC','DarkOrchid')
  call s:SetNamedColor('#8B0000','DarkRed')
  call s:SetNamedColor('#E9967A','DarkSalmon')
  call s:SetNamedColor('#8FBC8F','DarkSeaGreen')
  call s:SetNamedColor('#483D8B','DarkSlateBlue')
  call s:SetNamedColor('#2F4F4F','DarkSlateGray')
  call s:SetNamedColor('#2F4F4F','DarkSlateGrey')
  call s:SetNamedColor('#00CED1','DarkTurquoise')
  call s:SetNamedColor('#9400D3','DarkViolet')
  call s:SetNamedColor('#FF1493','DeepPink')
  call s:SetNamedColor('#00BFFF','DeepSkyBlue')
  call s:SetNamedColor('#696969','DimGray')
  call s:SetNamedColor('#696969','DimGrey')
  call s:SetNamedColor('#1E90FF','DodgerBlue')
  call s:SetNamedColor('#B22222','FireBrick')
  call s:SetNamedColor('#FFFAF0','FloralWhite')
  call s:SetNamedColor('#228B22','ForestGreen')
  call s:SetNamedColor('#DCDCDC','Gainsboro')
  call s:SetNamedColor('#F8F8FF','GhostWhite')
  call s:SetNamedColor('#FFD700','Gold')
  call s:SetNamedColor('#DAA520','GoldenRod')
  call s:SetNamedColor('#808080','Grey')
  call s:SetNamedColor('#ADFF2F','GreenYellow')
  call s:SetNamedColor('#F0FFF0','HoneyDew')
  call s:SetNamedColor('#FF69B4','HotPink')
  call s:SetNamedColor('#CD5C5C','IndianRed')
  call s:SetNamedColor('#4B0082','Indigo')
  call s:SetNamedColor('#FFFFF0','Ivory')
  call s:SetNamedColor('#F0E68C','Khaki')
  call s:SetNamedColor('#E6E6FA','Lavender')
  call s:SetNamedColor('#FFF0F5','LavenderBlush')
  call s:SetNamedColor('#7CFC00','LawnGreen')
  call s:SetNamedColor('#FFFACD','LemonChiffon')
  call s:SetNamedColor('#ADD8E6','LightBlue')
  call s:SetNamedColor('#F08080','LightCoral')
  call s:SetNamedColor('#E0FFFF','LightCyan')
  call s:SetNamedColor('#FAFAD2','LightGoldenRodYellow')
  call s:SetNamedColor('#D3D3D3','LightGray')
  call s:SetNamedColor('#D3D3D3','LightGrey')
  call s:SetNamedColor('#90EE90','LightGreen')
  call s:SetNamedColor('#FFB6C1','LightPink')
  call s:SetNamedColor('#FFA07A','LightSalmon')
  call s:SetNamedColor('#20B2AA','LightSeaGreen')
  call s:SetNamedColor('#87CEFA','LightSkyBlue')
  call s:SetNamedColor('#778899','LightSlateGray')
  call s:SetNamedColor('#778899','LightSlateGrey')
  call s:SetNamedColor('#B0C4DE','LightSteelBlue')
  call s:SetNamedColor('#FFFFE0','LightYellow')
  call s:SetNamedColor('#32CD32','LimeGreen')
  call s:SetNamedColor('#FAF0E6','Linen')
  call s:SetNamedColor('#FF00FF','Magenta')
  call s:SetNamedColor('#66CDAA','MediumAquaMarine')
  call s:SetNamedColor('#0000CD','MediumBlue')
  call s:SetNamedColor('#BA55D3','MediumOrchid')
  call s:SetNamedColor('#9370D8','MediumPurple')
  call s:SetNamedColor('#3CB371','MediumSeaGreen')
  call s:SetNamedColor('#7B68EE','MediumSlateBlue')
  call s:SetNamedColor('#00FA9A','MediumSpringGreen')
  call s:SetNamedColor('#48D1CC','MediumTurquoise')
  call s:SetNamedColor('#C71585','MediumVioletRed')
  call s:SetNamedColor('#191970','MidnightBlue')
  call s:SetNamedColor('#F5FFFA','MintCream')
  call s:SetNamedColor('#FFE4E1','MistyRose')
  call s:SetNamedColor('#FFE4B5','Moccasin')
  call s:SetNamedColor('#FFDEAD','NavajoWhite')
  call s:SetNamedColor('#FDF5E6','OldLace')
  call s:SetNamedColor('#6B8E23','OliveDrab')
  call s:SetNamedColor('#FF4500','OrangeRed')
  call s:SetNamedColor('#DA70D6','Orchid')
  call s:SetNamedColor('#EEE8AA','PaleGoldenRod')
  call s:SetNamedColor('#98FB98','PaleGreen')
  call s:SetNamedColor('#AFEEEE','PaleTurquoise')
  call s:SetNamedColor('#D87093','PaleVioletRed')
  call s:SetNamedColor('#FFEFD5','PapayaWhip')
  call s:SetNamedColor('#FFDAB9','PeachPuff')
  call s:SetNamedColor('#CD853F','Peru')
  call s:SetNamedColor('#FFC0CB','Pink')
  call s:SetNamedColor('#DDA0DD','Plum')
  call s:SetNamedColor('#B0E0E6','PowderBlue')
  call s:SetNamedColor('#BC8F8F','RosyBrown')
  call s:SetNamedColor('#4169E1','RoyalBlue')
  call s:SetNamedColor('#8B4513','SaddleBrown')
  call s:SetNamedColor('#FA8072','Salmon')
  call s:SetNamedColor('#F4A460','SandyBrown')
  call s:SetNamedColor('#2E8B57','SeaGreen')
  call s:SetNamedColor('#FFF5EE','SeaShell')
  call s:SetNamedColor('#A0522D','Sienna')
  call s:SetNamedColor('#87CEEB','SkyBlue')
  call s:SetNamedColor('#6A5ACD','SlateBlue')
  call s:SetNamedColor('#708090','SlateGray')
  call s:SetNamedColor('#708090','SlateGrey')
  call s:SetNamedColor('#FFFAFA','Snow')
  call s:SetNamedColor('#00FF7F','SpringGreen')
  call s:SetNamedColor('#4682B4','SteelBlue')
  call s:SetNamedColor('#D2B48C','Tan')
  call s:SetNamedColor('#D8BFD8','Thistle')
  call s:SetNamedColor('#FF6347','Tomato')
  call s:SetNamedColor('#40E0D0','Turquoise')
  call s:SetNamedColor('#EE82EE','Violet')
  call s:SetNamedColor('#F5DEB3','Wheat')
  call s:SetNamedColor('#F5F5F5','WhiteSmoke')
  call s:SetNamedColor('#9ACD32','YellowGreen')

  let view = winsaveview()
  %call s:PreviewCSSColorInLine()
  call winrestview(view)

  autocmd CursorHold * silent call s:PreviewCSSColorInLine()
  autocmd CursorHoldI * silent call s:PreviewCSSColorInLine()
  if !exists('g:cssColorVimDoNotMessMyUpdatetime')
    set ut=100
  endif

endif
