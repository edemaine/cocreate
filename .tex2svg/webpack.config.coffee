path = require 'path'

module.exports =
  mode: 'development'
  entry: './.tex2svg/tex2svg.coffee'
  output:
    path: outputDir = path.resolve __dirname, '..', 'public'
    filename: 'tex2svg.js'
  module:
    rules: [
      test: /\.coffee$/
      loader: 'coffee-loader'
      options:
        bare: true
        transpile:
          presets: ['@babel/preset-env']
    ,
      test: /\.js$/
      exclude: /node_modules/
      use:
        loader: 'babel-loader'
        options:
          presets: ['@babel/preset-env']
    ]
  plugins: [
  ]
