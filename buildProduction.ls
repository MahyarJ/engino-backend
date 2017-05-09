require! {
  'path'
  'mkdirp'
  'webpack'
  'fs'
}

module.exports = ({projectDir, buildDir}) ->
  buildDir ?= '../server-build'
  targetPath = process.env.TARGET_PATH or path.join(projectDir, buildDir)
  mkdirp.sync targetPath

  webpackConfig = require path.join(projectDir, 'webpack.config.ls')
  webpackConfig.output.path = targetPath

  webpack(webpackConfig).run (err, stats) ->
    if err?
      console.error 'Webpack: Error: ' err
    else
      console.log 'Webpack: Done'

  floraPackage = require \./package.json
  projectPackage = require path.join projectDir, './package.json'

  deps = floraPackage.dependencies
  for packageName, version of projectPackage.dependencies
    if deps[packageName]? and deps[packageName] isnt version
      console.warn "Dependency conflict. Package name: #{packageName}. Flora version: #{deps[packageName]} | Project version: #{version}"

  deps <<< projectPackage.dependencies
  delete deps[\@mahyarj/engino-server]

  packageJson =
    name: projectPackage.name + \-built
    version: projectPackage.version
    private: true
    scripts:
      start: 'cross-env NO_PRETTY_ERROR=on DEBUG=*,-retry-as-promised,-express*,-engine*,-socket.io*,-db*,-superagent node ./index.dist.js'
    dependencies: deps

  fs.writeFile path.join(targetPath, './package.json'), JSON.stringify(packageJson, null, 2), { encoding: \utf-8 }, (err, stats) ->
    if err?
      console.error "Package.json: Error: ", err
    else
      console.log "Package.json: Done"

  try
    copyFolderRecursiveSync path.join(projectDir, "/public"), targetPath
    console.log "Public folder copied."
  catch e
    console.info "didn't copy public folder"

copyFileSync = (source, target) ->
  return if /.DS_Store$|.map$/.test source
  console.log " -- Copying file: " + source.split("/").pop!
  targetFile = target
  targetFile = path.join target, path.basename source if (fs.lstatSync target).isDirectory! if fs.existsSync target
  fs.writeFileSync targetFile, fs.readFileSync source

copyFolderRecursiveSync = (source, target) ->
  files = []
  targetFolder = path.join target, path.basename source
  fs.mkdirSync targetFolder if not fs.existsSync targetFolder
  if (fs.lstatSync source).isDirectory!
    files = fs.readdirSync source
    files.forEach (file) ->
      curSource = path.join source, file
      if (fs.lstatSync curSource).isDirectory! then copyFolderRecursiveSync curSource, targetFolder else copyFileSync curSource, targetFolder
      return 