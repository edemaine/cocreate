unless window.PointerEvent
  import('pepjs').then ->
    console.log 'Loaded Pointer Events Polyfill (PEP)'
