

class buildhost::jenkins {
  include jenkins
  class{ '::jenkins': repo => $create_jenkins_repo }
  jenkins::plugin { 'scm-api': }
  jenkins::plugin { 'git-client': }
  jenkins::plugin { 'git': }
  jenkins::plugin { 'mapdb-api': }
  jenkins::plugin { 'multiple-scms': }
  jenkins::plugin { 'tap': }
  jenkins::plugin { 'build-pipeline-plugin': }
  jenkins::plugin { 'jquery': }
  jenkins::plugin { 'parameterized-trigger': }
  jenkins::plugin { 'sonar': }

  exec { 'jenkins_ssh_key':
    require => [ User['jenkins'], ],
    command => "runuser --command=\"/usr/bin/ssh-keygen -q -f /var/lib/jenkins/.ssh/id_rsa -P ''\" --shell=/bin/bash jenkins",
    creates => '/var/lib/jenkins/.ssh/id_rsa',
    path => [ "/usr/bin/", "/usr/sbin/" ],
  }

  exec { 'jenkins_permit_git':
    require => [ Exec['jenkins_ssh_key'], File["$repodir/.ssh"] ],
    command => "cat /var/lib/jenkins/.ssh/id_rsa.pub >> $repodir/.ssh/authorized_keys",
    unless => "grep -q jenkins $repodir/.ssh/authorized_keys",
    path => [ "/usr/bin/", "/usr/sbin/" ],
  }

  exec { 'jenkins_know_localhost':
    require => [ Exec['jenkins_ssh_key'], ],
    command => "echo -n \"$fqdn \" >> /var/lib/jenkins/.ssh/known_hosts && cat /etc/ssh/ssh_host_ecdsa_key.pub >> /var/lib/jenkins/.ssh/known_hosts",
    unless => "grep -q $fqdn /var/lib/jenkins/.ssh/known_hosts",
    path => [ "/usr/bin/", "/usr/sbin/" ],
  }

  file { '/var/lib/jenkins/.ssh/known_hosts':
    require => [ Exec['jenkins_know_localhost'], ],
    owner => jenkins,
    group => jenkins,
    mode => "600"
  }

  package { 'firewalld':
  ensure => 'installed',
  }

  exec { "firewalld_prepare_jenkins":
    require => [ Package["firewalld"], ],
    command => "firewall-cmd --permanent --add-port=8081/tcp &&
                firewall-cmd  --complete-reload",
    unless => "firewall-cmd --list-all|grep -q 8080",
    path => "/usr/bin/",
  }

  if $deploy_demo {
  jenkins::job { 'ticket-monster-dev':
    config => template("${templates}/ticket-monster-dev.xml.erb"),
  }
  jenkins::job { 'ticket-monster-sonar':
    config => template("${templates}/ticket-monster-sonar.xml.erb"),
  }
  jenkins::job { 'ticket-monster-systest':
    config => template("${templates}/ticket-monster-systest.xml.erb"),
  }
  jenkins::job { 'ticket-monster-prod':
    config => template("${templates}/ticket-monster-prod.xml.erb"),
  }
  jenkins::job { 'baseline-template':
    config => template("${templates}/baseline-template.xml.erb"),
  }
  jenkins::job { 'puppet-modules-dev':
    config => template("${templates}/puppet-modules-dev.xml.erb"),
  }
  jenkins::job { 'puppet-modules-prod':
    config => template("${templates}/puppet-modules-prod.xml.erb"),
  }
  jenkins::job { 'baseline-packages-dev':
    config => template("${templates}/baseline-packages-dev.xml.erb"),
  }
  jenkins::job { 'baseline-packages-prod':
    config => template("${templates}/baseline-packages-prod.xml.erb"),
  }
  }

  package { "apache-maven":
    ensure => $package_ensure,
  }
  file { '/var/lib/jenkins/hudson.tasks.Maven.xml':
    ensure => file,
    content => template("buildhost/hudson.tasks.Maven.xml.erb"),
    owner => 'jenkins',
    group => 'jenkins',
    mode => "644",
    require => [ Package['apache-maven'], Package['jenkins'], ],
  }
  file { '/var/lib/jenkins/maven-settings.xml':
    ensure => file,
    content => template("buildhost/maven-settings.xml.erb"),
    owner => 'jenkins',
    group => 'jenkins',
    mode => "644",
    require => [ Package['apache-maven'], Package['jenkins'], ],
  }
  
}