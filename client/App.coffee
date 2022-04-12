import {onError} from 'solid-js'
import {Route, Router, Routes} from 'solid-app-router'

import {FrontPage} from './FrontPage'
import {DrawApp} from './DrawApp'

export App = ->
  onError (e) -> console.error e
  <AppRouter/>

export AppRouter = ->
  <Router>
    <Routes>
      <Route path="/r/:roomId" element={<DrawApp/>}/>
      <Route path="/" element={<FrontPage/>}/>
    </Routes>
  </Router>
