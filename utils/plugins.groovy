// Jenkins.instance.pluginManager.plugins is an unmodifyable list
List plugins = new ArrayList(Jenkins.instance.pluginManager.plugins);

plugins.sort().each{
  plugin -> 
  if (plugin.getShortName() != 'credentials') {
    println ("jenkins::plugin { '${plugin.getShortName()}':\n  version => '${plugin.getVersion()}'\n}\n")
  }
}
