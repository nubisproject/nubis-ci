Jenkins.instance.pluginManager.plugins.sort().each{
  plugin -> 
  if (plugin.getShortName() == 'credentials') {
    next 
  }
  println ("jenkins::plugin { '${plugin.getShortName()}':\n  ensure => '${plugin.getVersion()}'\n}\n")
}

