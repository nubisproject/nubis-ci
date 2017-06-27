Jenkins.instance.pluginManager.plugins.sort().each{
  plugin -> 
  if (plugin.getShortName() == 'credentials') {
    next 
  }
  println ("jenkins::plugin { '${plugin.getShortName()}':\n  version => '${plugin.getVersion()}'\n}\n")
}

