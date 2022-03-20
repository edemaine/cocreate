if navigator?.platform?.startsWith? 'Mac'
  Ctrl = 'Command'
  Alt = 'Option'
else
  Ctrl = 'Ctrl'
  Alt = 'Alt'
export {Ctrl, Alt}

#export firefox = /Firefox\//.test navigator.userAgent
