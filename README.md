# afewmore
This is a task of CS615 in Stevens Institute of Technology.

Author

* Eric Fitzpatrick
* [Ankai Liang](https://github.com/AnkaiLiang)

## Manual
```
AFEWMORE(1)		  BSD General Commands Manual		   AFEWMORE(1)

NAME
     afewmore -- duplicate EC2 instances with their data directory

SYNOPSIS
     afewmore [-hv] [-d dir] [-n num] instance

DESCRIPTION
     The afewmore tool can be used to duplicate a given EC2 instance.  When
     doing so, it creates multiple new instances and populates their data
     directory by copying the data from the original.

OPTIONS
     The source instance is specified via the mandatory argument to afewmore.
     In addition, the following command-line options are supported:

     -d dir   Copy the contents of this data directory from the orignal source
	      instance to all the new instances.  If not specified, defaults
	      to /data.

     -h       Print a usage statement and exit.

     -n num   Create this many new instances.  If not specified, defaults to
	      10.

     -v       Be verbose.

DETAILS
     Frequently, it is necessary to duplicate a given server's configuration
     or setup.	While configuration management and service orchestration sys-
     tems may be able to perform this task, the afewmore tool allows for a
     trivial initial bootstrapping that only concerns itself with data dupli-
     cation, not host configuration.

     Upon invocation, afewmore will identify the type of EC2 instance in ques-
     tion and launch the requested number of duplicates.  It will then copy
     the contents of the given directory from the source instance to all of
     the newly created instances.

OUTPUT
     By default, afewmore prints the instance IDs of the newly created EC2
     instances as the only output.  Unless an error occurs, no other output is
     generated.

     If the -v flag is given, afewmore may print meaningful diagnostic mes-
     sages as it progresses to stdout.

     Any errors encountered cause a meaningful error message to be printed to
     STDERR.

ENVIRONMENT
     The afewmore tool is suitable to be used by any user and does not have
     any user-specific settings or credentials hard coded.

     afewmore assumes that the user has set up their environment for general
     use with the EC2 tools.  That is, it will not set or modify any environ-
     ment variables.

     afewmore also assumes that the user has set up their ~/.ssh/config file
     to access instances in EC2 via ssh(1) without any additional settings.

EXIT STATUS
     The afewmore will exit with a return status of 0 under normal circum-
     stances.  If an error occurred, afewmore will exit with a value >0.

EXAMPLES
     The following examples illustrate common usage of this tool.

     To create ten more instances of the EC2 instance i-0a1b2c3d4f and copy
     the contents of the '/data' directory from that instance:

	   $ afewmore i-0a1b2c3d4f
	   i-1a1b2c3d4f
	   i-2a1b2c3d4f
	   i-3a1b2c3d4f
	   i-4a1b2c3d4f
	   i-5a1b2c3d4f
	   i-6a1b2c3d4f
	   i-7a1b2c3d4f
	   i-8a1b2c3d4f
	   i-9a1b2c3d4f
	   i-0b1b2c3d4f
	   $ echo $?
	   0
	   $

     To create just one more instance and copy the contents of the directory
     '/usr/local/share':

	   $ afewmore -d /usr/local/share -n 1 i-0a1b2c3d4f
	   i-1a1b2c3d4f
	   $

SEE ALSO
     aws help, ssh(1), tar(1), rsync(1)

HISTORY
     afewmore was originally assigned by Jan Schaumann
     <jschauma@cs.stevens.edu> as a homework assignment for the class "Aspects
     of System Administration" at Stevens Institute of Technology in the
     Spring of 2017.

BSD				April 09, 2017				   BSD
```

## The commentary

### Ankai Liang
I decide to use shell script to finish this task.

1. At the beginning, I look for the arguments which inputted by user.
I found two way, one is manually dealing with them. It requires users to input arguments with explicit position. The other way is using `getopts`, a useful tool which can handle the short options. 
[Tutorial](http://wiki.bash-hackers.org/howto/getopts_tutorial)
After testing, I found that if -d is missing an argument, it will instead of taking the next option as the parameter. So I added a check in each options which need value.

2. Then I need to grab the information of target instance by a given instance-id.
I learned how to write a funtion in Shell Script. When I test the result shell function return, I found `$?` only return the numeric result, and the variable without `local` declaration would domain global, a good choice to record the function result.
About the parameter passing, if I use variable to transfer the json data, it will lose the line feeds. So I use the temp file to store the json data.
By the way, using '&' to make `echo command` running in background in funtion and using 'a=`func args`' outside is also a good way to implement funtion return. But in this way, it can't exit entire script in function when meet error. Maybe the main shell create a sub-shell environment to run sub-command.
Tricky point, sometimes the response from aws contains some null data in some attributes. We should filter them by 'grep "^$"'

3. Next I try to ensure what is UserName when ssh to remote server. Create a table, acquire image-Description, and use awk to match UserName. When use awk to do regular expression searching, I have to transfer the shell variables into awk.[Tutorial](https://www.gnu.org/software/gawk/manual/gawk.html#Using-Shell-Variables)

4. I want to check whether shell sucessfully ssh to the Target server. But I noticed when I offer the wrong username, cli will go into interface and ask for password. If I want to automaticlly deal with the interface, I need install `expect`, that's unallowed. I don't have a better way to solve it.

5. When trasfer the data between two instance, my test remote instance is NetBSD without rsync, I decided transfer the data by `scp`.
6. Because setting up instance need some time. so I have to wait a few seconds then execute the copy mission.

7. "Host key verification failed." I fail to use `scp` transfer data from remote instance to another remote one. I realized scp can't do that between two remote nodes. I need to copy one node's rsa public key to the other, then use ssh into one remote to do that transmission.
8. Deal with the directory path. Before using `scp`, I have to make sure the directory's parent path exists. Use pattern matching to adjust `${path}` and `mkdir -p` to create in new instance.

9. Implement all basic function!