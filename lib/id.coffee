export idRegExp = '[23456789ABCDEFGHJKLMNPQRSTWXYZabcdefghijkmnopqrstuvwxyz]{17}'
export fullIdRegExp = ///^#{idRegExp}$///
export validId = (id) -> typeof id == 'string' and fullIdRegExp.test id
export checkId = (id, type = '') ->
  unless validId id
    type += ' ' if type
    throw new Error "Invalid #{type}ID #{id}"
