export idRegExp = '[23456789ABCDEFGHJKLMNPQRSTWXYZabcdefghijkmnopqrstuvwxyz]{17}'
export fullIdRegExp = ///^#{idRegExp}$///
export validId = (id) -> fullIdRegExp.test id
