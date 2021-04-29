import {Aabb} from './Dbvt'

intersects_specific = 
    pen: (aabb, obj) ->
        true

    poly: (aabb, obj) ->
        true

    rect: (aabb, obj) ->
        console.log obj
        # Minkowski sum to make outer test simpler
        fattened = obj.aabb.fattened_xy ((aabb.width() - obj.width) / 2), ((aabb.height() - obj.width) / 2)
        test_point = aabb.center()

        if fattened.contains_point test_point
            # Inside. Take fill or lack of fill into account.
            obj.fill != null || !(obj.aabb.fattened -obj.width).contains aabb
        else
            # Outside. Take roundedness into account.
            test_point.x -= obj.aabb.center().x
            test_point.y -= obj.aabb.center().y
            test_point.x = Math.max ((Math.abs test_point.x) - fattened.width() / 2), 0
            test_point.y = Math.max ((Math.abs test_point.y) - fattened.height() / 2), 0
            test_point.x * test_point.x + test_point.y * test_point.y <= (obj.width / 2) * (obj.width / 2)

    ellipse: (aabb, obj) ->
        true

    text: (aabb, obj) ->
        aabb.intersects obj.aabb

    image: (aabb, obj) ->
        aabb.intersects obj.aabb

export intersects = (aabb, obj) ->
    intersects_specific[obj.type] aabb, obj