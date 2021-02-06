import React from 'react'
import {useTracker} from 'meteor/react-meteor-data'

import {currentRoom, currentPage} from './AppState'
import DrawApp from './DrawApp'

export PageList = React.memo ->
  pages = useTracker ->
    currentRoom.get()?.data()?.pages
  , []
  page = useTracker ->
    currentPage.get()
  , []

  return null unless pages?
  <div className="pageList">
    {for pageId, index in pages
      active = (pageId == page?.id)
      do (pageId) ->
        <div key={pageId} className="page #{if active then 'active' else ''}"
         onClick={-> DrawApp.setPageId pageId}>
          {index+1}
        </div>
    }
  </div>