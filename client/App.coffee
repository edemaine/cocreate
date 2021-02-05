import React from 'react'
import {BrowserRouter as Router, Switch, Route} from 'react-router-dom'

import {FrontPage} from './FrontPage'
import {DrawApp} from './DrawApp'

export App = React.memo ->
  <>
    <AppRouter/>
  </>
App.displayName = 'App'

export AppRouter = React.memo ->
  <Router>
    <Switch>
      <Route path="/r/:roomId">
        <DrawApp/>
      </Route>
      <Route path="/">
        <FrontPage/>
      </Route>
    </Switch>
  </Router>
AppRouter.displayName = 'AppRouter'
